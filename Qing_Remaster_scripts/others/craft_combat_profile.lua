-- Craft combat profile: recipe → weapon / flag mask / base⊕stat deltas / synergy / multishot
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local enums = require("Qing_Remaster_scripts.core.enums")
local dev_env = require("Qing_Remaster_scripts.core.dev_environment")

local M = {
	own_key = "Craft_Combat_Profile_",
	enable_form_log = false,
	BASE_STATS = {
		damage = 3.5,
		firedelay = 10,
		shotspeed = 1,
		range = 260,
		luck = 0,
		speed = 1,
	},
	TARGET_BASE = {
		-- serial display: 空行01号 / 空怖01号
		[enums.Items.Air_Flight] = {zh = "空行", en = "AF"},
		[enums.Items.Air_Terror] = {zh = "空怖", en = "AT"},
	},
	-- 底座品质 0–4 → 材料槽数 / 整体属性倍率（未放底座时槽数为 0、倍率 1）
	BASE_QUALITY_SLOTS = {
		[0] = 1, [1] = 2, [2] = 3, [3] = 4, [4] = 5,
	},
	BASE_QUALITY_STAT_MUL = {
		[0] = 0.80, [1] = 0.90, [2] = 1.00, [3] = 1.15, [4] = 1.30,
	},
}

-- Morph 条目：pri 仅作「零覆盖」fallback；主武器由 BRANCH_COMPAT 动态表决决定。
M.MORPH = {
	{id = 114, weapon = 4, pri = 11}, -- Mom's Knife
	{id = 118, weapon = 2, pri = 10}, -- Brimstone
	{id = 395, weapon = 9, pri = 8},  -- Tech X
	{id = 68, weapon = 3, pri = 7},   -- Technology
	{id = 168, weapon = 6, pri = 6},  -- Epic Fetus
	{id = 52, weapon = 5, pri = 5},   -- Dr. Fetus
	{id = 678, weapon = 14, pri = 4}, -- C Section
	{id = 229, weapon = 7, pri = 3},  -- Monstro's Lung
	{id = 329, weapon = 8, pri = 2},  -- Ludovico（可改形 Brim/Tech/TechX/Knife；仍被 Epic/剖腹产/英灵剑覆盖）
	{id = 579, weapon = 13, pri = 2}, -- Spirit Sword
}

-- 主武器编号
M.WPN = {
	TEARS = 1, BRIM = 2, TECH = 3, KNIFE = 4, DR = 5,
	EPIC = 6, LUNG = 7, LUDO = 8, TECH_X = 9, SWORD = 13, C_SECTION = 14,
}

-- 分支已实现、可消费的副 morph（weapon id 集合）。含 §14.7.1–9 增量。
M.BRANCH_COMPAT = {
	[6] = {[4] = true, [2] = true, [9] = true, [3] = true, [14] = true, [7] = true, [5] = true, [13] = true}, -- Epic
	[14] = {[4] = true, [2] = true, [9] = true, [3] = true, [5] = true, [13] = true}, -- C Section
	[13] = {[4] = true, [9] = true, [3] = true, [14] = true}, -- Spirit Sword
	[4] = {[2] = true, [9] = true, [5] = true, [7] = true, [3] = true}, -- Knife（+Tech）
	[2] = {[9] = true, [3] = true, [14] = true, [7] = true, [13] = true}, -- Brim（+Sword）
	[9] = {[2] = true, [7] = true, [3] = true}, -- Tech X（+Tech）
	[3] = {[7] = true}, -- Technology
	[7] = {[5] = true}, -- Lung
	[5] = {[2] = true, [9] = true, [3] = true, [13] = true}, -- Dr（§14.7）
	-- Ludovico：Brim/Tech/TechX/Knife 改形；Tech X 与 Tech 等效（受控环）
	[8] = {[2] = true, [3] = true, [9] = true, [4] = true},
}

-- 同分时的载体优先级（数值越大越优先）。
M.CARRIER_PRI = {
	[6] = 90,  -- Epic
	[14] = 80, -- C Section
	[13] = 70, -- Spirit Sword
	[8] = 65,  -- Ludovico（可改形 Brim/Tech/Knife；仍低于 Epic/剖腹产/英灵剑）
	[4] = 60,  -- Knife
	[2] = 50,  -- Brim
	[9] = 40,  -- Tech X
	[3] = 30,  -- Technology
	[7] = 20,  -- Lung
	[5] = 10,  -- Dr
	[1] = 0,   -- Tears
}

-- 这些主武器仍覆盖 Ludovico（不进入受控泪/环形态）
M.LUDO_OVERRIDDEN_BY = {
	[6] = true,  -- Epic Fetus
	[14] = true, -- C Section
	[13] = true, -- Spirit Sword
}

-- 恰好这些 morph 种类（可重复份数）时强制主武器；优先于覆盖评分。
-- key = 排序后的 weapon id 用 "," 拼接
M.EXACT_MORPH_SET_OVERRIDE = {
	["2,14"] = 2, -- Brim + C Section → Brim（现有额外胎儿）
}

M.LUDO_WEAPON = 8

-- §15.4 修订：血泪作为小攻击方式，主射仍走眼泪；可覆盖下列 morph 为主武器。
-- 肺/史诗/剖腹产/英灵剑仍优先于血泪，不在此表。
-- 妈刀：血泪覆盖妈刀（落地 knife burst）。鲁多维科：鲁多维科覆盖血泪（变色 + 低概率自模拟爆发）。
-- 被覆盖者记入 compat_consumed；多 guest 主泪产量均分（不读 TEAR_BURSTSPLIT / 不赢家通吃）。
M.HAEMO_OVERRIDE_WEAPONS = {
	[2] = true, -- Brimstone
	[3] = true, -- Technology
	[4] = true, -- Mom's Knife
	[5] = true, -- Dr. Fetus
	[9] = true, -- Tech X
}

-- 参与主泪产量均分的 guest（卢多不进覆盖表）
M.HAEMO_SHAREABLE = {
	[2] = true, -- brim
	[3] = true, -- tech
	[4] = true, -- knife
	[5] = true, -- bombs
	[9] = true, -- techx
}

-- 每多 1 个均分 guest，落地 burst 总面额 +20%（再均分到各 mode；不增加主气球数）
M.HAEMO_SHARE_BONUS = 0.2

-- 各 burst mode 自身产量区间（「倍率」）；多 mode 并存时先均分面额再套此区间
M.HAEMO_MODE_BASE_COUNT = {
	tears = {6, 11},
	brim = {4, 7},
	tech = {7, 11},
	techx = {3, 5},
	bombs = {3, 5},
	knife = {3, 6}, -- 妈刀：3–6，勿抄子泪 6–11
	sword = {3, 6},
}

-- 卢多控泪 + 血泪：每次有效伤害 tick 触发爆发的基础概率（再加 luck*0.01，封顶 0.35）
M.HAEMO_LUDO_BURST_CHANCE = 0.12

-- 保留 PRI 表仅作历史/探针对照；开火与 burst 已改为均分
M.HAEMO_BURST_PRI = {
	[2] = 40,
	[9] = 30,
	[3] = 20,
	[5] = 10,
	[4] = 5,
}

M.HAEMO_BURST_MODE = {
	[2] = "brim",
	[3] = "tech",
	[5] = "bombs",
	[9] = "techx",
	[4] = "knife",
}

M.WEAPON_NAME = {
	[1] = {zh = "眼泪", en = "Tears"},
	[2] = {zh = "硫磺", en = "Brimstone"},
	[3] = {zh = "科技", en = "Technology"},
	[4] = {zh = "妈刀", en = "Mom's Knife"},
	[5] = {zh = "博士", en = "Dr. Fetus"},
	[6] = {zh = "史诗", en = "Epic Fetus"},
	[7] = {zh = "肺", en = "Monstro's Lung"},
	[8] = {zh = "鲁多维科科技", en = "Ludovico Technique"},
	[9] = {zh = "科技X", en = "Tech X"},
	[10] = {zh = "骨剑", en = "Bone Club"},
	[13] = {zh = "英灵剑", en = "Spirit Sword"},
	[14] = {zh = "剖腹产", en = "C Section"},
}

-- Only Brimstone stack changes the attack shape; other morph stacks → extra shots (count-1).
M.WEAPON_STACK_KEY = {
	[3] = "tech",
	[4] = "knife",
	[5] = "dr",
	[6] = "epic",
	[7] = "lung",
	[9] = "techX",
	[13] = "sword",
	[14] = "sec",
}

--- 蓝图制造开火：按表决后的主武器套用射速倍率（乘 Tear Delay）。
--- 巧克力牛奶 / 诅咒之眼 / Haemolacria 暂不登记。
M.WEAPON_FIRE_DELAY_MUL = {
	[2] = 3,   -- Brimstone
	[4] = 2,   -- Mom's Knife
	[5] = 2.5, -- Dr. Fetus
	[6] = 4,   -- Epic Fetus
	[7] = 4,   -- Monstro's Lung
	[9] = 3,   -- Tech X
	[14] = 3,  -- C Section
}

function M.weapon_fire_delay_mul(weapon)
	return M.WEAPON_FIRE_DELAY_MUL[weapon or 1] or 1
end

--- 制造档案开火延迟：build_profile 已把主武器倍率写入 stats.firedelay
function M.craft_fire_delay(profile, weapon)
	if not profile or not profile.stats then return 10 end
	local st = profile.stats
	-- 兼容旧档案：未烘焙时按 base×mul 现算
	if st.firedelay_base ~= nil then
		return tonumber(st.firedelay) or 10
	end
	local base = tonumber(st.firedelay) or 10
	weapon = weapon or profile.weapon or 1
	return base * M.weapon_fire_delay_mul(weapon)
end

-- 幸运概率：分母保持正数，结果 clamp 到 [0, cap]
local function tear_p_clamp(p, cap)
	cap = cap or 1
	if p ~= p or p < 0 then return 0 end
	if p > cap then return cap end
	return p
end

local function tear_p_denom(base, sub, luck, cap)
	local den = math.max(1, (base or 1) - math.floor((tonumber(luck) or 0) * (sub or 1)))
	return tear_p_clamp(1 / den, cap or 1)
end

local function tear_roll(p, rng)
	p = tear_p_clamp(p, 1)
	if p <= 0 then return false end
	if p >= 1 then return true end
	if rng and rng.RandomFloat then return rng:RandomFloat() < p end
	return math.random() < p
end

-- 独立 TearFlags：确定项直接 OR；概率项按 Flight 幸运 + 稳定 RNG 投掷。
-- 不再依赖 player:GetTearHitParams / imitate。
-- scope: per_tear（默认）| inherit_split（子泪继承，由发射侧保证同次 volley 共用 flags）
M.TEAR_EFFECTS = {
	[3] = {flag = TearFlags.TEAR_HOMING},
	[5] = {flag = TearFlags.TEAR_BOOMERANG},
	[48] = {flag = TearFlags.TEAR_PIERCING},
	-- Spider Bite：1/max(1, 4-floor(luck/5))；0 运 25%，15 运 100%
	[89] = {
		flag = TearFlags.TEAR_SLOW,
		scope = "per_tear",
		roll = function(luck, rng)
			local p = 1 / math.max(1, 4 - math.floor((tonumber(luck) or 0) / 5))
			return tear_roll(p, rng)
		end,
	},
	-- The Common Cold：1/max(1, 4-floor(luck/4))
	[103] = {
		flag = TearFlags.TEAR_POISON,
		scope = "per_tear",
		roll = function(luck, rng)
			local p = 1 / math.max(1, 4 - math.floor((tonumber(luck) or 0) / 4))
			return tear_roll(p, rng)
		end,
	},
	[104] = {flag = TearFlags.TEAR_SPLIT, scope = "inherit_split"},
	-- Mom's Contacts
	[110] = {
		flag = TearFlags.TEAR_FREEZE,
		scope = "per_tear",
		roll = function(luck, rng)
			return tear_roll(tear_p_denom(5, 0.15, luck, 0.5), rng)
		end,
	},
	[115] = {flag = TearFlags.TEAR_SPECTRAL},
	[132] = {flag = TearFlags.TEAR_GROW},
	[149] = {flag = TearFlags.TEAR_EXPLOSIVE},
	-- The Mulligan：命中生成蓝蝇；固定 1/6 给泪挂 TEAR_MULLIGAN（不受幸运；与猫套常驻 flag 不叠乘）
	[151] = {
		flag = TearFlags.TEAR_MULLIGAN,
		scope = "per_tear",
		roll = function(_, rng)
			return tear_roll(1 / 6, rng)
		end,
	},
	[159] = {flag = TearFlags.TEAR_SPECTRAL}, -- Spirit of the Night
	[169] = {flag = TearFlags.TEAR_PERSISTENT},
	[182] = {flag = TearFlags.TEAR_HOMING}, -- Sacred Heart
	[185] = {flag = TearFlags.TEAR_SPECTRAL}, -- Dead Dove
	-- Mom's Eyeshadow
	[200] = {
		flag = TearFlags.TEAR_CHARM,
		scope = "per_tear",
		roll = function(luck, rng)
			local den = math.max(1, 10 - math.floor((tonumber(luck) or 0) / 3))
			return tear_roll(tear_p_clamp(1 / den, 1), rng)
		end,
	},
	-- Iron Bar：1/max(1, 10-floor(luck*0.334))；0 运 10%，27 运 100%
	[201] = {
		flag = TearFlags.TEAR_CONFUSION,
		scope = "per_tear",
		roll = function(luck, rng)
			local den = math.max(1, 10 - math.floor((tonumber(luck) or 0) * 0.334))
			return tear_roll(tear_p_clamp(1 / den, 1), rng)
		end,
	},
	[213] = {flag = TearFlags.TEAR_SHIELDED},
	[221] = {flag = TearFlags.TEAR_BOUNCE},
	[222] = {flag = TearFlags.TEAR_WAIT},
	[224] = {flag = TearFlags.TEAR_QUADSPLIT, scope = "inherit_split"},
	-- Mom's Perfume（恐惧概率；射速见 STAT_DELTA once）
	[228] = {
		flag = TearFlags.TEAR_FEAR,
		scope = "per_tear",
		roll = function(luck, rng)
			local den = math.max(1, 100 - math.floor(tonumber(luck) or 0))
			return tear_roll(tear_p_clamp(15 / den, 1), rng)
		end,
	},
	-- Ball of Tar：仅减速泪概率（不模拟脚下黑水迹）
	[231] = {
		flag = TearFlags.TEAR_SLOW | TearFlags.TEAR_GISH,
		scope = "per_tear",
		roll = function(luck, rng)
			return tear_roll(tear_p_denom(10, 0.5, luck, 1), rng)
		end,
	},
	[233] = {flag = TearFlags.TEAR_ORBIT}, -- Tiny Planet
	[237] = {flag = TearFlags.TEAR_PIERCING}, -- Death's Touch
	-- Fire Mind：燃烧常驻；命中爆炸见 post_hit（由发射侧挂标记）
	[257] = {
		flag = TearFlags.TEAR_BURN,
		post_hit = "fire_mind_explode",
		explode_p = function(luck)
			return tear_p_denom(10, 0.7, luck, 1)
		end,
	},
	-- Dark Matter：优于香水的恐惧曲线 ≈ 1/(3 - luck*0.1)
	[259] = {
		flag = TearFlags.TEAR_FEAR,
		always_flag = TearFlags.TEAR_DARK_MATTER,
		scope = "per_tear",
		roll = function(luck, rng)
			return tear_roll(tear_p_denom(3, 0.1, luck, 1), rng)
		end,
	},
	[261] = {flag = TearFlags.TEAR_SHRINK},
	[305] = {flag = TearFlags.TEAR_POISON}, -- Scorpio
	[306] = {flag = TearFlags.TEAR_PIERCING}, -- Sagittarius
	[309] = {flag = TearFlags.TEAR_KNOCKBACK}, -- Pisces
	[315] = {flag = TearFlags.TEAR_ATTRACTOR}, -- Strange Attractor
	[317] = {flag = TearFlags.TEAR_MYSTERIOUS_LIQUID_CREEP},
	[329] = {flag = TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING}, -- Ludovico
	[331] = {flag = TearFlags.TEAR_GLOW},
	[336] = {flag = TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING}, -- Dead Onion
	[358] = {flag = TearFlags.TEAR_SPECTRAL}, -- The Wiz
	[359] = {flag = TearFlags.TEAR_KNOCKBACK}, -- 8 Inch Nails
	[369] = {flag = TearFlags.TEAR_CONTINUUM},
	[374] = {
		flag = TearFlags.TEAR_LIGHT_FROM_HEAVEN,
		scope = "per_tear",
		roll = function(luck, rng)
			return tear_roll(tear_p_denom(10, 0.9, luck, 0.5), rng)
		end,
	},
	-- Abaddon：15/max(15, 100-floor(luck))
	[230] = {
		flag = TearFlags.TEAR_FEAR,
		scope = "per_tear",
		roll = function(luck, rng)
			local den = math.max(15, 100 - math.floor(tonumber(luck) or 0))
			return tear_roll(15 / den, rng)
		end,
	},
	[379] = {flag = TearFlags.TEAR_SPECTRAL}, -- Pupula Duplex
	[393] = { -- Serpent's Kiss：忏悔+固定 15%
		flag = TearFlags.TEAR_POISON,
		scope = "per_tear",
		roll = function(luck, rng) return tear_roll(0.15, rng) end,
	},
	[398] = { -- God's Flesh：忏悔+固定 20%
		flag = TearFlags.TEAR_GODS_FLESH,
		scope = "per_tear",
		roll = function(luck, rng) return tear_roll(0.20, rng) end,
	},
	-- Explosivo：固定 25%，不受幸运影响
	[401] = {
		flag = TearFlags.TEAR_STICKY,
		scope = "per_tear",
		roll = function(luck, rng)
			return tear_roll(0.25, rng)
		end,
	},
	[397] = {flag = TearFlags.TEAR_TRACTOR_BEAM}, -- Tractor Beam
	[429] = {flag = TearFlags.TEAR_GREED_COIN}, -- Head of the Keeper
	[453] = {flag = TearFlags.TEAR_BONE},
	[459] = { -- Sinus Infection：固定 20%
		flag = TearFlags.TEAR_BOOGER,
		scope = "per_tear",
		roll = function(luck, rng) return tear_roll(0.20, rng) end,
	},
	[460] = { -- Glaucoma：固定 5%
		flag = TearFlags.TEAR_PERMANENT_CONFUSION,
		scope = "per_tear",
		roll = function(luck, rng) return tear_roll(0.05, rng) end,
	},
	[462] = {flag = TearFlags.TEAR_PIERCING | TearFlags.TEAR_BELIAL}, -- Eye of Belial
	[463] = { -- Sulfuric Acid：固定 25%
		flag = TearFlags.TEAR_ACID,
		scope = "per_tear",
		roll = function(luck, rng) return tear_roll(0.25, rng) end,
	},
	[494] = {flag = TearFlags.TEAR_JACOBS}, -- Jacob's Ladder
	[496] = { -- Euthanasia（忏悔+）：1/max(4, 30-floor(2*luck))
		flag = TearFlags.TEAR_NEEDLE,
		scope = "per_tear",
		roll = function(luck, rng)
			local den = math.max(4, 30 - math.floor((tonumber(luck) or 0) * 2))
			return tear_roll(1 / den, rng)
		end,
	},
	[503] = { -- Little Horn：1/max(5, 20-floor(luck))
		flag = TearFlags.TEAR_HORN,
		scope = "per_tear",
		roll = function(luck, rng)
			local den = math.max(5, 20 - math.floor(tonumber(luck) or 0))
			return tear_roll(1 / den, rng)
		end,
	},
	[506] = {flag = TearFlags.TEAR_BACKSTAB}, -- Backstabber
	-- Technology Zero（非拟寄生物；461 卵泪另走 EXTRA/AF）
	[524] = {flag = TearFlags.TEAR_LASER},
	[529] = {flag = TearFlags.TEAR_POP}, -- Pop!
	-- 血泪：制造侧自模拟 burst，禁止把 TEAR_BURSTSPLIT 写入泪弹（原版 flag 会读玩家背包）
	[531] = {flag = nil, scope = "inherit_split", craft_sim_burst = true},
	[532] = {flag = TearFlags.TEAR_ABSORB},
	[533] = {flag = TearFlags.TEAR_LASERSHOT},
	[540] = {flag = TearFlags.TEAR_HYDROBOUNCE},
	[553] = { -- Mucormycosis：固定 25%
		flag = TearFlags.TEAR_SPORE,
		scope = "per_tear",
		roll = function(luck, rng) return tear_roll(0.25, rng) end,
	},
	[570] = {flag = TearFlags.TEAR_RAINBOW}, -- Playdough Cookie；颜色另行稳定抽取
	[572] = {flag = TearFlags.TEAR_OCCULT},
	[592] = {flag = TearFlags.TEAR_ROCK},
	[596] = {flag = TearFlags.TEAR_ICE}, -- Uranus
	[606] = {
		flag = TearFlags.TEAR_RIFT,
		scope = "per_tear",
		roll = function(luck, rng)
			return tear_roll(tear_p_denom(20, 1, luck, 0.2), rng)
		end,
	},
	[617] = { -- Lodestone：1/max(1, 6-floor(luck))
		flag = TearFlags.TEAR_MAGNETIZE,
		scope = "per_tear",
		roll = function(luck, rng)
			local den = math.max(1, 6 - math.floor(tonumber(luck) or 0))
			return tear_roll(1 / den, rng)
		end,
	},
	[618] = { -- Rotten Tomato：1/max(1, 6-ceil(luck))
		flag = TearFlags.TEAR_BAIT,
		scope = "per_tear",
		roll = function(luck, rng)
			local den = math.max(1, 6 - math.ceil(tonumber(luck) or 0))
			return tear_roll(1 / den, rng)
		end,
	},
	[637] = { -- Knockout Drops：1/max(1, floor(10-luck))
		flag = TearFlags.TEAR_PUNCH,
		scope = "per_tear",
		roll = function(luck, rng)
			local den = math.max(1, math.floor(10 - (tonumber(luck) or 0)))
			return tear_roll(1 / den, rng)
		end,
	},
}

-- 兼容旧键：材料 → flag（含概率项的 flag 本体，供标签/资格表）
M.TEAR_FLAG_MASK = {}
for id, e in pairs(M.TEAR_EFFECTS) do
	if e then
		local mask = e.flag or BitSet128(0, 0)
		if e.always_flag then mask = mask | e.always_flag end
		M.TEAR_FLAG_MASK[id] = mask
	end
end

-- 炸弹道具仅由 Dr. Fetus / Epic Fetus 分支消费；不得污染普通泪弹。
-- BombVariant 用于博士实体外观，flag 同时供博士爆炸与史诗落点效果。
M.BOMB_EFFECTS = {
	[106] = {variant = BombVariant.BOMB_MR_MEGA},
	[125] = {variant = BombVariant.BOMB_BOBBY, flag = TearFlags.TEAR_HOMING},
	[140] = {variant = BombVariant.BOMB_POISON},
	[209] = {variant = BombVariant.BOMB_BUTT, flag = TearFlags.TEAR_BUTT_BOMB},
	[220] = {variant = BombVariant.BOMB_SAD, flag = TearFlags.TEAR_SAD_BOMB},
	[256] = {variant = BombVariant.BOMB_HOT, flag = TearFlags.TEAR_BURN},
	[353] = {flag = TearFlags.TEAR_CROSS_BOMB},
	[366] = {flag = TearFlags.TEAR_SCATTER_BOMB},
	[367] = {flag = TearFlags.TEAR_STICKY},
	[432] = {variant = BombVariant.BOMB_GLITTER, flag = TearFlags.TEAR_GLITTER_BOMB},
	[517] = {flag = TearFlags.TEAR_FAST_BOMB},
	[563] = {nancy = true},
	[614] = {variant = BombVariant.BOMB_SAD_BLOOD, flag = TearFlags.TEAR_BLOOD_BOMB},
	[646] = {variant = BombVariant.BOMB_BRIMSTONE, flag = TearFlags.TEAR_BRIMSTONE_BOMB},
	[727] = {flag = TearFlags.TEAR_GHOST_BOMB},
}

-- 拟寄生物卵泪概率（461；不进 TEAR_FLAG_MASK）
function M.parasitoid_chance(luck)
	return tear_p_denom(7, 1, luck, 0.5)
end

--- Tough Love（150）：1/max(1, 10-⌊luck⌋) 换 TearVariant.TOOTH，伤害 ×3.2；非 TearFlag。
function M.tough_love_chance(luck)
	return tear_p_denom(10, 1, luck, 1)
end

--- Apple!（443）：1/max(1, 15-⌊luck⌋) 换 TearVariant.RAZOR，伤害 ×4；非 TearFlag。
function M.apple_chance(luck)
	return tear_p_denom(15, 1, luck, 1)
end

--- Lead Pencil / Eye of Greed 等共享的「攻击计数」阈值。
M.SHOT_COUNTER = {
	lead_pencil = {id = 444, every = 15, key = "pencil"},
	eye_of_greed = {id = 450, every = 20, key = "greed"},
}

function M.fire_mind_explode_chance(luck)
	local e = M.TEAR_EFFECTS[257]
	if e and e.explode_p then return e.explode_p(luck) end
	return tear_p_denom(10, 0.7, luck, 1)
end

M.FLAG_NAME = {
	[3] = {zh = "追踪", en = "Homing", eid_zh = "飞行器发射的泪弹会追踪敌人。", eid_en = "The Air Flight's tears home in on enemies."},
	[5] = {zh = "回旋", en = "Boomerang", eid_zh = "飞行器发射的泪弹会折返。", eid_en = "The Air Flight's tears boomerang back."},
	[48] = {zh = "穿透", en = "Piercing", eid_zh = "飞行器发射的泪弹会穿透敌人。", eid_en = "The Air Flight's tears pierce enemies."},
	[89] = {zh = "减速", en = "Slow", eid_zh = "飞行器的攻击会使敌人减速。", eid_en = "The Air Flight's attacks slow enemies."},
	[103] = {zh = "毒", en = "Poison", eid_zh = "飞行器的攻击会使敌人中毒。", eid_en = "The Air Flight's attacks poison enemies."},
	[104] = {zh = "分裂", en = "Split", eid_zh = "飞行器发射的泪弹命中后会分裂。", eid_en = "The Air Flight's tears split on hit."},
	[110] = {zh = "石化", en = "Petrify", eid_zh = "飞行器的攻击会使敌人石化。", eid_en = "The Air Flight's attacks petrify enemies."},
	[115] = {zh = "幽灵", en = "Spectral", eid_zh = "飞行器发射的泪弹带有幽灵特性。", eid_en = "The Air Flight's tears become spectral."},
	[132] = {zh = "变大", en = "Grow", eid_zh = "飞行器发射的泪弹会逐渐变大。", eid_en = "The Air Flight's tears grow as they travel."},
	[149] = {zh = "爆炸", en = "Explosive", eid_zh = "飞行器的攻击会爆炸。", eid_en = "The Air Flight's attacks explode."},
	[151] = {zh = "蓝蝇", en = "Mulligan", eid_zh = "飞行器击杀敌人后有概率生成蓝苍蝇。", eid_en = "After the Air Flight kills an enemy, it has a chance to spawn a blue fly."},
	[159] = {zh = "幽灵", en = "Spectral", eid_zh = "飞行器发射的泪弹带有幽灵特性。", eid_en = "The Air Flight's tears become spectral."},
	[169] = {zh = "持续", en = "Persistent", eid_zh = "飞行器发射的泪弹会持续存在更久。", eid_en = "The Air Flight's tears last longer."},
	[182] = {zh = "追踪", en = "Homing", eid_zh = "飞行器发射的泪弹会追踪敌人。", eid_en = "The Air Flight's tears home in on enemies."},
	[185] = {zh = "幽灵", en = "Spectral", eid_zh = "飞行器发射的泪弹带有幽灵特性。", eid_en = "The Air Flight's tears become spectral."},
	[200] = {zh = "魅惑", en = "Charm", eid_zh = "飞行器的攻击会使敌人被魅惑。", eid_en = "The Air Flight's attacks charm enemies."},
	[201] = {zh = "混乱", en = "Confusion", eid_zh = "飞行器的攻击会使敌人混乱。", eid_en = "The Air Flight's attacks confuse enemies."},
	[213] = {zh = "护盾", en = "Shielded", eid_zh = "飞行器发射的泪弹带有护盾。", eid_en = "The Air Flight's tears become shielded."},
	[221] = {zh = "反弹", en = "Bounce", eid_zh = "飞行器发射的泪弹会反弹。", eid_en = "The Air Flight's tears bounce."},
	[222] = {zh = "反重力", en = "Anti-Grav", eid_zh = "飞行器发射的泪弹带有反重力。", eid_en = "The Air Flight's tears use anti-gravity."},
	[224] = {zh = "四分裂", en = "Quad", eid_zh = "飞行器发射的泪弹会四向分裂。", eid_en = "The Air Flight's tears split in four directions."},
	[228] = {zh = "恐惧", en = "Fear", eid_zh = "飞行器的攻击会使敌人恐惧。", eid_en = "The Air Flight's attacks inflict fear."},
	[230] = {zh = "恐惧", en = "Fear", eid_zh = "飞行器的攻击会使敌人恐惧。", eid_en = "The Air Flight's attacks inflict fear."},
	[231] = {zh = "减速", en = "Slow", eid_zh = "飞行器的攻击会使敌人减速。", eid_en = "The Air Flight's attacks slow enemies."},
	[233] = {zh = "环绕", en = "Orbit", eid_zh = "飞行器发射的泪弹会环绕飞行。", eid_en = "The Air Flight's tears orbit as they fly."},
	[237] = {zh = "穿透", en = "Piercing", eid_zh = "飞行器发射的泪弹会穿透敌人。", eid_en = "The Air Flight's tears pierce enemies."},
	[257] = {zh = "燃烧", en = "Burn", eid_zh = "飞行器的攻击会使敌人燃烧。", eid_en = "The Air Flight's attacks burn enemies."},
	[259] = {zh = "恐惧", en = "Fear", eid_zh = "飞行器的攻击会使敌人恐惧。", eid_en = "The Air Flight's attacks inflict fear."},
	[261] = {zh = "缩小", en = "Shrink", eid_zh = "飞行器的攻击会使敌人缩小。", eid_en = "The Air Flight's attacks shrink enemies."},
	[305] = {zh = "毒", en = "Poison", eid_zh = "飞行器的攻击会使敌人中毒。", eid_en = "The Air Flight's attacks poison enemies."},
	[306] = {zh = "穿透", en = "Piercing", eid_zh = "飞行器发射的泪弹会穿透敌人。", eid_en = "The Air Flight's tears pierce enemies."},
	[309] = {zh = "击退", en = "Knockback", eid_zh = "飞行器的攻击会击退敌人。", eid_en = "The Air Flight's attacks knock enemies back."},
	[315] = {zh = "吸引", en = "Attractor", eid_zh = "飞行器发射的泪弹会吸引敌人。", eid_en = "The Air Flight's tears attract enemies."},
	[317] = {zh = "毒性水迹", en = "Toxic Creep", eid_zh = "飞行器的攻击会留下毒性水迹。", eid_en = "The Air Flight's attacks leave toxic creep."},
	[329] = {zh = "幽灵穿透", en = "Spectral Piercing", eid_zh = "飞行器发射的泪弹带有幽灵穿透。", eid_en = "The Air Flight's tears become spectral and piercing."},
	[331] = {zh = "神性光环", en = "Godhead", eid_zh = "飞行器发射的泪弹带有神性光环。", eid_en = "The Air Flight's tears gain a Godhead aura."},
	[336] = {zh = "幽灵穿透", en = "Spectral Piercing", eid_zh = "飞行器发射的泪弹带有幽灵穿透。", eid_en = "The Air Flight's tears become spectral and piercing."},
	[358] = {zh = "幽灵", en = "Spectral", eid_zh = "飞行器发射的泪弹带有幽灵特性。", eid_en = "The Air Flight's tears become spectral."},
	[359] = {zh = "击退", en = "Knockback", eid_zh = "飞行器的攻击会击退敌人。", eid_en = "The Air Flight's attacks knock enemies back."},
	[369] = {zh = "连续体", en = "Continuum", eid_zh = "飞行器发射的泪弹可连续体穿墙。", eid_en = "The Air Flight's tears gain Continuum wall travel."},
	[374] = {zh = "圣光", en = "Holy Light", eid_zh = "飞行器的攻击命中后有概率生成圣光。", eid_en = "The Air Flight's attacks have a chance to spawn holy light on hit."},
	[379] = {zh = "幽灵", en = "Spectral", eid_zh = "飞行器发射的泪弹带有幽灵特性。", eid_en = "The Air Flight's tears become spectral."},
	[393] = {zh = "蛇吻毒", en = "Serpent's Kiss", eid_zh = "飞行器的攻击会使敌人中蛇吻毒素。", eid_en = "The Air Flight's attacks apply Serpent's Kiss poison."},
	[397] = {zh = "牵引光束", en = "Tractor Beam", eid_zh = "飞行器发射的泪弹沿牵引光束前进。", eid_en = "The Air Flight's tears travel along a tractor beam."},
	[398] = {zh = "缩小", en = "God's Flesh", eid_zh = "飞行器的攻击会使敌人缩小。", eid_en = "The Air Flight's attacks shrink enemies."},
	[401] = {zh = "粘性", en = "Sticky", eid_zh = "飞行器发射的泪弹会粘附敌人。", eid_en = "The Air Flight's tears stick to enemies."},
	[429] = {zh = "掉币", en = "Coin Drop", eid_zh = "飞行器击杀敌人后有概率掉落硬币。", eid_en = "After the Air Flight kills an enemy, it has a chance to drop coins."},
	[453] = {zh = "骨头", en = "Bone", eid_zh = "飞行器发射骨头泪弹。", eid_en = "The Air Flight fires bone tears."},
	[459] = {zh = "鼻涕黏附", en = "Booger Stick", eid_zh = "飞行器发射的泪弹会鼻涕黏附。", eid_en = "The Air Flight's tears stick like boogers."},
	[460] = {zh = "青光眼", en = "Glaucoma", eid_zh = "飞行器的攻击会使敌人致盲。", eid_en = "The Air Flight's attacks blind enemies."},
	[462] = {zh = "彼列之眼", en = "Eye of Belial", eid_zh = "飞行器发射的泪弹带有彼列之眼效果。", eid_en = "The Air Flight's tears gain Eye of Belial."},
	[463] = {zh = "硫酸", en = "Acid", eid_zh = "飞行器的攻击带有硫酸。", eid_en = "The Air Flight's attacks deal acid damage."},
	[494] = {zh = "连锁电弧", en = "Jacob's Ladder", eid_zh = "飞行器的攻击会释放连锁电弧。", eid_en = "The Air Flight's attacks release chaining arcs."},
	[496] = {zh = "安乐死", en = "Euthanasia", eid_zh = "飞行器有概率发射安乐死针。", eid_en = "The Air Flight has a chance to fire Euthanasia needles."},
	[503] = {zh = "小角", en = "Little Horn", eid_zh = "飞行器有概率发射小角裂隙。", eid_en = "The Air Flight has a chance to fire Little Horn rifts."},
	[506] = {zh = "背刺", en = "Backstab", eid_zh = "飞行器从背后命中时造成背刺。", eid_en = "The Air Flight backstabs when hitting from behind."},
	[524] = {zh = "电弧", en = "Tech Zero", eid_zh = "飞行器发射的泪弹会以电弧连接。", eid_en = "The Air Flight's tears connect with Tech Zero arcs."},
	[529] = {zh = "啪!", en = "Pop!", eid_zh = "飞行器发射眼球泪弹。", eid_en = "The Air Flight fires eyeball tears."},
	[531] = {zh = "血泪", en = "Haemolacria", eid_zh = "飞行器发射会爆裂的血泪。", eid_en = "The Air Flight fires bursting Haemolacria tears."},
	[532] = {zh = "噬泪", en = "Lachryphagy", eid_zh = "飞行器发射的泪弹带有噬泪效果。", eid_en = "The Air Flight's tears gain Lachryphagy."},
	[533] = {zh = "三圣颂", en = "Trisagion", eid_zh = "飞行器发射三圣颂光束。", eid_en = "The Air Flight fires Trisagion beams."},
	[540] = {zh = "扁石", en = "Flat Stone", eid_zh = "飞行器发射的泪弹会像扁石一样弹跳。", eid_en = "The Air Flight's tears skip like Flat Stone."},
	[553] = {zh = "毛霉菌孢子", en = "Mucormycosis", eid_zh = "飞行器有概率发射毛霉菌孢子泪弹。", eid_en = "The Air Flight has a chance to fire Mucormycosis spore tears."},
	[570] = {zh = "随机泪效", en = "Playdough Cookie", eid_zh = "飞行器发射的泪弹带有随机泪效。", eid_en = "The Air Flight's tears gain random tear effects."},
	[572] = {zh = "可控泪弹", en = "Eye of the Occult", eid_zh = "飞行器发射可控泪弹。", eid_en = "The Air Flight fires controllable tears."},
	[592] = {zh = "岩石", en = "Rock", eid_zh = "飞行器发射岩石泪弹。", eid_en = "The Air Flight fires rock tears."},
	[596] = {zh = "冰冻", en = "Ice", eid_zh = "飞行器的攻击会使敌人冰冻。", eid_en = "The Air Flight's attacks freeze enemies."},
	[606] = {zh = "裂隙", en = "Rift", eid_zh = "飞行器的攻击会生成裂隙。", eid_en = "The Air Flight's attacks create rifts."},
	[617] = {zh = "磁化", en = "Magnetize", eid_zh = "飞行器的攻击会使敌人磁化。", eid_en = "The Air Flight's attacks magnetize enemies."},
	[618] = {zh = "诱饵", en = "Bait", eid_zh = "飞行器的攻击会使敌人成为诱饵。", eid_en = "The Air Flight's attacks mark enemies as bait."},
	[637] = {zh = "拳击", en = "Punch", eid_zh = "飞行器发射拳击泪弹。", eid_en = "The Air Flight fires punch tears."},
}

-- 炸弹材料审计短名（与 FLAG_NAME 并列，供 effect_labels）
-- eid_*：接在「装载炸弹攻击模块时，生成的炸弹会……」后的谓语；或写完整句
M.BOMB_NAME = {
	[106] = {zh = "大炸弹", en = "Mr. Mega", eid_zh = "产生更大爆炸", eid_en = "create larger explosions"},
	[125] = {zh = "追踪炸弹", en = "Homing Bombs", eid_zh = "追踪敌人", eid_en = "home in on enemies"},
	[140] = {zh = "毒炸弹", en = "Poison Bombs", eid_zh = "施加毒素", eid_en = "apply poison"},
	[209] = {zh = "屁炸弹", en = "Butt Bombs", eid_zh = "释放毒气云", eid_en = "release poison clouds"},
	[220] = {zh = "悲伤炸弹", en = "Sad Bombs", eid_zh = "爆炸后额外发射泪弹", eid_en = "fire extra tears on explosion"},
	[256] = {zh = "火焰炸弹", en = "Hot Bombs", eid_zh = "留下火焰", eid_en = "leave fire"},
	[353] = {zh = "十字炸弹", en = "Bomber Boy", eid_zh = "以十字形爆炸", eid_en = "explode in a cross pattern"},
	[366] = {zh = "分裂炸弹", en = "Scatter Bombs", eid_zh = "分裂成小炸弹", eid_en = "split into smaller bombs"},
	[367] = {zh = "粘性炸弹", en = "Sticky Bombs", eid_zh = "粘附在敌人身上", eid_en = "stick to enemies"},
	[432] = {zh = "闪光炸弹", en = "Glitter Bombs", eid_zh = "有概率掉落拾取物", eid_en = "have a chance to drop pickups"},
	[517] = {zh = "快速炸弹", en = "Fast Bombs", eid_zh = "提高炸弹放置速度", eid_en = "be placed faster"},
	[563] = {zh = "南茜炸弹", en = "Nancy Bombs", eid_zh = "获得随机炸弹效果", eid_en = "gain random bomb effects"},
	[614] = {zh = "血炸弹", en = "Blood Bombs", eid_zh = "留下血迹", eid_en = "leave blood creep"},
	[646] = {zh = "硫磺炸弹", en = "Brimstone Bombs", eid_zh = "发射硫磺激光", eid_en = "fire Brimstone beams"},
	[727] = {zh = "幽灵炸弹", en = "Ghost Bombs", eid_zh = "带有幽灵特性", eid_en = "become spectral"},
}

-- C Section fetus secondary weapon flags (same bits as auxi Sec_buffs)
M.FETUS_SEC_FLAGS = {
	[579] = BitSet128(0, 1 << (107 - 64)),
	[114] = BitSet128(0, 1 << (109 - 64)),
	[395] = BitSet128(0, 1 << (110 - 64)),
	[68] = BitSet128(0, 1 << (111 - 64)),
	[118] = BitSet128(0, 1 << (112 - 64)),
	[52] = BitSet128(0, 1 << (113 - 64)),
}

-- 战斗相关 CacheFlags：只作审计候选；原版范围不再据此判定已实装。
-- 不含 TEARFLAG/WEAPON/FAMILIARS/FLYING——那些走 flag/morph/其它表
M.STAT_CACHE_MASK = CacheFlag.CACHE_DAMAGE
	| CacheFlag.CACHE_FIREDELAY
	| CacheFlag.CACHE_SHOTSPEED
	| CacheFlag.CACHE_RANGE
	| CacheFlag.CACHE_SPEED
	| CacheFlag.CACHE_LUCK

-- Additive / multiplicative stat deltas（内部单位；见文件头 STAT_DELTA 约定）
-- Multishot tears themselves are in build_multishot; muls stay here.
-- 原版有 CacheFlags 但未列入本表：不再标为已实装，改进审计「缺数值」列表。
--
-- 字段成对：加算 + 对应 mul（加算后各乘区独立相乘）
--   damage/damage_mul, firedelay/firedelay_mul, shotspeed/shotspeed_mul,
--   range/range_mul, speed/speed_mul, luck/luck_mul
-- firedelay_mul 乘的是 Tear Delay（不是 Fire Rate）。
-- 来源：craft_stat_batch_*.lua（仅 verify=ok 非空 delta）+ legacy MEAT!/Almond Milk
-- 条件/动态/临时（ok_conditional|ok_dynamic|ok_temp|ok_chance）未导入，见 HANDOFF
M.STAT_DELTA = {
	[1] = {firedelay = -0.7}, -- The Sad Onion
	[2] = {firedelay_mul = 2.1}, -- The Inner Eye
	[4] = {damage = 0.5, damage_mul = 1.5}, -- Cricket's Head
	[5] = {damage = 1.5, range = 60, range_mul = 2, shotspeed_mul = 1.6, luck = -1}, -- My Reflection
	[6] = {firedelay = -1.5, range = -60, range_mul = 0.8}, -- Number One
	[7] = {damage = 1}, -- Blood of the Martyr
	[12] = {damage = 0.3, damage_mul = 1.5, range = 100, speed = 0.3}, -- Magic Mushroom
	[13] = {speed = 0.2}, -- The Virus
	[14] = {range = 100, speed = 0.3}, -- Roid Rage
	[27] = {speed = 0.3}, -- Wooden Spoon
	[28] = {speed = 0.3}, -- The Belt
	[29] = {range = 100}, -- Mom's Underwear
	[30] = {range = 100}, -- Mom's Heels
	[31] = {range = 150}, -- Mom's Lipstick
	[32] = {firedelay = -0.7}, -- Wire Coat Hanger
	[46] = {luck = 1}, -- Lucky Foot
	[50] = {damage = 1}, -- Steven
	[51] = {damage = 1}, -- Pentagram
	[62] = {damage = 0.3}, -- Charm of the Vampire
	[70] = {damage = 1, speed = 0.2}, -- Growth Hormones
	[71] = {range = 100, speed = 0.3}, -- Mini Mush
	[72] = {firedelay = -0.5}, -- Rosary
	[79] = {damage = 1, speed = 0.2}, -- The Mark
	[80] = {damage = 0.5, firedelay = -0.7}, -- The Pact
	[82] = {speed = 0.3}, -- Lord of the Pit
	[90] = {damage = 1, firedelay = -0.2, speed = -0.2}, -- The Small Rock
	[101] = {damage = 0.3, firedelay = -0.2, range = 60, speed = 0.3}, -- The Halo
	[110] = {range = 60}, -- Mom's Contacts
	[115] = {firedelay = -0.5}, -- Ouija Board
	[119] = {speed = 0.3}, -- Blood Bag
	[120] = {damage = -0.4, damage_mul = 0.9, firedelay = -1.7, speed = 0.3}, -- Odd Mushroom (Thin)
	[121] = {damage = 1, range = 60, speed = -0.2}, -- Odd Mushroom (Large)
	[129] = {speed = -0.2}, -- Bucket of Lard
	[138] = {damage = 0.3}, -- Stigmata
	[143] = {shotspeed = 0.2, speed = 0.3}, -- Speed Ball
	[149] = {damage = 40, firedelay_mul = 3, shotspeed_mul = 0.8, range_mul = 0.8}, -- Ipecac
	[152] = {firedelay_mul = 1.5}, -- Technology 2（EID FR x0.67 ≈ 1.5）
	[153] = {firedelay_mul = 2.1}, -- Mutant Spider
	-- 154 Chemical Peel：左眼 +2，见 ONE_EYE
	[165] = {damage = 1, shotspeed = 0.23}, -- Cat-o-nine-tails
	[169] = {damage = 4, damage_mul = 2, firedelay_mul = 2.1, scale_mul = 2}, -- Polyphemus
	[176] = {shotspeed = 0.16}, -- Stem Cells
	[182] = {damage = 1, damage_mul = 2.3, firedelay = 0.4, shotspeed = -0.25}, -- Sacred Heart
	[183] = {firedelay = -0.7, shotspeed = 0.16}, -- Tooth Picks
	[189] = {damage = 0.3, firedelay = -0.2, range = 100, speed = 0.2}, -- SMB Super Fan
	[193] = {damage = 0.3}, -- MEAT!（批次未收录，legacy 保留）
	[194] = {shotspeed = 0.16}, -- Magic 8 Ball
	[196] = {firedelay = -0.4}, -- Squeezy
	[197] = {damage = 0.5, range = 60}, -- Jesus Juice
	[201] = {damage = 0.3}, -- Iron Bar
	[206] = {damage = 1, firedelay = -0.5}, -- Guillotine
	[208] = {damage = 1}, -- Champion Belt
	[213] = {shotspeed = -0.15}, -- Lost Contact
	[214] = {range = 60}, -- Anemic
	[216] = {damage = 1}, -- Ceremonial Robes
	[222] = {firedelay = -1}, -- Anti-Gravity（TEAR_WAIT 另见 flag 表）
	[224] = {firedelay = -0.5, range_mul = 0.8}, -- Cricket's Body
	[228] = {firedelay = -0.5, once = true}, -- Mom's Perfume：+0.5 FR，多份不叠加
	-- 229 Monstro's Lung：射速不进 STAT（兼容副件时不应 ×4）；主武为肺时见 WEAPON_FIRE_DELAY_MUL
	[230] = {damage = 1.5, speed = 0.2}, -- Abaddon
	[232] = {speed = 0.3}, -- Stop Watch
	[233] = {range = 260}, -- Tiny Planet
	[237] = {damage = 1.5, firedelay = 0.3}, -- Death's Touch
	[245] = {damage_mul = 0.8}, -- 20/20
	[253] = {luck = 1}, -- Magic Scab
	-- 254 Blood Clot：左眼，见 ONE_EYE
	[255] = {firedelay = -0.5, shotspeed = 0.2}, -- Screw
	[259] = {damage = 1}, -- Dark Matter
	[261] = {damage = 0.5}, -- Proptosis（近距 3x 衰减为行为层，未建模）
	[299] = {speed = -0.3}, -- Taurus
	[300] = {speed = 0.25}, -- Aries
	[306] = {speed = 0.2}, -- Sagittarius
	[307] = {damage = 0.5, firedelay = -0.5, range = 30, speed = 0.1}, -- Capricorn
	[309] = {firedelay = -0.5}, -- Pisces
	[310] = {damage_mul = 2, firedelay_mul = 1.5, shotspeed = -0.5}, -- Eve's Mascara
	[314] = {speed = -0.4}, -- Thunder Thighs（踩石/生命不进档案）
	[328] = {damage = 1}, -- The Negative
	[329] = {shotspeed = 0.2}, -- The Ludovico Technique
	[330] = {damage_mul = 0.2, firedelay_mul = 1 / 5.5, scale_mul = 0.4}, -- Soy Milk
	[331] = {damage = 0.5, firedelay = 0.3, shotspeed = -0.3}, -- Godhead
	[336] = {shotspeed = -0.4, range = -60}, -- Dead Onion
	[339] = {shotspeed = 0.16, range = 100}, -- Safety Pin
	[340] = {speed = 0.3}, -- Caffeine Pill
	[341] = {firedelay = -0.7, shotspeed = 0.16}, -- Torn Photo
	[342] = {firedelay = -0.7, shotspeed = -0.16}, -- Blue Cap
	[343] = {luck = 1}, -- Latch Key
	[345] = {damage = 1, range = 100}, -- Synthoil
	[355] = {range = 100, luck = 1}, -- Mom's Pearls
	[359] = {damage = 1.5}, -- 8 Inch Nails
	[369] = {range = 120}, -- Continuum
	[370] = {firedelay = -0.7, range = 100}, -- Mr. Dolly
	[381] = {firedelay = -0.7}, -- Eden's Blessing
	[394] = {firedelay = -0.7, range = 120}, -- Marked
	[397] = {firedelay = -1, shotspeed = 0.16, range = 100}, -- Tractor Beam
	[417] = {damage_mul = 1.5}, -- Succubus：制造档案直接采用光环内 +50% 伤害
	[438] = {firedelay = -0.75}, -- Binky（体型见 body_scale_mul）
	[443] = {firedelay = -0.3}, -- Apple!
	[445] = {damage = 0.3, speed = 0.1}, -- Dog Tooth
	[453] = {range = 60}, -- Compound Fracture
	[455] = {range = 100}, -- Dad's Lost Coin
	[462] = {range = 60}, -- Eye of Belial
	[463] = {damage = 0.3}, -- Sulfuric Acid
	[465] = {firedelay = -0.3}, -- Analog Stick
	[492] = {luck = 1}, -- YO LISTEN!
	[513] = {damage = 0.1}, -- Bozo
	[531] = {damage = 1, damage_mul = 1.5, firedelay_mul = 3, range_mul = 0.8}, -- Haemolacria
	[547] = {firedelay = -0.7}, -- Divorce Papers
	[554] = {firedelay = -0.5, shotspeed = 0.2}, -- 2Spooky
	[561] = {damage_mul = 0.33, firedelay_mul = 0.33, scale_mul = 0.5}, -- Almond Milk（批次未收录，legacy 保留）
	[564] = {firedelay = -0.5, shotspeed = 0.2}, -- A Bar of Soap
	[571] = {speed = 0.3}, -- Orphan Socks
	[572] = {damage = 1, range = 80, shotspeed = -0.16}, -- Eye of the Occult
	[573] = {damage_mul = 1.2}, -- Immaculate Heart（额外环绕泪见 AF）
	[590] = {speed = 0.4}, -- Mercury（水星）：开门行为不进档案；无条件移速正常计入
	[592] = {damage = 1}, -- Terra
	[594] = {speed = -0.3}, -- Jupiter（静止积蓄见动态）
	[598] = {firedelay = -0.7}, -- Pluto（+0.7 tears 近似；体型见 body_scale）
	[601] = {firedelay = -0.7}, -- Act of Contrition
	-- 605 The Scooper：右眼，见 ONE_EYE
	[632] = {luck = 2}, -- Evil Charm
	[633] = {damage = 2, speed = 0.1}, -- Dogma
	[659] = {range = 100, scale_add = 0.22}, -- Tropicamide
	[669] = {damage = 0.5, firedelay = -0.5, shotspeed = 0.16, range = 100, speed = 0.2, luck = 1}, -- Sausage
	[688] = {speed = 0.2}, -- Inner Child（体型见 body_scale；额外生命不复制）
	[708] = {damage = 1}, -- Stapler
	[730] = {damage = 0.75, luck = 1}, -- Glass Eye
	-- 731 Stye：右眼，见 ONE_EYE
	[732] = {damage = 1}, -- Mom's Ring
}

-- 单眼加成：side 0=左 1=右；不进常驻 STAT_DELTA，开火时按眼睛相位叠加
-- label 写入描述「特效」行
M.ONE_EYE = {
	[154] = {side = 0, damage = 2, blood_variant = true, zh = "化学剥皮(左)", en = "ChemPeel(L)"},
	[155] = {side = 0, damage_mul = 1.35, blood_variant = true, once = true, zh = "窥眼(左)", en = "Peeper(L)"},
	[254] = {side = 0, damage = 1, range = 110, blood_variant = true, zh = "血块(左)", en = "BloodClot(L)"},
	[605] = {side = 1, damage_mul = 1.35, zh = "挖眼勺(右)", en = "Scooper(R)"},
	[731] = {side = 1, damage_mul = 1.28, shotspeed = -0.3, range = 260, zh = "麦粒肿(右)", en = "Stye(R)"},
}

-- EXTRA_IMPL 在描述页显示的短名（有特效的至少能看见）
M.EXTRA_NAME = {
	tech2 = {zh = "科技2", en = "Technology 2"},
	tech5 = {zh = "科技0.5", en = "Technology 0.5"},
	chocolate = {zh = "巧克力奶", en = "Chocolate Milk"},
	cursed_eye = {zh = "诅咒眼", en = "Cursed Eye"},
	dollar_bill = {zh = "三美元钞票", en = "$3 Bill"},
	moms_wig = {zh = "妈妈的假发", en = "Mom's Wig"},
	hive_mind = {zh = "虫群之心", en = "Hive Mind"},
	epiphora = {zh = "溢泪症", en = "Epiphora"},
	dead_eye = {zh = "死眼", en = "Dead Eye"},
	fruit_cake = {zh = "水果蛋糕", en = "Fruit Cake"},
	almond_milk = {zh = "杏仁奶", en = "Almond Milk"},
	parasitoid = {zh = "拟寄生物", en = "Parasitoid"},
	tough_love = {zh = "严厉的爱", en = "Tough Love"},
	apple = {zh = "苹果！", en = "Apple!"},
	lead_pencil = {zh = "铅笔", en = "Lead Pencil"},
	eye_of_greed = {zh = "贪婪的眼睛", en = "Eye of Greed"},
	candle = {zh = "蜡烛", en = "Candle"},
	eye = {zh = "眼瘤", en = "Eye Sore"},
	eye_drops = {zh = "眼药水", en = "Eye Drops"},
	money_is_power = {zh = "金钱就是力量", en = "Money = Power"},
	whore_of_babylon = {zh = "大淫妇", en = "Whore of Babylon"},
	bloody_lust = {zh = "嗜血", en = "Bloody Lust"},
	bloody_gust = {zh = "血怒", en = "Bloody Gust"},
	experimental = {zh = "实验性针剂", en = "Experimental Treatment"},
	libra = {zh = "天平", en = "Libra"},
	zodiac = {zh = "十二宫", en = "Zodiac"},
	taurus = {zh = "金牛座", en = "Taurus"},
	purity = {zh = "白莲花", en = "Purity"},
	lusty_blood = {zh = "杀戮嗜血", en = "Lusty Blood"},
	crown_of_light = {zh = "白王冠", en = "Crown of Light"},
	dark_princes_crown = {zh = "黑王冠", en = "Dark Prince's Crown"},
	adrenaline = {zh = "肾上腺素", en = "Adrenaline"},
	chemical_peel = {zh = "化学剥皮(左)", en = "Chemical Peel (L)"},
	peeper = {zh = "窥眼(左)", en = "Peeper (L)"},
	blood_clot = {zh = "血块(左)", en = "Blood Clot (L)"},
	scooper = {zh = "挖眼勺(右)", en = "Scooper (R)"},
	stye = {zh = "麦粒肿(右)", en = "Stye (R)"},
	kidney = {zh = "肾结石", en = "Kidney Stone"},
	number_two = {zh = "2号", en = "No. 2"},
	milk = {zh = "牛奶", en = "Milk!"},
	camo_undies = {zh = "迷彩", en = "Camo Undies"},
	jupiter = {zh = "木星", en = "Jupiter"},
	paschal_candle = {zh = "逾越节蜡烛", en = "Paschal Candle"},
	rock_bottom = {zh = "谷底石", en = "Rock Bottom"},
	red_stew = {zh = "红豆汤", en = "Red Stew"},
	candy_heart = {zh = "糖心", en = "Candy Heart"},
	soul_locket = {zh = "灵魂吊坠", en = "Soul Locket"},
	heartbreak = {zh = "心碎", en = "Heartbreak"},
	keepers_sack = {zh = "店长袋", en = "Keeper's Sack"},
	immaculate_heart = {zh = "无暇之心", en = "Immaculate Heart"},
	occult_eye = {zh = "可控泪弹", en = "Eye of the Occult"},
	occult_eye_stats = {zh = "玄秘(属性)", en = "Occult (stats)"},
	neptunus = {zh = "海王星", en = "Neptunus"},
	binge_eater = {zh = "大胃王", en = "Binge Eater"},
	false_phd = {zh = "假博士", en = "False PHD"},
	moms_eye = {zh = "妈妈的眼睛", en = "Mom's Eye"},
	lokis_horns = {zh = "洛基的角", en = "Loki's Horns"},
	one_up = {zh = "一命复活", en = "1up!"},
	dead_cat = {zh = "九命复活", en = "Dead Cat"},
	inner_child = {zh = "内在小孩", en = "Inner Child"},
	guppys_collar = {zh = "猫项圈", en = "Guppy's Collar"},
	lazarus_rags = {zh = "拉撒路的破布", en = "Lazarus' Rags"},
	ankh = {zh = "安卡十字", en = "Ankh"},
	judas_shadow = {zh = "犹大的影子", en = "Judas' Shadow"},
	cube_of_meat = {zh = "肉块", en = "Cube of Meat"},
	ball_of_bandages = {zh = "绷带球", en = "Ball of Bandages"},
	black_bean = {zh = "黑豆", en = "The Black Bean"},
	anemic = {zh = "贫血", en = "Anemic"},
	varicose_veins = {zh = "静脉曲张", en = "Varicose Veins"},
	it_hurts = {zh = "痛痛", en = "It Hurts"},
	large_zit = {zh = "大青春痘", en = "Large Zit"},
	linger_bean = {zh = "流连豆", en = "Linger Bean"},
	dead_tooth = {zh = "烂牙", en = "Dead Tooth"},
	monstrance = {zh = "圣体匣", en = "Monstrance"},
	volt_120 = {zh = "120伏特", en = "120 Volt"},
	circle_of_protection = {zh = "保护之环", en = "Circle of Protection"},
	maw_of_the_void = {zh = "虚空之口", en = "Maw of the Void"},
	-- athame = {zh = "献祭之刃", en = "Athame"}, -- 受伤环已废止 2026-08-16
	revelation = {zh = "启示", en = "Revelation"},
	saturnus = {zh = "土星", en = "Saturnus"},
	evil_eye = {zh = "邪眼", en = "Evil Eye"},
	spear_of_destiny = {zh = "命运长枪", en = "Spear of Destiny"},
	trinity_shield = {zh = "三位一体盾", en = "Trinity Shield"},
	swarm = {zh = "苍蝇军团", en = "The Swarm"},
	vengeful_spirit = {zh = "复仇之火", en = "Vengeful Spirit"},
	guppys_hairball = {zh = "毛球", en = "Guppy's Hairball"},
	holy_water = {zh = "圣水", en = "Holy Water"},
	best_bud = {zh = "好朋友", en = "Best Bud"},
	leprosy = {zh = "麻风病", en = "Leprosy"},
	halo_of_flies = {zh = "苍蝇光环", en = "Halo of Flies"},
	distant_admiration = {zh = "仰慕之交", en = "Distant Admiration"},
	guardian_angel = {zh = "守护天使", en = "Guardian Angel"},
	forever_alone = {zh = "永远孤独", en = "Forever Alone"},
	sacrificial_dagger = {zh = "献祭匕首", en = "Sacrificial Dagger"},
	big_fan = {zh = "大粉丝", en = "Big Fan"},
	friend_zone = {zh = "朋友区", en = "Friend Zone"},
	moms_razor = {zh = "妈妈的剃刀", en = "Mom's Razor"},
	slipped_rib = {zh = "滑肋骨", en = "Slipped Rib"},
	sworn_protector = {zh = "宣誓守护者", en = "Sworn Protector"},
	censer = {zh = "香炉", en = "Censer"},
	smart_fly = {zh = "聪明苍蝇", en = "Smart Fly"},
	bloodshot_eye = {zh = "血丝眼", en = "Bloodshot Eye"},
	angelic_prism = {zh = "天使棱镜", en = "Angelic Prism"},
	pointy_rib = {zh = "尖肋骨", en = "Pointy Rib"},
	psy_fly = {zh = "灵能苍蝇", en = "Psy Fly"},
	bot_fly = {zh = "机器苍蝇", en = "Bot Fly"},
	tinytoma = {zh = "小托马", en = "Tinytoma"},
	papa_fly = {zh = "爸爸的苍蝇", en = "Papa Fly"},
	multidimensional_baby = {zh = "多维宝宝", en = "Multidimensional Baby"},
	finger = {zh = "手指！", en = "Finger!"},
	depression = {zh = "抑郁症", en = "Depression"},
	headless_baby = {zh = "无头宝宝", en = "Headless Baby"},
	farting_baby = {zh = "屁屁宝宝", en = "Farting Baby"},
	boiled_baby = {zh = "沸腾宝宝", en = "Boiled Baby"},
	juicy_sack = {zh = "多汁的袋子", en = "Juicy Sack"},
	bobs_brain = {zh = "鲍勃的脑浆", en = "Bob's Brain"},
	dry_baby = {zh = "干瘪宝宝", en = "Dry Baby"},
	obsessed_fan = {zh = "着迷的粉丝", en = "Obsessed Fan"},
	lil_spewer = {zh = "小吐根", en = "Lil Spewer"},
	hallowed_ground = {zh = "圣洁之地", en = "Hallowed Ground"},
	my_shadow = {zh = "我的影子", en = "My Shadow"},
	shade = {zh = "阴影", en = "Shade"},
	guillotine = {zh = "断头台", en = "Guillotine"},
	king_baby = {zh = "国王宝宝", en = "King Baby"},
	-- 第二组资源宝宝
	sack_of_pennies = {zh = "硬币袋", en = "Sack of Pennies"},
	little_chad = {zh = "查德宝宝", en = "Little C.H.A.D."},
	relic = {zh = "圣遗物", en = "The Relic"},
	bomb_bag = {zh = "炸弹袋", en = "Bomb Bag"},
	mystery_sack = {zh = "神秘袋", en = "Mystery Sack"},
	lil_chest = {zh = "小宝箱", en = "Lil Chest"},
	charged_baby = {zh = "充电宝宝", en = "Charged Baby"},
	rune_bag = {zh = "符文袋", en = "Rune Bag"},
	acid_baby = {zh = "毒瘾宝宝", en = "Acid Baby"},
	sack_of_sacks = {zh = "袋中袋", en = "Sack of Sacks"},
	mystery_egg = {zh = "神秘的卵", en = "Mystery Egg"},
}

-- Behavioral extras used by Air Flight / list (not pure stats/flags).
M.EXTRA_IMPL = {
	[2] = "multishot",
	-- §16.7 第一批泪弹宝宝 → Craft_Familiar_holder 绑定 Air Flight
	[8] = "brother_bobby",
	[11] = "one_up", -- 1up!：MeusNil 跟随；配方缺失坠毁后可复活一次
	[67] = "sister_maggy",
	[81] = "dead_cat", -- Dead Cat：MeusNil 跟随；制造坠毁可复活 9 次
	[99] = "little_gish",
	[100] = "little_steven",
	[161] = "ankh", -- Ankh：无跟随；制造坠毁可复活一次
	[163] = "ghost_baby",
	[167] = "harlequin_baby",
	[174] = "rainbow_baby",
	[206] = "guillotine",
	[212] = "guppys_collar", -- Guppy's Collar：无跟随；制造坠毁 50% 复活（不耗次数）
	[268] = "rotten_baby",
	[311] = "judas_shadow", -- Judas' Shadow：无跟随；制造坠毁可复活一次
	[322] = "mongo_baby",
	[332] = "lazarus_rags", -- Lazarus' Rags：无跟随；制造坠毁可复活一次
	[361] = "fates_reward",
	[390] = "seraphim",
	[417] = "succubus",
	[435] = "lil_loki",
	[472] = "king_baby",
	[608] = "freezer_baby",
	[688] = "inner_child", -- Inner Child：无跟随；制造坠毁可复活一次（体型仍走 BODY_SCALE_MUL）
	-- §16.7 第二批激光/近距
	[95] = "robo_baby",
	[113] = "demon_baby",
	[267] = "robo_baby_2",
	[69] = "chocolate",
	[152] = "tech2",
	[153] = "multishot",
	[154] = "chemical_peel",
	[155] = "peeper",
	[55] = "moms_eye", -- Mom's Eye：volley 向后额外弹
	[87] = "lokis_horns", -- Loki's Horns：volley 另三正方向
	[318] = "gemini",
	[319] = "cains_other_eye",
	[360] = "incubus",
	[698] = "twisted_pair",
	-- 蓄力 / 冲刺宝宝批次
	[275] = "lil_brimstone",
	[679] = "lil_abaddon",
	[471] = "lil_monstro",
	[88] = "little_chubby",
	[473] = "big_chubby",
	[384] = "lil_gurdy",
	-- Flight orbital / on-hurt 批次
	[73] = "cube_of_meat",
	[207] = "ball_of_bandages",
	[180] = "black_bean",
	[214] = "anemic",
	[452] = "varicose_veins",
	[560] = "it_hurts",
	[502] = "large_zit",
	[447] = "linger_bean",
	[446] = "dead_tooth",
	[574] = "monstrance",
	[559] = "volt_120",
	[423] = "circle_of_protection",
	[399] = "maw_of_the_void",
	-- [408] = "athame", -- 受伤环已废止 2026-08-16
	[643] = "revelation",
	[595] = "saturnus",
	[410] = "evil_eye",
	[243] = "trinity_shield",
	[400] = "spear_of_destiny",
	[693] = "swarm",
	[702] = "vengeful_spirit",
	[392] = "zodiac",
	[299] = "taurus",
	[187] = "guppys_hairball",
	[178] = "holy_water",
	[274] = "best_bud",
	[525] = "leprosy",
	[10] = "halo_of_flies",
	[57] = "distant_admiration",
	[112] = "guardian_angel",
	[128] = "forever_alone",
	[172] = "sacrificial_dagger",
	[279] = "big_fan",
	[364] = "friend_zone",
	[508] = "moms_razor",
	[542] = "slipped_rib",
	[363] = "sworn_protector",
	[387] = "censer",
	[264] = "smart_fly",
	[509] = "bloodshot_eye",
	[528] = "angelic_prism",
	[544] = "pointy_rib",
	[581] = "psy_fly",
	[629] = "bot_fly",
	[645] = "tinytoma",
	[430] = "papa_fly",
	[431] = "multidimensional_baby",
	[467] = "finger",
	[469] = "depression",
	[269] = "headless_baby",
	[404] = "farting_baby",
	[607] = "boiled_baby",
	[266] = "juicy_sack",
	[273] = "bobs_brain",
	[265] = "dry_baby",
	[426] = "obsessed_fan",
	[537] = "lil_spewer",
	[543] = "hallowed_ground",
	[433] = "my_shadow",
	[468] = "shade",
	-- 第二组资源宝宝
	[94] = "sack_of_pennies",
	[96] = "little_chad",
	[98] = "relic",
	[131] = "bomb_bag",
	[271] = "mystery_sack",
	[362] = "lil_chest",
	[372] = "charged_baby",
	[389] = "rune_bag",
	[491] = "acid_baby",
	[500] = "sack_of_sacks",
	[539] = "mystery_egg",
	[229] = "lung",
	[244] = "tech5",
	[245] = "multishot",
	[254] = "blood_clot",
	[316] = "cursed_eye",
	[358] = "multishot",
	[191] = "dollar_bill",
	[217] = "moms_wig",
	[248] = "hive_mind", -- 虫群之心：有妈假发时条件亮起，蓝蜘蛛上限 5→10
	[240] = "experimental",
	[304] = "libra",
	[368] = "epiphora",
	[373] = "dead_eye",
	[378] = "number_two", -- No. 2：持续攻击掉落大便炸弹（受配方 BOMB_EFFECTS 影响，不进炸弹门控）
	[407] = "purity",
	[411] = "lusty_blood",
	[415] = "crown_of_light",
	[418] = "fruit_cake",
	[561] = "almond_milk", -- Almond Milk：每泪随机 1–2 个打包 TearFlag
	[440] = "kidney",
	[442] = "dark_princes_crown",
	[150] = "tough_love", -- Tough Love：概率 TearVariant.TOOTH + 3.2×伤
	[443] = "apple", -- Apple!：概率 TearVariant.RAZOR + 4×伤
	[444] = "lead_pencil", -- Lead Pencil：仅右眼、50%血泪、每15发喷12血泪
	[450] = "eye_of_greed", -- Eye of Greed：每20发额外金币泪
	[461] = "parasitoid",
	[493] = "adrenaline",
	[495] = "candle",
	[558] = "eye", -- Eye Sore：volley 概率随机方向额外弹
	[600] = "eye_drops",
	[605] = "scooper",
	[616] = "candle",
	[678] = "fetus",
	[731] = "stye",
	-- 动态条件（数值由 craft_dynamic_stats 注入，避免缺数值黄标）
	[109] = "money_is_power",
	[122] = "whore_of_babylon",
	[157] = "bloody_lust",
	[695] = "bloody_gust",
	-- 第三批
	[436] = "milk",
	[497] = "camo_undies",
	[562] = "rock_bottom",
	[567] = "paschal_candle",
	[572] = "occult_eye",
	[573] = "immaculate_heart",
	[594] = "jupiter",
	[597] = "neptunus",
	[621] = "red_stew",
	[671] = "candy_heart",
	[686] = "soul_locket",
	[694] = "heartbreak",
	[716] = "keepers_sack",
	[664] = "binge_eater",
	[654] = "false_phd",
}

-- 制造坠毁复活（与 temporary_revive_manager 玩家临时复活分流）
-- follower：MeusNil 展示；uses=0 + chance：概率源（成功不耗次数，仍锁定配方）
M.CRAFT_REVIVE_SOURCES = {
	{
		key = "one_up",
		id = CollectibleType.COLLECTIBLE_1UP or 11,
		uses = 1,
		follower = true,
		familiar_variant = FamiliarVariant.ONE_UP,
		anm2 = "gfx/003.041_1up.anm2",
		anim = "Float",
	},
	{
		key = "dead_cat",
		id = CollectibleType.COLLECTIBLE_DEAD_CAT or 81,
		uses = 9,
		follower = true,
		familiar_variant = FamiliarVariant.DEAD_CAT,
		anm2 = "gfx/003.040_dead cat.anm2",
		anim = "Float",
	},
	{
		key = "inner_child",
		id = CollectibleType.COLLECTIBLE_INNER_CHILD or 688,
		uses = 1,
		follower = false,
	},
	{
		key = "guppys_collar",
		id = CollectibleType.COLLECTIBLE_GUPPYS_COLLAR or 212,
		uses = 0,
		chance = 50,
		follower = false,
	},
	{
		key = "lazarus_rags",
		id = CollectibleType.COLLECTIBLE_LAZARUS_RAGS or 332,
		uses = 1,
		follower = false,
	},
	{
		key = "ankh",
		id = CollectibleType.COLLECTIBLE_ANKH or 161,
		uses = 1,
		follower = false,
	},
	{
		key = "judas_shadow",
		id = CollectibleType.COLLECTIBLE_JUDAS_SHADOW or 311,
		uses = 1,
		follower = false,
	},
}

M.CRAFT_REVIVE_ID_SET = {}
M.CRAFT_REVIVE_BY_KEY = {}
for _, src in ipairs(M.CRAFT_REVIVE_SOURCES) do
	M.CRAFT_REVIVE_ID_SET[src.id] = src.key
	M.CRAFT_REVIVE_BY_KEY[src.key] = src
end

function M.craft_revive_get_spent(rec)
	if not rec then return {} end
	local spent = rec.craft_revive_spent
	if type(spent) ~= "table" then
		spent = {}
		rec.craft_revive_spent = spent
	end
	-- 旧字段迁移
	if rec.one_up_spent and (tonumber(spent.one_up) or 0) < 1 then
		spent.one_up = 1
	end
	return spent
end

function M.craft_revive_source_spent(rec, key)
	if not key then return 0 end
	local spent = M.craft_revive_get_spent(rec)
	return tonumber(spent[key]) or 0
end

function M.craft_revive_is_locked(rec)
	return rec ~= nil and rec.craft_revive_locked == true
end

function M.craft_revive_recipe_has(craft_prof, rec, src)
	if not src then return false end
	if craft_prof and craft_prof.extras and craft_prof.extras[src.key] == true then
		return true
	end
	local counts = craft_prof and craft_prof.counts
	if type(counts) == "table" and (tonumber(counts[src.id]) or 0) > 0 then
		return true
	end
	if rec and type(rec.ingredients) == "table" then
		local c = M.counts_from_ingredients(rec.ingredients)
		return (tonumber(c[src.id]) or 0) > 0
	end
	return false
end

--- 复活道具仍在玩家身上（真实持有）；消失后不得再救飞行器 / 不得用 MeusNil 冒充
function M.craft_revive_player_has(player, src)
	if not player or not src or not src.id then return false end
	local n = player.GetCollectibleNum and player:GetCollectibleNum(src.id, true)
	return (tonumber(n) or 0) > 0
end

function M.craft_revive_remaining(rec, src)
	if not src then return 0 end
	if src.chance then return 1 end -- 概率源每次可再掷
	local uses = tonumber(src.uses) or 0
	if uses <= 0 then return 0 end
	local used = M.craft_revive_source_spent(rec, src.key)
	local left = uses - used
	if left < 0 then left = 0 end
	return left
end

function M.craft_revive_follower_dimmed(rec, src)
	if not src or not src.follower then return false end
	local uses = tonumber(src.uses) or 0
	if uses <= 0 then return false end
	return M.craft_revive_source_spent(rec, src.key) >= uses
end

--- 坠毁触发时选源：配方有 +（玩家仍持有 或 audit/prototype 虚拟源）；确定次数优先；项圈失败则继续尝试后续源
function M.craft_revive_try_pick(craft_prof, rec, player)
	for _, src in ipairs(M.CRAFT_REVIVE_SOURCES) do
		local available = M.craft_revive_player_has(player, src)
			or M.craft_has_virtual_source_for(rec, src.id)
		if M.craft_revive_recipe_has(craft_prof, rec, src) and available then
			if src.chance then
				local roll = Random() % 100
				if roll < (tonumber(src.chance) or 0) then
					return src
				end
			elseif M.craft_revive_remaining(rec, src) > 0 then
				return src
			end
		end
	end
	return nil
end

function M.craft_revive_spend(rec, src)
	if not rec or not src then return end
	local spent = M.craft_revive_get_spent(rec)
	local uses = tonumber(src.uses) or 0
	if uses > 0 then
		spent[src.key] = (tonumber(spent[src.key]) or 0) + 1
	end
	rec.craft_revive_locked = true
	rec.one_up_spent = (tonumber(spent.one_up) or 0) > 0 or nil
end

--- 蓝图确认修改：解除锁定；已不在配方中的源清 spent
function M.craft_revive_on_confirm(rec, profile)
	if not rec then return end
	rec.craft_revive_locked = nil
	local spent = rec.craft_revive_spent
	if type(spent) ~= "table" then
		rec.one_up_spent = nil
		return
	end
	local extras = profile and profile.extras or {}
	local counts = profile and profile.counts or {}
	for key, _ in pairs(spent) do
		local src = M.CRAFT_REVIVE_BY_KEY[key]
		local keep = extras[key] == true
		if not keep and src then
			keep = (tonumber(counts[src.id]) or 0) > 0
		end
		if not keep then
			spent[key] = nil
		end
	end
	rec.one_up_spent = (tonumber(spent.one_up) or 0) > 0 or nil
end

--- Flight 从 broken 真正恢复为有效时，为仍装载的一次性复活源开启新一轮充能。
--- 必须由完整性检查确认 repaired 后调用；普通面板确认不得调用。
function M.craft_revive_on_repaired(rec, profile)
	if not rec then return end
	local spent = rec.craft_revive_spent
	if type(spent) == "table" then
		local extras = profile and profile.extras or {}
		local counts = profile and profile.counts or {}
		for key, _ in pairs(spent) do
			local src = M.CRAFT_REVIVE_BY_KEY[key]
			local loaded = extras[key] == true
			if not loaded and src then
				loaded = (tonumber(counts[src.id]) or 0) > 0
			end
			if loaded then spent[key] = nil end
		end
	end
	rec.craft_revive_locked = nil
	rec.one_up_spent = nil
	rec.craft_revive_repair_epoch = (tonumber(rec.craft_revive_repair_epoch) or 0) + 1
end

function M.craft_revive_fx_label(key, rec, zh)
	local src = M.CRAFT_REVIVE_BY_KEY[key]
	local base = M.EXTRA_NAME[key]
	local name = base and (zh and base.zh or base.en) or key
	if not src or not rec then return name end
	if src.chance then return name end
	local uses = tonumber(src.uses) or 0
	if uses <= 0 then return name end
	local used = M.craft_revive_source_spent(rec, key)
	if used >= uses then
		return zh and (name .. "(已用尽)") or (name .. "(spent)")
	end
	if used > 0 then
		local left = uses - used
		return zh and (name .. "(剩" .. tostring(left) .. ")") or (name .. "(left" .. tostring(left) .. ")")
	end
	return name
end

-- 审计「缺数值」明确排除（非可移植战斗加算 / 行为待办）
M.STAT_AUDIT_EXCLUDE = {
	[3] = true, -- Spoon Bender：追踪已由 TEAR_HOMING 实装，无独立数值
	[75] = true, -- PHD：治疗/胶囊/献血机效果，不提供 Flight 战斗属性
	[132] = true, -- Lump of Coal：距离成长由 TEAR_GROW 实装
	[215] = true, -- Goat Head
	[258] = true, -- Missing No.
	[260] = true, -- Black Candle
	[262] = true, -- Missing Page 2
	[344] = true, -- Match Book
	[440] = true, -- Kidney Stone 无常驻静态属性；卡住/结石/喷射由 Air Flight 实装
	[538] = true, -- Marbles
	[540] = true, -- Flat Stone：反弹/溅射由 TEAR_HYDROBOUNCE 实装
	[619] = true, -- Birthright（按角色单独兼容）
	[692] = true, -- Sanguine Bond（恶魔房献祭尖刺/奖励，不是 Flight 属性）
}

-- 飞行器视觉体型（不复用弹体 stats.scale）
M.BODY_SCALE_MUL = {
	[12] = 1.25, -- Magic Mushroom
	[71] = 0.8, -- Mini Mush
	[438] = 0.85, -- Binky
	[598] = 0.5, -- Pluto（勿用 597 Neptunus）
	[688] = 0.55, -- Inner Child
}

-- 制造宝宝 extras 键（与 adapter.extra_key / list 字段对应）
M.CRAFT_FAMILIAR_EXTRAS = {
	-- Peeper 不注册 Craft_Familiar adapter，保持原版斜向漂浮而非跟随 Flight。
	{key = "peeper", list = "peeper", zh = "窥眼", en = "Peeper", movement = "free"},
	{key = "gemini", list = "gemini", zh = "双子座", en = "Gemini", movement = "free", status = "testing"},
	{key = "incubus", list = "incubus", zh = "淫魔", en = "Incubus", movement = "follow"},
	{key = "cains_other_eye", list = "cains_other_eye", zh = "该隐的另一只眼", en = "Cain's Other Eye", movement = "follow"},
	{key = "twisted_pair", list = "twisted_pair", zh = "作孽双子", en = "Twisted Pair", movement = "follow"},
	{key = "brother_bobby", list = "bobby", zh = "波比弟弟", en = "Brother Bobby", movement = "follow"},
	{key = "sister_maggy", list = "maggy", zh = "玛姬妹妹", en = "Sister Maggy", movement = "follow"},
	{key = "little_steven", list = "steven", zh = "小史蒂文", en = "Little Steve", movement = "follow"},
	{key = "ghost_baby", list = "ghost_baby", zh = "幽灵宝宝", en = "Ghost Baby", movement = "follow"},
	{key = "harlequin_baby", list = "harlequin", zh = "小丑宝宝", en = "Harlequin Baby", movement = "follow"},
	{key = "lil_loki", list = "lil_loki", zh = "小洛基", en = "Lil Loki", movement = "follow"},
	{key = "little_gish", list = "gish", zh = "小吉什", en = "Little Gish", movement = "follow"},
	{key = "freezer_baby", list = "freezer", zh = "冰冻宝宝", en = "Freezer Baby", movement = "follow"},
	{key = "seraphim", list = "seraphim", zh = "六翼天使", en = "Seraphim", movement = "follow"},
	{key = "succubus", list = "succubus", zh = "魅魔", en = "Succubus", movement = "follow"},
	{key = "rainbow_baby", list = "rainbow", zh = "彩虹宝宝", en = "Rainbow Baby", movement = "follow"},
	{key = "rotten_baby", list = "rotten", zh = "腐烂宝宝", en = "Rotten Baby", movement = "follow"},
	{key = "mongo_baby", list = "mongo", zh = "蒙戈宝宝", en = "Mongo Baby", movement = "follow"},
	{key = "fates_reward", list = "fates_reward", zh = "宿命的报答", en = "Fate's Reward", movement = "follow"},
	{key = "robo_baby", list = "robo", zh = "机器人宝宝", en = "Robo-Baby", movement = "follow"},
	{key = "robo_baby_2", list = "robo2", zh = "机器人宝宝2.0", en = "Robo-Baby 2.0", movement = "follow"},
	{key = "demon_baby", list = "demon", zh = "恶魔宝宝", en = "Demon Baby", movement = "follow"},
	{key = "lil_brimstone", list = "lil_brimstone", zh = "小硫磺火", en = "Lil Brimstone", movement = "charge"},
	{key = "lil_abaddon", list = "lil_abaddon", zh = "亚巴顿宝宝", en = "Lil Abaddon", movement = "charge"},
	{key = "lil_monstro", list = "lil_monstro", zh = "萌死戳宝宝", en = "Lil Monstro", movement = "charge"},
	{key = "little_chubby", list = "little_chubby", zh = "小胖蛆", en = "Little Chubby", movement = "charge"},
	{key = "big_chubby", list = "big_chubby", zh = "大胖蛆", en = "Big Chubby", movement = "charge"},
	{key = "lil_gurdy", list = "lil_gurdy", zh = "肉山宝宝", en = "Lil Gurdy", movement = "charge"},
	-- also_fx：既有宝宝实体又有独立行为特效；宝宝行走 CRAFT_FAMILIAR，特效行走 EXTRA_NAME
	{key = "milk", list = "milk", zh = "牛奶", en = "Milk!", also_fx = true, movement = "follow"},
	{key = "one_up", list = "one_up", zh = "一命菇", en = "1up!", also_fx = true, movement = "follow"},
	{key = "dead_cat", list = "dead_cat", zh = "九命猫", en = "Dead Cat", also_fx = true, movement = "follow"},
	-- 第一组跟随/特效
	{key = "censer", list = "censer", zh = "香炉", en = "Censer", movement = "follow"},
	{key = "papa_fly", list = "papa_fly", zh = "爸爸的苍蝇", en = "Papa Fly", movement = "follow"},
	{key = "multidimensional_baby", list = "multidimensional_baby", zh = "多维宝宝", en = "Multidimensional Baby", movement = "follow"},
	{key = "depression", list = "depression", zh = "抑郁症", en = "Depression", movement = "follow"},
	{key = "headless_baby", list = "headless_baby", zh = "无头宝宝", en = "Headless Baby", movement = "follow"},
	{key = "farting_baby", list = "farting_baby", zh = "屁屁宝宝", en = "Farting Baby", movement = "follow"},
	{key = "boiled_baby", list = "boiled_baby", zh = "沸腾宝宝", en = "Boiled Baby", movement = "follow"},
	{key = "juicy_sack", list = "juicy_sack", zh = "多汁的袋子", en = "Juicy Sack", movement = "follow"},
	{key = "bobs_brain", list = "bobs_brain", zh = "鲍勃的脑浆", en = "Bob's Brain", movement = "projectile"},
	{key = "dry_baby", list = "dry_baby", zh = "干瘪宝宝", en = "Dry Baby", movement = "follow"},
	{key = "obsessed_fan", list = "obsessed_fan", zh = "着迷的粉丝", en = "Obsessed Fan", movement = "trail"},
	{key = "lil_spewer", list = "lil_spewer", zh = "小吐根", en = "Lil Spewer", movement = "charge"},
	{key = "guppys_hairball", list = "guppys_hairball", zh = "毛球", en = "Guppy's Hairball", movement = "flail"},
	{key = "holy_water", list = "holy_water", zh = "圣水", en = "Holy Water", movement = "projectile"},
	{key = "hallowed_ground", list = "hallowed_ground", zh = "圣洁之地", en = "Hallowed Ground", movement = "follow"},
	{key = "my_shadow", list = "my_shadow", zh = "我的影子", en = "My Shadow", movement = "trail"},
	{key = "shade", list = "shade", zh = "阴影", en = "Shade", movement = "follow"},
	{key = "king_baby", list = "king_baby", zh = "国王宝宝", en = "King Baby", movement = "follow"},
	-- 第二组资源宝宝：只改跟随目标
	{key = "sack_of_pennies", list = "sack_of_pennies", zh = "硬币袋", en = "Sack of Pennies", movement = "follow"},
	{key = "little_chad", list = "little_chad", zh = "查德宝宝", en = "Little C.H.A.D.", movement = "follow"},
	{key = "relic", list = "relic", zh = "圣遗物", en = "The Relic", movement = "follow"},
	{key = "bomb_bag", list = "bomb_bag", zh = "炸弹袋", en = "Bomb Bag", movement = "follow"},
	{key = "mystery_sack", list = "mystery_sack", zh = "神秘袋", en = "Mystery Sack", movement = "follow"},
	{key = "lil_chest", list = "lil_chest", zh = "小宝箱", en = "Lil Chest", movement = "follow"},
	{key = "charged_baby", list = "charged_baby", zh = "充电宝宝", en = "Charged Baby", movement = "follow"},
	{key = "rune_bag", list = "rune_bag", zh = "符文袋", en = "Rune Bag", movement = "follow"},
	{key = "acid_baby", list = "acid_baby", zh = "毒瘾宝宝", en = "Acid Baby", movement = "follow"},
	{key = "sack_of_sacks", list = "sack_of_sacks", zh = "袋中袋", en = "Sack of Sacks", movement = "follow"},
	{key = "mystery_egg", list = "mystery_egg", zh = "神秘的卵", en = "Mystery Egg", movement = "follow"},
}

-- Flight 环绕物（Craft_Orbital_holder）；独立「环绕物」审计行，不挤占「特效」
-- id 与 EXTRA_IMPL 共用键；受伤触发类（黑豆等）仍走特效，不进本表
M.CRAFT_ORBITAL_EXTRAS = {
	{key = "cube_of_meat", id = 73, zh = "肉块", en = "Cube of Meat"},
	{key = "ball_of_bandages", id = 207, zh = "绷带球", en = "Ball of Bandages"},
	{key = "halo_of_flies", id = 10, zh = "苍蝇光环", en = "Halo of Flies"},
	{key = "distant_admiration", id = 57, zh = "仰慕之交", en = "Distant Admiration"},
	{key = "guardian_angel", id = 112, zh = "守护天使", en = "Guardian Angel"},
	{key = "forever_alone", id = 128, zh = "永远孤独", en = "Forever Alone"},
	{key = "sacrificial_dagger", id = 172, zh = "献祭匕首", en = "Sacrificial Dagger"},
	{key = "big_fan", id = 279, zh = "大粉丝", en = "Big Fan"},
	{key = "friend_zone", id = 364, zh = "朋友区", en = "Friend Zone"},
	{key = "moms_razor", id = 508, zh = "妈妈的剃刀", en = "Mom's Razor"},
	{key = "slipped_rib", id = 542, zh = "滑肋骨", en = "Slipped Rib"},
	{key = "sworn_protector", id = 363, zh = "宣誓守护者", en = "Sworn Protector"},
	{key = "smart_fly", id = 264, zh = "聪明苍蝇", en = "Smart Fly"},
	{key = "bloodshot_eye", id = 509, zh = "血丝眼", en = "Bloodshot Eye"},
	{key = "angelic_prism", id = 528, zh = "天使棱镜", en = "Angelic Prism"},
	{key = "pointy_rib", id = 544, zh = "尖肋骨", en = "Pointy Rib"},
	{key = "finger", id = 467, zh = "手指！", en = "Finger!"},
	{key = "guillotine", id = 206, zh = "断头台", en = "Guillotine"},
	{key = "psy_fly", id = 581, zh = "灵能苍蝇", en = "Psy Fly"},
	{key = "bot_fly", id = 629, zh = "机器苍蝇", en = "Bot Fly"},
	{key = "tinytoma", id = 645, zh = "小托马", en = "Tinytoma"},
	-- 受伤后生成、但仍是环绕实体
	{key = "best_bud", id = 274, zh = "好朋友", en = "Best Bud"},
	{key = "leprosy", id = 525, zh = "麻风病", en = "Leprosy"},
	{key = "swarm", id = 693, zh = "苍蝇军团", en = "The Swarm"},
	{key = "vengeful_spirit", id = 702, zh = "复仇之火", en = "Vengeful Spirit"},
}

local _impl_cache = nil
local _stat_cache_memo = {}

-- 临时禁用的蓝图材料。保留其实现代码，待兼容修好后只需移除此表项。
M.INGREDIENT_BAN = {
	-- Gemini：已重新开放蓝图通道，配合 gemini_motion_probe 采集后重做。
}

function M.is_ingredient_banned(id)
	id = tonumber(id)
	return id ~= nil and M.INGREDIENT_BAN[id] == true
end

local function rebuild_impl_cache()
	local t = {}
	for _, m in ipairs(M.MORPH) do t[m.id] = true end
	for id in pairs(M.TEAR_FLAG_MASK) do t[id] = true end
	for id in pairs(M.STAT_DELTA) do t[id] = true end
	for id in pairs(M.FETUS_SEC_FLAGS) do t[id] = true end
	for id in pairs(M.BOMB_EFFECTS) do t[id] = true end
	for id in pairs(M.EXTRA_IMPL) do t[id] = true end
	_impl_cache = t
end

function M.has_stat_cache(id)
	id = tonumber(id)
	if not id or id <= 0 then return false end
	local col = Isaac.GetItemConfig():GetCollectible(id)
	return col ~= nil and ((col.CacheFlags or 0) & M.STAT_CACHE_MASK) ~= 0
end

function M.is_vanilla_collectible(id)
	id = tonumber(id)
	if not id or id <= 0 then return false end
	local limit = CollectibleType.NUM_COLLECTIBLES or 733
	return id < limit
end

function M.is_active_collectible(id)
	id = tonumber(id)
	if not id or id <= 0 then return false end
	local col = Isaac.GetItemConfig():GetCollectible(id)
	return col ~= nil and col.Type == ItemType.ITEM_ACTIVE
end

--- 主动道具 Cache 候选（不进缺数值列表，仅调试/计数）
function M.active_cache_pending(id)
	id = tonumber(id)
	return id ~= nil and id > 0 and M.is_active_collectible(id) and M.has_stat_cache(id)
		and M.STAT_DELTA[id] == nil and not M.STAT_AUDIT_EXCLUDE[id]
end

--- 是否为已登记的攻击模式 morph（主武器切换类）
function M.is_morph_item(id)
	id = tonumber(id)
	if not id or id <= 0 then return false end
	for _, m in ipairs(M.MORPH) do
		if m.id == id then return true end
	end
	return false
end

--- 审计专用：Cache 暗示战斗属性，但没有任何明确数值幅度。
--- 已有 morph / 泪 flag / 炸弹效果 / 剖腹产副武器 / EXTRA_IMPL 接线的不标缺数值。
function M.missing_stat_delta(id)
	id = tonumber(id)
	if not id or id <= 0 then return false end
	if M.STAT_AUDIT_EXCLUDE[id] then return false end
	if M.is_active_collectible(id) then return false end
	if M.EXTRA_IMPL[id] then return false end -- 动态/行为已登记
	if M.is_morph_item(id) then return false end
	if M.TEAR_FLAG_MASK[id] then return false end
	if M.BOMB_EFFECTS[id] then return false end
	if M.FETUS_SEC_FLAGS[id] then return false end
	return M.has_stat_cache(id) and M.STAT_DELTA[id] == nil
end

function M.body_scale_from_counts(counts)
	local mul = 1
	for id, n in pairs(counts or {}) do
		if n and n > 0 then
			local b = M.BODY_SCALE_MUL[id]
			if b then
				for _ = 1, n do
					mul = mul * b
				end
			end
		end
	end
	return math.max(0.25, math.min(3, mul))
end

--- 属性类：原版必须有手写 STAT_DELTA；模组道具才允许 CacheFlags 兜底。
function M.is_stat_item(id)
	id = tonumber(id)
	if not id or id <= 0 then return false end
	if M.STAT_DELTA[id] then return true end
	local memo = _stat_cache_memo[id]
	if memo ~= nil then return memo end
	local ok = false
	local col = Isaac.GetItemConfig():GetCollectible(id)
	if col then
		if not M.is_vanilla_collectible(id) and M.has_stat_cache(id) then
			ok = true
		elseif ItemConfig.TAG_TEARS_UP and col.Tags and (col.Tags & ItemConfig.TAG_TEARS_UP) ~= 0 then
			ok = true
		end
	end
	_stat_cache_memo[id] = ok
	return ok
end

function M.has_impl(id)
	id = tonumber(id)
	if not id or id <= 0 then return false end
	if not _impl_cache then rebuild_impl_cache() end
	if _impl_cache[id] then return true end
	-- 原版属性幅度必须有显式表；CacheFlags 仅供 missing_stat_delta 审计。
	return M.is_stat_item(id)
end

function M.impl_tags(id)
	id = tonumber(id) or id
	local tags = {}
	for _, m in ipairs(M.MORPH) do
		if m.id == id then tags[#tags + 1] = "morph" break end
	end
	if M.is_stat_item(id) then tags[#tags + 1] = "stat" end
	if M.missing_stat_delta(id) then tags[#tags + 1] = "stat_cache_missing" end
	if M.TEAR_FLAG_MASK[id] then tags[#tags + 1] = "flag" end
	if M.EXTRA_IMPL[id] then tags[#tags + 1] = M.EXTRA_IMPL[id] end
	if M.FETUS_SEC_FLAGS[id] then tags[#tags + 1] = "fetus_sec" end
	if M.BOMB_EFFECTS[id] then tags[#tags + 1] = "bomb" end
	return tags
end

-- 蓝图审计背包：状态标签 + 类别标签（非每个 EXTRA 键）
-- group=status / category：两组各自 OR，组间 AND（见 collectible_matches_audit_tags）
M.AUDIT_FILTER_TAG_DEFS = {
	{key = "valid", zh = "有效", en = "Valid", group = "status"},
	{key = "invalid", zh = "无效", en = "Invalid", group = "status"},
	{key = "unimplemented", zh = "未实装", en = "Unimpl", group = "status"},
	{key = "weapon", zh = "攻击方式", en = "Attack", group = "category"},
	{key = "stat", zh = "属性", en = "Stats", group = "category"},
	{key = "tear", zh = "泪特效", en = "Tear FX", group = "category"},
	{key = "bomb", zh = "炸弹效果", en = "Bomb FX", group = "category"},
	{key = "familiar", zh = "宝宝", en = "Familiar", group = "category"},
	{key = "orbital", zh = "环绕物", en = "Orbital", group = "category"},
	{key = "extra", zh = "特效", en = "Extra", group = "category"},
	{key = "form", zh = "套装", en = "Form", group = "category"},
}

function M.audit_filter_tag_defs()
	return M.AUDIT_FILTER_TAG_DEFS
end

function M.default_audit_tag_enabled()
	local t = {}
	for _, def in ipairs(M.AUDIT_FILTER_TAG_DEFS) do
		t[def.key] = true
	end
	return t
end

--- 归一化 prefs/存档中的 tag_enabled；缺键默认 true
--- 第二参保留兼容旧调用，不再把 audit_filter=impl 迁成关闭「无效」（会永久滤掉无效项）
function M.normalize_audit_tag_enabled(src, _audit_filter_legacy)
	local out = M.default_audit_tag_enabled()
	if type(src) == "table" then
		for _, def in ipairs(M.AUDIT_FILTER_TAG_DEFS) do
			local v = src[def.key]
			if v ~= nil then out[def.key] = v == true end
		end
	end
	return out
end

--- 审计「有效」：与旧 hide_gray/仅有效 一致（接线或套装可点亮）
function M.audit_item_is_valid(id, player)
	id = tonumber(id)
	if not id or id <= 0 then return false end
	if M.has_impl(id) then return true end
	if M.form_synergy_for_collectible(id, player) then return true end
	return false
end

function M.collectible_audit_tag_set(id, player)
	id = tonumber(id)
	local set = {}
	if not id or id <= 0 then return set end
	local is_valid = M.audit_item_is_valid(id, player)
	if is_valid then
		set.valid = true
	else
		set.invalid = true
	end
	if M.missing_stat_delta(id) then
		set.unimplemented = true
	end
	local is_morph = false
	for _, m in ipairs(M.MORPH) do
		if m.id == id then is_morph = true break end
	end
	if is_morph or M.FETUS_SEC_FLAGS[id] then set.weapon = true end
	if M.is_stat_item(id) or M.STAT_DELTA[id] or M.ONE_EYE[id] then set.stat = true end
	if M.TEAR_FLAG_MASK[id] or M.FLAG_NAME[id] then set.tear = true end
	if M.BOMB_EFFECTS[id] then set.bomb = true end
	local ek = M.EXTRA_IMPL[id]
	if ek then
		if M.CRAFT_FAMILIAR_EXTRAS_KEY_SET[ek] then
			set.familiar = true
			if M.CRAFT_FAMILIAR_ALSO_FX[ek] then set.extra = true end
		elseif M.CRAFT_ORBITAL_EXTRAS_KEY_SET[ek] then
			set.orbital = true
		else
			set.extra = true
		end
	end
	if M.form_synergy_for_collectible(id, player) then set.form = true end
	return set
end

--- 状态组与类别组各自 OR，组间 AND；两组都全关则空目录。
--- 无任何类别标签的道具（典型「无效」未接线项）：仅在「类别全开」或「类别全关」时通过类别侧，
--- 避免类别默认全开时把它们全部滤掉。
function M.collectible_matches_audit_tags(id, enabled_map, player)
	enabled_map = enabled_map or {}
	local status_on, cat_on = false, false
	local cat_total, cat_enabled_n = 0, 0
	for _, def in ipairs(M.AUDIT_FILTER_TAG_DEFS) do
		if def.group == "status" then
			if enabled_map[def.key] == true then status_on = true end
		else
			cat_total = cat_total + 1
			if enabled_map[def.key] == true then
				cat_on = true
				cat_enabled_n = cat_enabled_n + 1
			end
		end
	end
	if not status_on and not cat_on then return false end
	local set = M.collectible_audit_tag_set(id, player)
	local status_ok = not status_on
	local cat_hit = false
	local has_category = false
	for _, def in ipairs(M.AUDIT_FILTER_TAG_DEFS) do
		if def.group ~= "status" and set[def.key] then
			has_category = true
		end
		if enabled_map[def.key] == true and set[def.key] then
			if def.group == "status" then
				status_ok = true
			else
				cat_hit = true
			end
		end
	end
	local all_cats_on = cat_total > 0 and cat_enabled_n >= cat_total
	local cat_ok = (not cat_on) or cat_hit or ((not has_category) and all_cats_on)
	return status_ok and cat_ok
end

--- 材料槽条目：number 或 {id/collectible=, source=, prototype_uid=}
--- source: "real" | "audit" | "prototype"
function M.ingredient_id(entry)
	if type(entry) == "table" then
		return tonumber(entry.id or entry.collectible)
	end
	return tonumber(entry)
end

function M.is_prototype_entry(entry)
	return type(entry) == "table" and entry.source == "prototype"
		and entry.prototype_uid ~= nil
end

--- 单条材料来源。旧档：纯 number + rec.audit=true → 视为 audit。
function M.ingredient_source(entry, audit_fallback)
	if type(entry) == "table" then
		local src = entry.source
		if src == "prototype" or src == "audit" or src == "real" then
			return src
		end
		if entry.prototype_uid ~= nil then
			return "prototype"
		end
	end
	if audit_fallback then
		return "audit"
	end
	return "real"
end

function M.is_audit_entry(entry, audit_fallback)
	return M.ingredient_source(entry, audit_fallback) == "audit"
end

function M.is_real_entry(entry, audit_fallback)
	return M.ingredient_source(entry, audit_fallback) == "real"
end

function M.normalize_base_quality(q)
	q = tonumber(q)
	if q == nil then return nil end
	if q < 0 then return 0 end
	if q > 4 then return 4 end
	return math.floor(q)
end

function M.collectible_quality(id)
	id = tonumber(id)
	if not id or id <= 0 then return nil end
	local ok, cfg = pcall(function()
		return Isaac.GetItemConfig():GetCollectible(id)
	end)
	if not ok or not cfg then return 0 end
	return M.normalize_base_quality(cfg.Quality) or 0
end

function M.quality_from_cost_items(cost_items)
	for _, entry in ipairs(cost_items or {}) do
		local id = M.ingredient_id(entry)
		local q = M.collectible_quality(id)
		if q ~= nil then return q end
	end
	return nil
end

function M.resolve_base_quality(ctx)
	if type(ctx) ~= "table" then return nil end
	if ctx.base_quality ~= nil then
		return M.normalize_base_quality(ctx.base_quality)
	end
	local rec = ctx.rec
	if type(rec) ~= "table" then return nil end
	if rec.base_quality ~= nil then
		return M.normalize_base_quality(rec.base_quality)
	end
	if rec.remembered_quality ~= nil then
		return M.normalize_base_quality(rec.remembered_quality)
	end
	return M.quality_from_cost_items(rec.cost_items)
end

function M.slots_for_base_quality(q)
	q = M.normalize_base_quality(q)
	if q == nil then return 0 end
	return M.BASE_QUALITY_SLOTS[q] or 3
end

function M.stat_mul_for_base_quality(q)
	q = M.normalize_base_quality(q)
	if q == nil then return 1 end
	return M.BASE_QUALITY_STAT_MUL[q] or 1
end

function M.apply_base_quality_to_stats(stats, quality)
	if type(stats) ~= "table" then return stats end
	local q = M.normalize_base_quality(quality)
	local mul = M.stat_mul_for_base_quality(q)
	stats.base_quality = q
	stats.base_quality_mul = mul
	if math.abs(mul - 1) <= 0.001 then return stats end
	stats.damage = (tonumber(stats.damage) or 0) * mul
	stats.range = (tonumber(stats.range) or 0) * mul
	stats.shotspeed = (tonumber(stats.shotspeed) or 0) * mul
	stats.speed = (tonumber(stats.speed) or 0) * mul
	stats.luck = (tonumber(stats.luck) or 0) * mul
	stats.firedelay = math.max(1, (tonumber(stats.firedelay) or 10) / mul)
	return stats
end

--- 遍历材料+成本条目
function M.for_each_craft_entry(ingredients, cost_items, fn)
	if not fn then return end
	for slot, entry in pairs(ingredients or {}) do
		fn(entry, "ingredient", slot)
	end
	for i, entry in ipairs(cost_items or {}) do
		fn(entry, "cost", i)
	end
end

--- 整机「属审计」：存在至少一条 audit 材料/成本（并非「全部都不来自审计」）
function M.craft_has_any_audit(ingredients, cost_items, audit_fallback)
	local found = false
	M.for_each_craft_entry(ingredients, cost_items, function(entry)
		if found then return end
		if M.ingredient_source(entry, audit_fallback) == "audit" then
			found = true
		end
	end)
	if found then return true end
	-- 无条目时：仅当旧档 fallback 且无任何材料时不标审计
	return false
end

function M.craft_has_any_audit_rec(rec)
	if not rec then return false end
	return M.craft_has_any_audit(rec.ingredients, rec.cost_items, rec.audit == true)
end

--- 纯审计：有至少一条条目，且全部为 audit（无 real/prototype）
--- 用于豁免成本阶梯/确认时的真实成本与配额校验
function M.craft_is_pure_audit(ingredients, cost_items, audit_fallback)
	local any = false
	local all_audit = true
	M.for_each_craft_entry(ingredients, cost_items, function(entry)
		any = true
		if M.ingredient_source(entry, audit_fallback) ~= "audit" then
			all_audit = false
		end
	end)
	return any and all_audit
end

function M.craft_is_pure_audit_rec(rec)
	if not rec then return false end
	return M.craft_is_pure_audit(rec.ingredients, rec.cost_items, rec.audit == true)
end

--- 原型 UID 是否已被 integrity 标为丢失
local function craft_prototype_uid_missing(rec, uid)
	if uid == nil or not rec or not rec.broken_missing then return false end
	local pu = rec.broken_missing.prototype_uids
	if type(pu) ~= "table" then return false end
	return pu[uid] == true or pu[tostring(uid)] == true
end

--- 配方中该 collectible 是否以仍有效的 audit/prototype 虚拟持有（可 MeusNil / 不依赖玩家 innate）
--- 丢失的 prototype UID 不算虚拟源。
function M.craft_has_virtual_source_for(rec, collectible_id, opts)
	collectible_id = tonumber(collectible_id)
	if not rec or not collectible_id then return false end
	opts = opts or {}
	for _, entry in pairs(rec.ingredients or {}) do
		if M.ingredient_id(entry) == collectible_id then
			local src = M.ingredient_source(entry, rec.audit == true)
			if src == "audit" then
				return true
			elseif src == "prototype" then
				local uid = entry.prototype_uid
				if opts.prototype_alive then
					if opts.prototype_alive(uid) then return true end
				elseif not craft_prototype_uid_missing(rec, uid) then
					return true
				end
			end
		end
	end
	return false
end

--- 捕捉类制造宝宝材料是否仍可用（audit 恒可用；prototype 需 UID 仍在；real 需本配方未记缺且玩家仍持有）。
--- always_spawn_synthetic 不走此判定（不依赖原版实体，缺料时暂维持 extras）。
--- opts.prototype_alive = function(uid) -> boolean
function M.craft_familiar_material_available(player, rec, collectible_id, opts)
	collectible_id = tonumber(collectible_id)
	if not rec or not collectible_id then return false end
	opts = opts or {}
	local fb = rec.audit == true
	local miss_n = rec.broken_missing and tonumber(rec.broken_missing[collectible_id]) or 0
	for _, entry in pairs(rec.ingredients or {}) do
		if M.ingredient_id(entry) == collectible_id then
			local src = M.ingredient_source(entry, fb)
			if src == "audit" then
				return true
			elseif src == "prototype" then
				local uid = entry.prototype_uid
				if opts.prototype_alive then
					if opts.prototype_alive(uid) then return true end
				elseif not craft_prototype_uid_missing(rec, uid) then
					return true
				end
			elseif src == "real" then
				if miss_n <= 0
					and player
					and player.HasCollectible
					and player:HasCollectible(collectible_id, true)
				then
					return true
				end
			end
		end
	end
	return false
end

--- 蓝图「道具原型」抽池资格（唯一入口）
function M.is_prototype_eligible(id)
	id = tonumber(id)
	if not id or id <= 0 then return false end
	-- 池耗尽哨兵；禁止当作可用原型
	if id == (CollectibleType.COLLECTIBLE_BREAKFAST or 25) then return false end
	if M.is_ingredient_banned(id) then return false end
	if M.STAT_AUDIT_EXCLUDE[id] then return false end
	-- 缺数值幅度（审计黄标）≠ 可用原型
	if M.missing_stat_delta(id) then return false end
	local col = Isaac.GetItemConfig():GetCollectible(id)
	if not col or col.Hidden then return false end
	-- 首版：仅被动与宝宝
	if col.Type ~= ItemType.ITEM_PASSIVE and col.Type ~= ItemType.ITEM_FAMILIAR then
		return false
	end
	if ItemConfig.TAG_QUEST and col.Tags and (col.Tags & ItemConfig.TAG_QUEST) ~= 0 then
		return false
	end
	if not M.has_impl(id) then return false end
	local pool = Game():GetItemPool()
	if pool and pool.CanSpawnCollectible then
		local ok = pool:CanSpawnCollectible(id, false)
		if ok == false then return false end
	end
	return true
end

function M.counts_from_ingredients(ingredients)
	local counts = {}
	if not ingredients then return counts end
	for _, entry in pairs(ingredients) do
		local id = M.ingredient_id(entry)
		if id and id ~= 0 and not M.is_ingredient_banned(id) then
			counts[id] = (counts[id] or 0) + 1
		end
	end
	return counts
end

--- 按来源拆分材料份数：{ [id] = {real=, audit=, prototype=} }
function M.source_counts_from_ingredients(ingredients, audit_fallback)
	local out = {}
	if not ingredients then return out end
	for _, entry in pairs(ingredients) do
		local id = M.ingredient_id(entry)
		if id and id ~= 0 and not M.is_ingredient_banned(id) then
			local src = M.ingredient_source(entry, audit_fallback)
			local bucket = out[id]
			if not bucket then
				bucket = {real = 0, audit = 0, prototype = 0}
				out[id] = bucket
			end
			if src == "prototype" then
				bucket.prototype = bucket.prototype + 1
			elseif src == "audit" then
				bucket.audit = bucket.audit + 1
			else
				bucket.real = bucket.real + 1
			end
		end
	end
	return out
end

function M.source_bucket_for(profile_or_rec, id)
	id = tonumber(id)
	if not id or id <= 0 or not profile_or_rec then
		return {real = 0, audit = 0, prototype = 0}
	end
	local sc = profile_or_rec.source_counts and profile_or_rec.source_counts[id]
	if sc then
		return {
			real = tonumber(sc.real) or 0,
			audit = tonumber(sc.audit) or 0,
			prototype = tonumber(sc.prototype) or 0,
		}
	end
	local total = 0
	if profile_or_rec.counts then
		total = tonumber(profile_or_rec.counts[id]) or 0
	elseif profile_or_rec.ingredients then
		total = (M.counts_from_ingredients(profile_or_rec.ingredients) or {})[id] or 0
	end
	-- 旧档无 source_counts：整份记为 audit（避免误认领玩家原版实体）
	return {real = 0, audit = total, prototype = 0}
end

function M.bomb_effects_from_counts(counts, init_seed)
	local flags = BitSet128(0, 0)
	local variant = nil
	local nancy = false
	local available = {}
	local ids = {}
	for id in pairs(M.BOMB_EFFECTS) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local effect = M.BOMB_EFFECTS[id]
		if not effect.nancy then available[#available + 1] = effect end
		if (counts and counts[id] or 0) > 0 then
			if effect.flag then flags = flags | effect.flag end
			if effect.variant ~= nil then variant = effect.variant end
			if effect.nancy then nancy = true end
		end
	end
	if nancy and #available > 0 then
		table.sort(available, function(a, b) return (a.variant or -1) < (b.variant or -1) end)
		local chosen = available[((tonumber(init_seed) or 0) % #available) + 1]
		if chosen.flag then flags = flags | chosen.flag end
		if chosen.variant ~= nil then variant = chosen.variant end
	end
	return flags, variant
end

function M.apply_bomb_item_effects(bomb, profile)
	if not bomb or not profile then return end
	local flags, variant = M.bomb_effects_from_counts(profile.counts, bomb.InitSeed)
	if bomb.AddTearFlags then bomb:AddTearFlags(flags)
	elseif bomb.Flags ~= nil then bomb.Flags = bomb.Flags | flags end
	if variant ~= nil then bomb.Variant = variant end
	local d = bomb:GetData()
	d.QingCraftBombFlags = flags
	d.QingCraftBombVariant = variant
end

--- 条件亮起：效果依赖特定主武器/副 morph 时，未满足则蓝图 UI 变暗（仍可放入）
--- 炸弹类：需博士/史诗为主武器，或配方含 52/168，或含 No. 2（378）/鲍勃脑浆（273）
--- 剖腹产副武器 flag：仅非主 morph 的 FETUS_SEC 条目才门控（主攻击方式如博士/硫磺等始终可亮）
--- 虫群之心（248）：需配方含妈妈的假发（217）
--- 注意：378/273 本身不进 BOMB_EFFECTS / 门控，走 EXTRA_IMPL；但会点亮其它炸弹材料
function M.effect_gate_kind(id)
	id = tonumber(id)
	if not id or id <= 0 then return nil end
	if id == 248 then return "moms_wig" end
	if M.BOMB_EFFECTS[id] then return "bomb" end
	-- 52/118/114… 同属 MORPH 与 FETUS_SEC：作主攻击方式时不得因无剖腹产而变暗
	if M.FETUS_SEC_FLAGS[id] and not M.is_morph_item(id) then return "fetus_sec" end
	return nil
end

--- 玩家已变身时，带对应 TAG 的材料可点亮（即使无独立接线，如圣经→书套）
--- 返回 synergy key：bookworm / conjoined / guppy / spun
function M.form_synergy_for_collectible(id, player)
	id = tonumber(id)
	if not id or id <= 0 or not player then return nil end
	local TAG_BOOK = ItemConfig.TAG_BOOK or (1 << 13)
	local TAG_BABY = ItemConfig.TAG_BABY or (1 << 9)
	local TAG_GUPPY = ItemConfig.TAG_GUPPY or (1 << 5)
	local TAG_SYRINGE = ItemConfig.TAG_SYRINGE or (1 << 1)
	if M.collectible_has_tag(id, TAG_BOOK)
		and M.player_has_form(player, PlayerForm.PLAYERFORM_BOOK_WORM)
	then
		return "bookworm"
	end
	if M.collectible_has_tag(id, TAG_BABY)
		and M.player_has_form(player, PlayerForm.PLAYERFORM_BABY)
	then
		return "conjoined"
	end
	if M.collectible_has_tag(id, TAG_GUPPY)
		and M.player_has_form(player, PlayerForm.PLAYERFORM_GUPPY)
	then
		return "guppy"
	end
	if M.collectible_has_tag(id, TAG_SYRINGE)
		and M.player_has_form(player, PlayerForm.PLAYERFORM_DRUGS)
	then
		return "spun"
	end
	return nil
end

function M.is_effectively_lit(id, ctx)
	id = tonumber(id)
	if not id or id <= 0 then return false end
	ctx = ctx or {}
	-- 套装材料：玩家已变身 + 对应 TAG → 亮起（圣经等主动书无独立接线也适用）
	if M.form_synergy_for_collectible(id, ctx.player) then
		return true
	end
	if not M.has_impl(id) then return false end
	-- 主 morph（博士/硫磺/妈刀等）始终亮起
	if M.is_morph_item(id) then return true end
	local kind = M.effect_gate_kind(id)
	if not kind then return true end
	local weapon = tonumber(ctx.weapon) or 1
	local list = ctx.list or {}
	local counts = ctx.counts or {}
	if kind == "bomb" then
		return weapon == 5 or weapon == 6
			or (list.dr or 0) > 0
			or (list.epic or 0) > 0
			or (counts[378] or 0) > 0 -- No. 2 掉落炸弹，配方炸弹效果可亮起
			or (counts[273] or 0) > 0 -- 脑浆爆炸吃 BOMB_EFFECTS
			or (list.bobs_brain or 0) > 0
	end
	if kind == "fetus_sec" then
		return weapon == 14 or (list.sec or 0) > 0
	end
	if kind == "moms_wig" then
		return (counts[217] or 0) > 0
	end
	return true
end

--- 从蓝图草稿槽位统计 counts，并解析预览武器上下文
--- opts/player：传入玩家以便套装材料亮起
function M.preview_weapon_context_from_craft(craft, player)
	local counts = {}
	if craft then
		for _, slot in ipairs(craft.slots or {}) do
			local tok = slot.token and craft.token_map and craft.token_map[slot.token]
			local id = tok and tonumber(tok.collectible)
			if id and id > 0 then
				counts[id] = (counts[id] or 0) + 1
			end
		end
	end
	local list = M.list_from_counts(counts)
	local weapon = select(1, M.resolve_weapon(list, counts))
	return {
		weapon = weapon or 1,
		list = list,
		counts = counts,
		player = player,
	}
end

function M.list_from_counts(counts)
	counts = counts or {}
	local function n(id) return counts[id] or 0 end
	return {
		brimstone = n(118),
		tech = n(68),
		techX = n(395),
		knife = n(114),
		lung = n(229),
		dr = n(52),
		epic = n(168),
		sword = n(579),
		ludo = n(329),
		pol = n(169),
		cho = n(69),
		soy = n(330),
		soy2 = n(561),
		sec = n(678),
		ipec = n(149),
		godhead = n(331),
		tri = n(533),
		hae = n(531),
		coal = n(132),
		pro = n(261),
		divi = n(453) + n(224) + n(104),
		redfire = n(616),
		bluefire = n(495),
		eye = n(558),
		tech2 = n(152),
		tech5 = n(244),
		cursed_eye = n(316),
		fruit_cake = n(418),
		bobby = n(8),
		maggy = n(67),
		gish = n(99),
		steven = n(100),
		ghost_baby = n(163),
		harlequin = n(167),
		rainbow = n(174),
		rotten = n(268),
		mongo = n(322),
		fates_reward = n(361),
		seraphim = n(390),
		succubus = n(417),
		lil_loki = n(435),
		freezer = n(608),
		robo = n(95),
		demon = n(113),
		robo2 = n(267),
		milk = n(436),
		one_up = n(11),
		dead_cat = n(81),
		inner_child = n(688),
		guppys_collar = n(212),
		lazarus_rags = n(332),
		ankh = n(161),
		judas_shadow = n(311),
		gemini = n(318),
		cains_other_eye = n(319),
		incubus = n(360),
		twisted_pair = n(698),
		lil_brimstone = n(275),
		lil_abaddon = n(679),
		lil_monstro = n(471),
		little_chubby = n(88),
		big_chubby = n(473),
		lil_gurdy = n(384),
		censer = n(387),
		papa_fly = n(430),
		multidimensional_baby = n(431),
		finger = n(467),
		depression = n(469),
		headless_baby = n(269),
		farting_baby = n(404),
		boiled_baby = n(607),
		juicy_sack = n(266),
		bobs_brain = n(273),
		dry_baby = n(265),
		obsessed_fan = n(426),
		lil_spewer = n(537),
		guppys_hairball = n(187),
		holy_water = n(178),
		hallowed_ground = n(543),
		my_shadow = n(433),
		shade = n(468),
		king_baby = n(472),
		sack_of_pennies = n(94),
		little_chad = n(96),
		relic = n(98),
		bomb_bag = n(131),
		mystery_sack = n(271),
		lil_chest = n(362),
		charged_baby = n(372),
		rune_bag = n(389),
		acid_baby = n(491),
		sack_of_sacks = n(500),
		mystery_egg = n(539),
		inner = n(2),
		mutant = n(153),
		twenty = n(245),
		wiz = n(358),
		sacred = n(182),
	}
end

--- Recipe-only multishot count (mirrors attack_list_calculator manual path).
function M.build_multishot(counts)
	counts = counts or {}
	local inner = counts[2] or 0
	local mutant = counts[153] or 0
	local twenty = counts[245] or 0
	local wiz = counts[358] or 0
	local cnt1 = 1
	if inner > 0 or mutant > 0 then
		cnt1 = cnt1 + 1
	end
	local perfect = twenty
	if inner > 0 or mutant > 0 then
		perfect = perfect - 1
	end
	cnt1 = cnt1 + mutant * 2 + inner + math.max(0, perfect) + wiz
	return {
		count = math.max(1, cnt1),
		inner = inner,
		mutant = mutant,
		twenty = twenty,
		wiz = wiz,
	}
end

function M.collectible_has_tag(id, tag)
	id = tonumber(id)
	if not id or id <= 0 or tag == nil then return false end
	-- 勿 tonumber(tag)：运行时 TAG_* 可能不是 plain number，tonumber 会变 nil 导致套装全失效
	local col = Isaac.GetItemConfig():GetCollectible(id)
	if not col then return false end
	-- HasTags / Tags 位运算；API 可能返回 1/0 而非 boolean，禁止 == true
	if col.HasTags then
		if col:HasTags(tag) then return true end
		return false
	end
	local tags = col.Tags
	if tags == nil then return false end
	return (tags & tag) == tag
end

function M.counts_have_item_tag(counts, tag)
	for id, n in pairs(counts or {}) do
		if n and n > 0 and M.collectible_has_tag(id, tag) then
			return true
		end
	end
	return false
end

--- 是否已变身；勿用 player.HasPlayerForm 字段探测；勿对返回值 == true（引擎常给 1/0）
function M.player_has_form(player, form)
	if not player or form == nil then return false end
	local ok, has = pcall(function()
		return player:HasPlayerForm(form)
	end)
	if ok and has then return true end
	-- RGON：计数满 3 也视为变身
	if player.GetPlayerFormCounter then
		local ok2, n = pcall(function()
			return player:GetPlayerFormCounter(form)
		end)
		if ok2 and type(n) == "number" and n >= 3 then return true end
	end
	return false
end

-- ---------- 套装诊断 jsonl ----------
-- 输出：codex_work/logs/craft_form_debug.jsonl
local function form_log_escape(s)
	s = tostring(s or "")
	s = string.gsub(s, "\\", "\\\\")
	s = string.gsub(s, "\"", "\\\"")
	s = string.gsub(s, "\n", "\\n")
	s = string.gsub(s, "\r", "\\r")
	return s
end

local function form_log_encode_value(v)
	local vt = type(v)
	if v == nil then return "null" end
	if vt == "boolean" then return v and "true" or "false" end
	if vt == "number" then
		if v ~= v or v == math.huge or v == -math.huge then return "null" end
		return string.format("%.6g", v)
	end
	if vt == "table" then
		-- 数组优先
		local n = #v
		if n > 0 then
			local parts = {}
			for i = 1, n do parts[i] = form_log_encode_value(v[i]) end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local parts = {}
		for k, val in pairs(v) do
			parts[#parts + 1] = "\"" .. form_log_escape(k) .. "\":" .. form_log_encode_value(val)
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	return "\"" .. form_log_escape(v) .. "\""
end

local function form_log_write(row)
	if not dev_env.probes_allowed() then return end
	if not M.enable_form_log then return end
	row = row or {}
	row.fr = Game():GetFrameCount()
	local line = form_log_encode_value(row)
	pcall(function()
		if not io or not io.open then return end
		-- 唯一规范文件；仅两种相对写法（禁止根目录/机器绝对路径兜底）
		local paths = {
			"mods/Qing_remaster/codex_work/logs/craft_form_debug.jsonl",
			"../mods/Qing_remaster/codex_work/logs/craft_form_debug.jsonl",
		}
		local mode = M._form_log_ready and "a" or "w"
		for _, path in ipairs(paths) do
			local f = io.open(path, mode)
			if f then
				f:write(line .. "\n")
				f:close()
				M._form_log_ready = true
				M._form_log_path = path
				return
			end
		end
	end)
end

local function form_probe_player(player, form)
	local out = {
		form = form,
		ok = false,
		raw = nil,
		raw_type = "nil",
		truthy = false,
		counter = nil,
	}
	if not player or form == nil then return out end
	local ok, raw = pcall(function() return player:HasPlayerForm(form) end)
	out.ok = ok
	if ok then
		out.raw = raw
		out.raw_type = type(raw)
		out.truthy = not not raw
		out.eq_true = (raw == true)
		out.eq_one = (raw == 1)
	else
		out.err = tostring(raw)
	end
	if player.GetPlayerFormCounter then
		local ok2, n = pcall(function() return player:GetPlayerFormCounter(form) end)
		if ok2 then out.counter = n end
	end
	return out
end

local function form_probe_collectible(id, tags)
	id = tonumber(id)
	local out = {id = id, name = "?"}
	if not id or id <= 0 then return out end
	local col = Isaac.GetItemConfig():GetCollectible(id)
	if not col then
		out.missing = true
		return out
	end
	out.name = col.Name or "?"
	out.type = col.Type
	out.tags_raw = col.Tags
	out.tags_type = type(col.Tags)
	out.has_HasTags = col.HasTags ~= nil
	out.hit = {}
	for key, tag in pairs(tags) do
		local row = {tag = key, tag_val = tag, tag_type = type(tag)}
		if col.HasTags then
			local ok, r = pcall(function() return col:HasTags(tag) end)
			row.hasTags_ok = ok
			if ok then
				row.hasTags_raw = r
				row.hasTags_type = type(r)
				row.hasTags_truthy = not not r
			else
				row.hasTags_err = tostring(r)
			end
		end
		if col.Tags ~= nil and tag ~= nil then
			local ok2, bit_ok = pcall(function()
				return (col.Tags & tag) == tag
			end)
			row.bit_ok = ok2 and bit_ok or false
			if not ok2 then row.bit_err = tostring(bit_ok) end
		end
		row.helper = M.collectible_has_tag(id, tag)
		out.hit[key] = row
	end
	return out
end

--- 套装解析诊断（节流：同签名约 30 帧写一次）
function M.log_form_resolve(src, player, counts, forms)
	if not M.enable_form_log then return end
	counts = counts or {}
	forms = forms or {}
	local TAGS = {
		book = ItemConfig.TAG_BOOK or (1 << 13),
		baby = ItemConfig.TAG_BABY or (1 << 9),
		guppy = ItemConfig.TAG_GUPPY or (1 << 5),
		syringe = ItemConfig.TAG_SYRINGE or (1 << 1),
	}
	local count_keys = {}
	for id, n in pairs(counts) do
		if n and n > 0 then
			count_keys[#count_keys + 1] = {id = tonumber(id) or id, n = n}
		end
	end
	table.sort(count_keys, function(a, b)
		local ai, bi = tonumber(a.id) or 0, tonumber(b.id) or 0
		return ai < bi
	end)
	local sig_parts = {tostring(src or "?")}
	for _, row in ipairs(count_keys) do
		sig_parts[#sig_parts + 1] = tostring(row.id) .. "x" .. tostring(row.n)
	end
	if player then
		sig_parts[#sig_parts + 1] = "p" .. tostring(GetPtrHash(player))
	end
	sig_parts[#sig_parts + 1] = "f"
		.. (forms.bookworm and "B" or "-")
		.. (forms.spun and "S" or "-")
		.. (forms.guppy and "G" or "-")
		.. (forms.conjoined and "C" or "-")
	local sig = table.concat(sig_parts, "|")
	local fr = Game():GetFrameCount()
	if M._form_log_sig == sig and fr < (M._form_log_next or 0) then
		return
	end
	M._form_log_sig = sig
	M._form_log_next = fr + 30

	local items = {}
	for _, row in ipairs(count_keys) do
		items[#items + 1] = form_probe_collectible(row.id, TAGS)
		items[#items].n = row.n
	end

	form_log_write({
		e = "resolve",
		src = src or "?",
		player = player and true or false,
		tag_book = TAGS.book,
		tag_book_type = type(TAGS.book),
		tag_syringe = TAGS.syringe,
		tag_syringe_type = type(TAGS.syringe),
		pf_bookworm = PlayerForm and PlayerForm.PLAYERFORM_BOOK_WORM,
		pf_drugs = PlayerForm and PlayerForm.PLAYERFORM_DRUGS,
		has_bookworm = form_probe_player(player, PlayerForm and PlayerForm.PLAYERFORM_BOOK_WORM),
		has_drugs = form_probe_player(player, PlayerForm and PlayerForm.PLAYERFORM_DRUGS),
		has_baby = form_probe_player(player, PlayerForm and PlayerForm.PLAYERFORM_BABY),
		has_guppy = form_probe_player(player, PlayerForm and PlayerForm.PLAYERFORM_GUPPY),
		counts_n = #count_keys,
		items = items,
		helper_has_book_tag = M.counts_have_item_tag(counts, TAGS.book),
		helper_has_syringe_tag = M.counts_have_item_tag(counts, TAGS.syringe),
		helper_player_book = M.player_has_form(player, PlayerForm and PlayerForm.PLAYERFORM_BOOK_WORM),
		helper_player_drugs = M.player_has_form(player, PlayerForm and PlayerForm.PLAYERFORM_DRUGS),
		forms = {
			bookworm = forms.bookworm and true or false,
			spun = forms.spun and true or false,
			guppy = forms.guppy and true or false,
			conjoined = forms.conjoined and true or false,
		},
		dmg = nil,
	})
end

--- 显示射速（≈ tears）加减：内部 MaxFireDelay ↔ 30/(delay+1)
function M.add_tears_stat(stats, delta)
	if not stats then return end
	delta = tonumber(delta) or 0
	if delta == 0 then return end
	local fr = 30 / (math.max(-0.75, tonumber(stats.firedelay) or 10) + 1)
	fr = math.max(0.1, fr + delta)
	stats.firedelay = math.max(1, 30 / fr - 1)
end

--- 玩家套装 × 配方材料 → 每飞行器至多生效一次（不叠层）
--- 均需：玩家已变身 + 配方含对应 TAG（BABY / GUPPY / BOOK / SYRINGE）
function M.resolve_player_forms(player, counts, src)
	local forms = {}
	if not player then
		M.log_form_resolve(src or "no_player", player, counts, forms)
		return forms
	end
	local TAG_BOOK = ItemConfig.TAG_BOOK or (1 << 13)
	local TAG_BABY = ItemConfig.TAG_BABY or (1 << 9)
	local TAG_GUPPY = ItemConfig.TAG_GUPPY or (1 << 5)
	local TAG_SYRINGE = ItemConfig.TAG_SYRINGE or (1 << 1)
	if M.player_has_form(player, PlayerForm.PLAYERFORM_BABY)
		and M.counts_have_item_tag(counts, TAG_BABY)
	then
		forms.conjoined = true
	end
	if M.player_has_form(player, PlayerForm.PLAYERFORM_GUPPY)
		and M.counts_have_item_tag(counts, TAG_GUPPY)
	then
		forms.guppy = true
	end
	if M.player_has_form(player, PlayerForm.PLAYERFORM_BOOK_WORM)
		and M.counts_have_item_tag(counts, TAG_BOOK)
	then
		forms.bookworm = true
	end
	if M.player_has_form(player, PlayerForm.PLAYERFORM_DRUGS)
		and M.counts_have_item_tag(counts, TAG_SYRINGE)
	then
		forms.spun = true
	end
	M.log_form_resolve(src or "resolve", player, counts, forms)
	return forms
end

function M.apply_player_form_stats(stats, forms)
	if not stats or not forms then return end
	if forms.conjoined then
		stats.damage = (tonumber(stats.damage) or 0) - 0.3
		M.add_tears_stat(stats, -0.3)
	end
	if forms.spun then
		stats.damage = (tonumber(stats.damage) or 0) + 2
		stats.speed = (tonumber(stats.speed) or 0) + 0.15
	end
end

--- 套装额外弹道相对瞄准角（度）。Bookworm 仅在 roll_bookworm 时掷 25%。
function M.form_extra_angles(profile, opts)
	opts = opts or {}
	local angs = {}
	local forms = profile and profile.forms
	if not forms then return angs end
	if forms.conjoined then
		angs[#angs + 1] = -45
		angs[#angs + 1] = 45
	end
	if forms.bookworm and opts.roll_bookworm then
		local hit = false
		if opts.rng and opts.rng.RandomFloat then
			hit = opts.rng:RandomFloat() < 0.25
		else
			hit = math.random(4) == 1
		end
		if hit then angs[#angs + 1] = 0 end
	end
	return angs
end

function M.form_extra_shot_dirs(base_dir, profile, opts)
	local dirs = {}
	for _, ang in ipairs(M.form_extra_angles(profile, opts)) do
		if ang == 0 then
			dirs[#dirs + 1] = base_dir
		else
			dirs[#dirs + 1] = auxi.get_by_rotate(base_dir, ang)
		end
	end
	return dirs
end

local function morph_set_key(present_weapons)
	local ids = {}
	for w in pairs(present_weapons) do ids[#ids + 1] = w end
	table.sort(ids)
	local parts = {}
	for i = 1, #ids do parts[i] = tostring(ids[i]) end
	return table.concat(parts, ",")
end

local function fallback_pri_weapon(present_weapons)
	local best_w, best_p = 1, -1
	for _, m in ipairs(M.MORPH) do
		if present_weapons[m.weapon] and m.pri > best_p then
			best_p = m.pri
			best_w = m.weapon
		end
	end
	return best_w
end

local function ludo_is_overridden(present)
	for w in pairs(present or {}) do
		if M.LUDO_OVERRIDDEN_BY[w] then return true end
	end
	return false
end

--- 动态主武器表决（§14）：覆盖数量优先，同分看 CARRIER_PRI，零覆盖回退旧 pri。
--- Ludovico 可消费 Brim/Tech/TechX/Knife 改形；仍被 Epic/剖腹产/英灵剑覆盖。
function M.resolve_weapon(list, counts)
	list = list or {}
	counts = counts or {}
	local morph_items = {}
	local present = {} -- weapon -> true（重复份数不参与表决）
	for _, m in ipairs(M.MORPH) do
		local c = counts[m.id] or 0
		if c > 0 then
			morph_items[#morph_items + 1] = m.id
			present[m.weapon] = true
		end
	end

	local weapon = 1
	local compat_consumed = {}
	local used_fallback_pri = false

	local override = M.EXACT_MORPH_SET_OVERRIDE[morph_set_key(present)]
	if override then
		weapon = override
	elseif present[M.LUDO_WEAPON] and not ludo_is_overridden(present) then
		-- Ludo 单独或与可改形副 morph：主武器固定 8（Tech X 视为 Tech 环）
		weapon = M.LUDO_WEAPON
	else
		local best_score, best_carrier, best_w = -1, -1, 1
		local any_positive = false
		for cand in pairs(present) do
			local score = 0
			local can = M.BRANCH_COMPAT[cand]
			if can then
				for other in pairs(present) do
					if other ~= cand and can[other] then
						score = score + 1
					end
				end
			end
			if score > 0 then any_positive = true end
			local carrier = M.CARRIER_PRI[cand] or 0
			if score > best_score or (score == best_score and carrier > best_carrier) then
				best_score = score
				best_carrier = carrier
				best_w = cand
			end
		end
		if any_positive then
			weapon = best_w
		else
			weapon = fallback_pri_weapon(present)
			used_fallback_pri = true
		end
	end

	local can = M.BRANCH_COMPAT[weapon] or {}
	for other in pairs(present) do
		if other ~= weapon and can[other] then
			compat_consumed[#compat_consumed + 1] = other
		end
	end
	table.sort(compat_consumed)

	local consumed_set = {[weapon] = true}
	for _, w in ipairs(compat_consumed) do consumed_set[w] = true end
	local unsupported_morphs = {}
	for other in pairs(present) do
		if not consumed_set[other] then
			unsupported_morphs[#unsupported_morphs + 1] = other
		end
	end
	table.sort(unsupported_morphs)

	-- 血泪小攻击：主武为 Brim/Tech/TechX/Dr/Knife 时覆盖为眼泪；多 guest 仍 1 发主气球，
	-- 落地 shared 均分各 mode 面额。肺/史诗/剖腹产/英灵剑/鲁多维科胜出时不覆盖。
	local haemo_override = false
	local haemo_guests = {}
	local haemo_share_guests = {}
	local haemo_burst_mode = "tears"
	if (list.hae or 0) > 0 and M.HAEMO_OVERRIDE_WEAPONS[weapon] then
		haemo_override = true
		local guests = {}
		for other in pairs(present) do
			if M.HAEMO_OVERRIDE_WEAPONS[other] then
				guests[#guests + 1] = other
			end
		end
		table.sort(guests)
		haemo_guests = guests
		local share = {}
		for _, g in ipairs(haemo_guests) do
			if M.HAEMO_SHAREABLE[g] and M.HAEMO_BURST_MODE[g] then
				share[#share + 1] = g
			end
		end
		table.sort(share)
		haemo_share_guests = share
		if #share == 0 then
			haemo_burst_mode = "tears"
		elseif #share == 1 then
			haemo_burst_mode = M.HAEMO_BURST_MODE[share[1]] or "tears"
		else
			haemo_burst_mode = "shared"
		end
		weapon = 1
		compat_consumed = {}
		consumed_set = {[1] = true}
		for _, g in ipairs(haemo_guests) do
			compat_consumed[#compat_consumed + 1] = g
			consumed_set[g] = true
		end
		table.sort(compat_consumed)
		unsupported_morphs = {}
		for other in pairs(present) do
			if not consumed_set[other] then
				unsupported_morphs[#unsupported_morphs + 1] = other
			end
		end
		table.sort(unsupported_morphs)
	end

	local extras = {
		lung = list.lung or 0,
		tech2 = (list.tech2 or 0) > 0,
		tech5 = (list.tech5 or 0) > 0,
		chocolate = (list.cho or 0) > 0,
		cursed_eye = (list.cursed_eye or 0) > 0,
		haemolacria = (list.hae or 0) > 0,
		haemo_override = haemo_override,
		haemo_guests = haemo_guests,
		haemo_share_guests = haemo_share_guests,
		haemo_burst_mode = haemo_burst_mode,
		-- 卢多/剖腹产保留主武时仍标记血泪侧车效果
		haemo_ludo_proc = (list.hae or 0) > 0 and weapon == 8,
		haemo_fetus_proc = (list.hae or 0) > 0 and weapon == 14,
		brother_bobby = (list.bobby or 0) > 0,
		sister_maggy = (list.maggy or 0) > 0,
		little_steven = (list.steven or 0) > 0,
		ghost_baby = (list.ghost_baby or 0) > 0,
		harlequin_baby = (list.harlequin or 0) > 0,
		lil_loki = (list.lil_loki or 0) > 0,
		little_gish = (list.gish or 0) > 0,
		freezer_baby = (list.freezer or 0) > 0,
		seraphim = (list.seraphim or 0) > 0,
		succubus = (list.succubus or 0) > 0,
		rainbow_baby = (list.rainbow or 0) > 0,
		rotten_baby = (list.rotten or 0) > 0,
		mongo_baby = (list.mongo or 0) > 0,
		fates_reward = (list.fates_reward or 0) > 0,
		robo_baby = (list.robo or 0) > 0,
		robo_baby_2 = (list.robo2 or 0) > 0,
		demon_baby = (list.demon or 0) > 0,
		gemini = (list.gemini or 0) > 0,
		cains_other_eye = (list.cains_other_eye or 0) > 0,
		incubus = (list.incubus or 0) > 0,
		twisted_pair = (list.twisted_pair or 0) > 0,
		lil_brimstone = (list.lil_brimstone or 0) > 0,
		lil_abaddon = (list.lil_abaddon or 0) > 0,
		lil_monstro = (list.lil_monstro or 0) > 0,
		little_chubby = (list.little_chubby or 0) > 0,
		big_chubby = (list.big_chubby or 0) > 0,
		lil_gurdy = (list.lil_gurdy or 0) > 0,
		fruit_cake = (list.fruit_cake or 0) > 0,
		candle_red = (list.redfire or 0) > 0,
		candle_blue = (list.bluefire or 0) > 0,
		milk = (list.milk or 0) > 0,
		one_up = (list.one_up or 0) > 0,
		dead_cat = (list.dead_cat or 0) > 0,
		inner_child = (list.inner_child or 0) > 0,
		guppys_collar = (list.guppys_collar or 0) > 0,
		lazarus_rags = (list.lazarus_rags or 0) > 0,
		ankh = (list.ankh or 0) > 0,
		judas_shadow = (list.judas_shadow or 0) > 0,
		censer = (list.censer or 0) > 0,
		papa_fly = (list.papa_fly or 0) > 0,
		multidimensional_baby = (list.multidimensional_baby or 0) > 0,
		finger = (list.finger or 0) > 0,
		depression = (list.depression or 0) > 0,
		headless_baby = (list.headless_baby or 0) > 0,
		farting_baby = (list.farting_baby or 0) > 0,
		boiled_baby = (list.boiled_baby or 0) > 0,
		juicy_sack = (list.juicy_sack or 0) > 0,
		bobs_brain = (list.bobs_brain or 0) > 0,
		dry_baby = (list.dry_baby or 0) > 0,
		obsessed_fan = (list.obsessed_fan or 0) > 0,
		lil_spewer = (list.lil_spewer or 0) > 0,
		guppys_hairball = (list.guppys_hairball or 0) > 0,
		holy_water = (list.holy_water or 0) > 0,
		hallowed_ground = (list.hallowed_ground or 0) > 0,
		my_shadow = (list.my_shadow or 0) > 0,
		shade = (list.shade or 0) > 0,
		king_baby = (list.king_baby or 0) > 0,
		sack_of_pennies = (list.sack_of_pennies or 0) > 0,
		little_chad = (list.little_chad or 0) > 0,
		relic = (list.relic or 0) > 0,
		bomb_bag = (list.bomb_bag or 0) > 0,
		mystery_sack = (list.mystery_sack or 0) > 0,
		lil_chest = (list.lil_chest or 0) > 0,
		charged_baby = (list.charged_baby or 0) > 0,
		rune_bag = (list.rune_bag or 0) > 0,
		acid_baby = (list.acid_baby or 0) > 0,
		sack_of_sacks = (list.sack_of_sacks or 0) > 0,
		mystery_egg = (list.mystery_egg or 0) > 0,
		used_fallback_pri = used_fallback_pri,
	}
	return weapon, morph_items, extras, compat_consumed, unsupported_morphs
end

function M.build_synergy(weapon, list, extras)
	list = list or {}
	extras = extras or {}
	local brim = list.brimstone or 0
	local tech = list.tech or 0
	local techX = list.techX or 0
	local knife = list.knife or 0
	local dr = list.dr or 0
	local sword = list.sword or 0
	local stack_key = M.WEAPON_STACK_KEY[weapon]
	local extra_shots = 0
	if stack_key then
		extra_shots = math.max(0, (list[stack_key] or 0) - 1)
	end
	-- 血泪覆盖：叠份 guest morph → 额外主血泪基数（再经均分加成）
	if extras.haemo_override then
		local stack_src = extras.haemo_share_guests
		if not stack_src or #stack_src == 0 then
			stack_src = extras.haemo_guests or {}
		end
		for _, g in ipairs(stack_src) do
			local sk = M.WEAPON_STACK_KEY[g]
			if sk then
				extra_shots = extra_shots + math.max(0, (list[sk] or 0) - 1)
			end
		end
	end
	-- Ludovico 改形优先级：刀 > 硫磺环（可叠 Tech 外观）> 科技环（含 Tech X）
	local ludo_knife = weapon == 8 and knife > 0
	local ludo_brim = weapon == 8 and brim > 0 and not ludo_knife
	local ludo_tech = weapon == 8 and (tech > 0 or techX > 0) and not ludo_knife and not ludo_brim
	local haemo_mode = extras.haemo_burst_mode or "tears"
	local share_guests = extras.haemo_share_guests or {}
	local haemo_has_brim = false
	for _, g in ipairs(share_guests) do
		if g == 2 then
			haemo_has_brim = true
			break
		end
	end
	-- 无均分 guest 时回退旧单 mode
	if not haemo_has_brim and haemo_mode == "brim" then haemo_has_brim = true end
	return {
		thick_brim = brim >= 2,
		brim_tech = (weapon == 2 and tech > 0) or (ludo_brim and (tech > 0 or techX > 0))
			or (extras.haemo_override and haemo_has_brim and tech > 0),
		brim_techx = (weapon == 2 and techX > 0) or (weapon == 9 and brim > 0),
		brim_sword = weapon == 2 and sword > 0,
		knife_brim = weapon == 4 and brim > 0,
		knife_techx = weapon == 4 and techX > 0,
		knife_tech = weapon == 4 and tech > 0,
		techx_tech = weapon == 9 and tech > 0,
		sword_tech = (weapon == 10 or weapon == 13) and (tech > 0 or techX > 0),
		dr_brim = weapon == 5 and brim > 0,
		dr_techx = weapon == 5 and techX > 0,
		dr_tech = weapon == 5 and tech > 0,
		dr_sword = weapon == 5 and sword > 0,
		ludo_knife = ludo_knife,
		ludo_brim = ludo_brim,
		ludo_tech = ludo_tech,
		haemo_burst_mode = haemo_mode,
		haemo_share_guests = share_guests,
		haemo_brim_tech = extras.haemo_override and haemo_has_brim and tech > 0,
		epic_burst = {
			knife = knife,
			brimstone = brim,
			tech = tech,
			techX = techX,
			dr = dr,
			sword = sword,
		},
		extra_shots = extra_shots,
		brim_copies = brim,
		tech_copies = tech,
		techx_copies = techX,
		knife_copies = knife,
	}
end

function M.mask_from_counts(counts)
	local mask = BitSet128(0, 0)
	for id, n in pairs(counts or {}) do
		if n and n > 0 then
			local e = M.TEAR_EFFECTS[id]
			local f = M.TEAR_FLAG_MASK[id] or (e and e.flag)
			if f then mask = mask | f end
		end
	end
	return mask
end

--- 由 base_seed + salt 派生独立 RNG（每道具/每弹各一流，避免 pairs 顺序污染）
function M.derived_rng(base_seed, salt)
	local seed = math.floor((tonumber(base_seed) or 1) + (tonumber(salt) or 0) * 16777619) & 0xffffffff
	-- 不把线性相邻 seed 直接交给 SetSeed 后只取首值；先做 32 位雪崩混合。
	-- 旧实现还强制奇数，会把相邻的 (2n, 2n+1) 折叠成同一 seed。
	seed = seed ~ (seed >> 16)
	seed = (seed * 0x7feb352d) & 0xffffffff
	seed = seed ~ (seed >> 15)
	seed = (seed * 0x846ca68b) & 0xffffffff
	seed = seed ~ (seed >> 16)
	seed = seed & 0x7fffffff
	if seed == 0 then seed = 1 end
	local rng = RNG()
	rng:SetSeed(seed, 35)
	return rng
end

--- counts 安全读取（兼容 number / string 键）
function M.count_of(counts, id)
	if not counts then return 0 end
	id = tonumber(id)
	if not id then return 0 end
	local n = counts[id]
	if n == nil then n = counts[tostring(id)] end
	return tonumber(n) or 0
end

function M.tear_flag_base_seed(opts)
	opts = opts or {}
	if opts.seed and tonumber(opts.seed) and tonumber(opts.seed) ~= 0 then
		return tonumber(opts.seed)
	end
	local room = Game() and Game():GetRoom()
	local seed = (room and room.GetDecorationSeed and room:GetDecorationSeed()) or 1
	seed = seed + (tonumber(opts.shot_serial) or 0) * 17
	seed = seed + (tonumber(opts.craft_uid) or 0) * 131
	seed = seed + (tonumber(opts.projectile_index) or 0) * 8191
	seed = seed + (tonumber(opts.init_seed) or 0) % 1000003
	return seed
end

--- Almond Milk（561）：每泪从打包池抽 1–2 个 TearFlag（不另采样；避开爆炸/分裂等重形态）
M.ALMOND_MILK_FLAG_POOL = {
	TearFlags.TEAR_HOMING,
	TearFlags.TEAR_SPECTRAL,
	TearFlags.TEAR_PIERCING,
	TearFlags.TEAR_SLOW,
	TearFlags.TEAR_POISON,
	TearFlags.TEAR_FREEZE,
	TearFlags.TEAR_CHARM,
	TearFlags.TEAR_CONFUSION,
	TearFlags.TEAR_FEAR,
	TearFlags.TEAR_BURN,
	TearFlags.TEAR_BOUNCE,
	TearFlags.TEAR_BOOMERANG,
	TearFlags.TEAR_WIGGLE,
	TearFlags.TEAR_SPIRAL,
	TearFlags.TEAR_SQUARE,
	TearFlags.TEAR_GROW,
	TearFlags.TEAR_SHRINK,
	TearFlags.TEAR_ATTRACTOR,
}

function M.roll_almond_milk_flags(rng)
	local pool = M.ALMOND_MILK_FLAG_POOL
	local n = #pool
	if n <= 0 then return BitSet128(0, 0) end
	local pick_n = 1
	if rng and rng.RandomInt then
		pick_n = 1 + rng:RandomInt(2) -- 1 或 2
	else
		pick_n = 1 + (math.random(2) - 1)
	end
	if pick_n > n then pick_n = n end
	local idx = {}
	for i = 1, n do idx[i] = i end
	local mask = BitSet128(0, 0)
	for _ = 1, pick_n do
		local j
		if rng and rng.RandomInt then
			j = rng:RandomInt(#idx) + 1
		else
			j = math.random(#idx)
		end
		local p = table.remove(idx, j)
		local flag = pool[p]
		if flag then mask = mask | flag end
	end
	return mask
end

--- 按配方独立投掷 TearFlags（不读玩家缓存 / GetTearHitParams）
--- opts: {seed=, shot_serial=, craft_uid=, projectile_index=, init_seed=}
--- 概率项按「排序后的道具 ID」各自派生 RNG，不再顺序消耗同一流。
function M.roll_tear_flags(luck, profile, opts)
	opts = opts or {}
	local counts = (profile and profile.counts) or opts.counts or {}
	local mask = BitSet128(0, 0)
	local base_seed = M.tear_flag_base_seed(opts)
	luck = tonumber(luck) or 0
	local ids = {}
	for id, n in pairs(counts) do
		id = tonumber(id)
		if id and n and n > 0 and M.TEAR_EFFECTS[id] then
			ids[#ids + 1] = id
		end
	end
	table.sort(ids)
	local proj = tonumber(opts.projectile_index) or 0
	for _, id in ipairs(ids) do
		local e = M.TEAR_EFFECTS[id]
		if e then
			if e.always_flag then mask = mask | e.always_flag end
			-- craft_sim_burst（血泪等）：不写引擎分裂 flag，落地由自模拟触发
			if e.flag and not e.craft_sim_burst then
				local ok = true
				if e.roll then
					local rng = M.derived_rng(base_seed, id * 65537 + proj * 13)
					ok = e.roll(luck, rng) == true
				end
				if ok then mask = mask | e.flag end
			end
		end
	end
	-- 杏仁奶：每泪独立抽 1–2 个打包 flag
	if (counts[561] or 0) > 0 then
		local rng = M.derived_rng(base_seed, 561 * 65537 + proj * 13)
		mask = mask | M.roll_almond_milk_flags(rng)
	end
	if profile and profile.runtime and profile.runtime.flag_extra then
		mask = mask | profile.runtime.flag_extra
	end
	-- Guppy!：TEAR_MULLIGAN（命中生成蓝蝇；引擎自带概率，约 2/3）
	if profile and profile.forms and profile.forms.guppy
		and TearFlags and TearFlags.TEAR_MULLIGAN
	then
		mask = mask | TearFlags.TEAR_MULLIGAN
	end
	if profile and profile.runtime and profile.runtime.occult_stats_only
		and TearFlags and TearFlags.TEAR_OCCULT then
		mask = mask & ~TearFlags.TEAR_OCCULT
	end
	-- 双保险：制造血泪绝不带 TEAR_BURSTSPLIT（stamp 会整表赋值 flags，旧逻辑曾写回该 flag）
	if (counts[531] or 0) > 0 and TearFlags and TearFlags.TEAR_BURSTSPLIT then
		mask = mask & ~TearFlags.TEAR_BURSTSPLIT
	end
	return mask
end

function M.stats_from_counts(counts)
	local s = {
		damage = M.BASE_STATS.damage,
		firedelay = M.BASE_STATS.firedelay,
		shotspeed = M.BASE_STATS.shotspeed,
		range = M.BASE_STATS.range,
		luck = M.BASE_STATS.luck,
		speed = M.BASE_STATS.speed,
		scale = 1,
	}
	local dmg_mul, delay_mul, range_mul, shotspeed_mul, speed_mul, luck_mul, scale_mul = 1, 1, 1, 1, 1, 1, 1
	local scale_add = 0
	local once_done = {}
	for id, n in pairs(counts or {}) do
		if n and n > 0 then
			local d = M.STAT_DELTA[id]
			if d then
				local reps = d.once and 1 or n
				if d.once then
					if once_done[id] then reps = 0 else once_done[id] = true end
				end
				for _ = 1, reps do
					s.damage = s.damage + (d.damage or 0)
					s.firedelay = s.firedelay + (d.firedelay or 0)
					s.shotspeed = s.shotspeed + (d.shotspeed or 0)
					s.range = s.range + (d.range or 0)
					s.luck = s.luck + (d.luck or 0)
					s.speed = s.speed + (d.speed or 0)
					dmg_mul = dmg_mul * (d.damage_mul or 1)
					delay_mul = delay_mul * (d.firedelay_mul or 1)
					range_mul = range_mul * (d.range_mul or 1)
					shotspeed_mul = shotspeed_mul * (d.shotspeed_mul or 1)
					speed_mul = speed_mul * (d.speed_mul or 1)
					luck_mul = luck_mul * (d.luck_mul or 1)
					scale_mul = scale_mul * (d.scale_mul or 1)
					scale_add = scale_add + (d.scale_add or 0)
				end
			end
		end
	end
	s.damage = s.damage * dmg_mul
	s.firedelay = math.max(1, s.firedelay * delay_mul)
	s.range = s.range * range_mul
	s.shotspeed = s.shotspeed * shotspeed_mul
	s.speed = s.speed * speed_mul
	s.luck = s.luck * luck_mul
	s.scale = math.max(0.12, scale_mul + scale_add)
	s.scale_add_applied = scale_add
	s.dmg_mul_applied = dmg_mul
	s.delay_mul_applied = delay_mul
	s.range_mul_applied = range_mul
	s.shotspeed_mul_applied = shotspeed_mul
	s.speed_mul_applied = speed_mul
	s.luck_mul_applied = luck_mul
	s.scale_mul_applied = scale_mul
	return s
end

function M.effect_labels(counts, zh)
	local labels = {}
	local seen = {}
	local function push(name)
		if not name or seen[name] then return end
		seen[name] = true
		labels[#labels + 1] = name
	end
	for id, n in pairs(counts or {}) do
		if n and n > 0 then
			id = tonumber(id) or id
			local info = M.FLAG_NAME[id]
			if info then push(zh and info.zh or info.en) end
			local bn = M.BOMB_NAME and M.BOMB_NAME[id]
			if bn then push(zh and bn.zh or bn.en) end
			-- 无正式短名时不输出带 ID 的占位符（面板也不冒充已完成）
			local oe = M.ONE_EYE[id]
			if oe then push(zh and oe.zh or oe.en) end
			local ek = M.EXTRA_IMPL[id]
			-- 单眼已用 ONE_EYE 标签；多发/主武器 morph 另有行；纯宝宝走「宝宝」行；环绕物走「环绕物」行
			-- also_fx 宝宝（如牛奶）仍可在特效行显示 EXTRA_NAME
			if ek and M.EXTRA_NAME[ek] and not oe
				and ek ~= "multishot" and ek ~= "fetus" and ek ~= "lung"
				and (not M.CRAFT_FAMILIAR_EXTRAS_KEY_SET[ek] or M.CRAFT_FAMILIAR_ALSO_FX[ek])
				and not M.CRAFT_ORBITAL_EXTRAS_KEY_SET[ek]
			then
				-- 妈妈的假发 + 虫群之心 → 合并为「妈妈的假发+」；虫群之心本身不再单列
				if ek == "moms_wig" then
					if (counts[248] or 0) > 0 then
						push(zh and "妈妈的假发+" or "Mom's Wig+")
					else
						local en = M.EXTRA_NAME[ek]
						push(zh and en.zh or en.en)
					end
				elseif ek == "hive_mind" then
					-- 有假发时已并入「妈妈的假发+」
					if (counts[217] or 0) <= 0 then
						local en = M.EXTRA_NAME[ek]
						push(zh and en.zh or en.en)
					end
				else
					local en = M.EXTRA_NAME[ek]
					push(zh and en.zh or en.en)
				end
			end
		end
	end
	table.sort(labels)
	return labels
end

--- 套装特效栏短名（仅 profile.forms 已生效时）
function M.form_effect_labels(forms, zh)
	local labels = {}
	forms = forms or {}
	if forms.conjoined then
		labels[#labels + 1] = zh and "宝宝套" or "Conjoined"
	end
	if forms.guppy then
		labels[#labels + 1] = zh and "猫套" or "Guppy"
	end
	if forms.bookworm then
		labels[#labels + 1] = zh and "书套" or "Bookworm"
	end
	if forms.spun then
		labels[#labels + 1] = zh and "针套" or "Spun"
	end
	return labels
end

-- CRAFT_FAMILIAR_EXTRAS 键集合（避免特效行重复纯宝宝名）
M.CRAFT_FAMILIAR_EXTRAS_KEY_SET = {}
M.CRAFT_FAMILIAR_ALSO_FX = {}
-- extra_key → list_from_counts 字段名（brother_bobby→bobby）
M.CRAFT_FAMILIAR_EXTRA_LIST_KEY = {}
for _, row in ipairs(M.CRAFT_FAMILIAR_EXTRAS) do
	M.CRAFT_FAMILIAR_EXTRAS_KEY_SET[row.key] = true
	M.CRAFT_FAMILIAR_EXTRA_LIST_KEY[row.key] = row.list or row.key
	if row.also_fx then
		M.CRAFT_FAMILIAR_ALSO_FX[row.key] = true
	end
end

M.CRAFT_ORBITAL_EXTRAS_KEY_SET = {}
for _, row in ipairs(M.CRAFT_ORBITAL_EXTRAS) do
	M.CRAFT_ORBITAL_EXTRAS_KEY_SET[row.key] = true
end

--- 制造宝宝审计短名（独立「宝宝」行；不挤占特效）
function M.familiar_labels(extras, zh)
	local labels = {}
	extras = extras or {}
	for _, row in ipairs(M.CRAFT_FAMILIAR_EXTRAS) do
		if extras[row.key] then
			labels[#labels + 1] = zh and row.zh or row.en
		end
	end
	return labels
end

--- 制造环绕物审计短名（独立「环绕物」行；按配方 counts）
function M.orbital_labels(counts, zh)
	local labels = {}
	counts = counts or {}
	for _, row in ipairs(M.CRAFT_ORBITAL_EXTRAS) do
		local id = tonumber(row.id)
		if id and (counts[id] or 0) > 0 then
			labels[#labels + 1] = zh and row.zh or row.en
		end
	end
	return labels
end

--- 配方是否需要左右眼相位（眼药水 / 单眼道具）
function M.needs_eye_phase(counts)
	if (counts and counts[600] or 0) > 0 then return true end
	for id, n in pairs(counts or {}) do
		if n and n > 0 and M.ONE_EYE[id] then return true end
	end
	return false
end

--- 当前眼睛相位的单眼加成（side：0 左 / 1 右）
function M.one_eye_bonus(counts, side)
	local out = {damage = 0, range = 0, shotspeed = 0, damage_mul = 1, blood_variant = false}
	side = (side or 0) % 2
	for id, n in pairs(counts or {}) do
		local oe = M.ONE_EYE[id]
		if oe and n and n > 0 and oe.side == side then
			local copies = oe.once and 1 or n
			for _ = 1, copies do
				out.damage = out.damage + (oe.damage or 0)
				out.range = out.range + (oe.range or 0)
				out.shotspeed = out.shotspeed + (oe.shotspeed or 0)
				out.damage_mul = out.damage_mul * (oe.damage_mul or 1)
				out.blood_variant = out.blood_variant or oe.blood_variant == true
			end
		end
	end
	return out
end

function M.weapon_label(weapon, zh)
	local info = M.WEAPON_NAME[weapon or 1]
	if not info then return tostring(weapon or 1) end
	return zh and info.zh or info.en
end

--- 血泪作主攻击方式时（武器表决为眼泪），审计「方式」写血泪而非眼泪
function M.profile_shows_haemo_weapon(profile)
	if not profile then return false end
	local ex = profile.extras or {}
	if not ex.haemolacria then return false end
	return (profile.weapon or 1) == 1
end

function M.profile_attack_label(profile, zh)
	if M.profile_shows_haemo_weapon(profile) then
		return zh and "血泪" or "Haemolacria"
	end
	return M.weapon_label(profile and profile.weapon, zh)
end

--- 蓝图 pedestal EID：正式句式，见 craft_eid_copy.lua / blueprint_craft_eid_copy_review.md
function M.collectible_craft_eid_lines(id, zh)
	local copy = require("Qing_Remaster_scripts.others.craft_eid_copy")
	return copy.collectible_craft_eid_lines(id, zh)
end

function M.collectible_craft_eid_text(id, zh)
	local copy = require("Qing_Remaster_scripts.others.craft_eid_copy")
	return copy.collectible_craft_eid_text(id, zh)
end

function M.target_base_label(target, zh)
	local info = M.TARGET_BASE[target]
	if not info then return nil end
	return zh and info.zh or info.en
end

function M.fmt_num(n, digits)
	digits = digits or 2
	local m = 10 ^ digits
	local v = math.floor((n or 0) * m + 0.5) / m
	return tostring(v)
end

--- 当前主武器实际消费的兼容组合标签（写入审计「特效」行）
--- 血泪：方式已写「血泪」时，特效只挂简略 guest 名（硫磺/科技/…），不写长串「覆盖/眼泪+X/爆裂X」
function M.compat_labels(profile, zh)
	local labels = {}
	local syn = (profile and profile.synergy) or {}
	local host = profile and profile.weapon
	local consumed = (profile and profile.compat_consumed) or {}
	local ex = profile and profile.extras or {}

	if ex.haemolacria then
		if ex.haemo_override then
			-- 均分 guest 优先；否则列 haemo_guests
			local guests = ex.haemo_share_guests
			if not guests or #guests == 0 then
				guests = ex.haemo_guests or {}
			end
			local seen = {}
			for _, w in ipairs(guests) do
				w = tonumber(w) or w
				if w and not seen[w] then
					seen[w] = true
					labels[#labels + 1] = M.weapon_label(w, zh)
				end
			end
		elseif ex.haemo_ludo_proc then
			labels[#labels + 1] = zh and "血泪触发" or "HaeProc"
		elseif ex.haemo_fetus_proc then
			labels[#labels + 1] = zh and "落地爆发" or "LandBurst"
		end
		-- 刀/剑作主武时「方式」已写刀/剑；特效靠 FLAG_NAME「血泪」，不再写长兼容串
	else
		local host_name = M.weapon_label(host, zh)
		for _, w in ipairs(consumed) do
			labels[#labels + 1] = host_name .. "+" .. M.weapon_label(w, zh)
		end
	end

	-- 同种叠层等非 BRANCH_COMPAT 形态变化，也并入特效标注
	if syn.thick_brim then
		labels[#labels + 1] = zh and "粗硫磺" or "ThickBrim"
	end
	if (syn.extra_shots or 0) > 0 then
		labels[#labels + 1] = (zh and "叠+" or "stk+") .. tostring(syn.extra_shots)
	end
	return labels
end

--- Compact audit lines for Blueprint UI.
--- player 可选：再解析一次套装，写入独立「套装」行
function M.audit_lines(profile, zh, player)
	if not profile then
		return {zh and "（空配方）" or "(empty recipe)"}
	end
	local st = profile.stats or M.BASE_STATS
	local ms = profile.multishot or {count = 1}
	local lines = {}
	lines[#lines + 1] = (zh and "方式 " or "Wpn ") .. M.profile_attack_label(profile, zh)
		.. "  x" .. tostring(ms.count)
	-- 显示端与 Found HUD / EID 对齐：内部 MaxFireDelay → 每秒攻击数。
	local function display_fire_rate(delay)
		return 30 / (math.max(-0.75, tonumber(delay) or 10) + 1)
	end
	local tear_txt = M.fmt_num(display_fire_rate(st.firedelay), 2)
	local wmul = tonumber(st.weapon_delay_mul) or 1
	if wmul ~= 1 and st.firedelay_base ~= nil then
		-- 主武器倍率作用于内部 delay；括号只辅助展示基础 Fire Rate。
		tear_txt = tear_txt .. "(" .. (zh and "底" or "base ")
			.. M.fmt_num(display_fire_rate(st.firedelay_base), 2) .. ")"
	end
	lines[#lines + 1] = (zh and "伤害 " or "DMG ") .. M.fmt_num(st.damage, 2)
		.. (zh and "  射速 " or "  Tear ") .. tear_txt
	lines[#lines + 1] = (zh and "弹速 " or "SS ") .. M.fmt_num(st.shotspeed, 2)
		.. (zh and "  射程 " or "  Rng ") .. M.fmt_num((tonumber(st.range) or 0) / 40, 2)
	lines[#lines + 1] = (zh and "移速 " or "Spd ") .. M.fmt_num(st.speed, 2)
		.. (zh and "  幸运 " or "  Luk ") .. M.fmt_num(st.luck, 1)
	local mods = M.attack_modifiers_from_profile(profile)
	if mods and mods.chocolate then
		local pct = math.floor(mods.ratio * 100 + 0.5)
		local base_delay = tonumber(st.firedelay) or 10
		local final_delay = M.attack_delay_from_modifiers(base_delay, mods)
		lines[#lines + 1] = (zh and "巧克力 " or "Choco ")
			.. tostring(pct) .. "%"
			.. (zh and " 伤×" or " dmg×") .. M.fmt_num(mods.damage_mul, 2)
			.. (zh and " 尺×" or " sz×") .. M.fmt_num(mods.size_mul, 2)
			.. (zh and " 蓄" or " charge ") .. tostring(mods.charge_frames or 0) .. (zh and "帧" or "f")
			.. (zh and " 射速 " or " rate ") .. M.fmt_num(display_fire_rate(final_delay), 2)
	end
	if mods and mods.techx then
		local pct = math.floor((mods.techx_ratio or 1) * 100 + 0.5)
		lines[#lines + 1] = (zh and "科技X " or "TechX ")
			.. tostring(pct) .. "%"
			.. (zh and " 环×" or " rad×") .. M.fmt_num(mods.techx_radius_mul, 2)
			.. (zh and " 伤×" or " dmg×") .. M.fmt_num(mods.techx_damage_mul, 2)
			.. (zh and " 间隔×" or " delay×") .. M.fmt_num(mods.techx_delay_mul, 2)
	end
	if profile.extras and profile.extras.cursed_eye then
		lines[#lines + 1] = (zh and "诅咒眼 " or "CursedEye ")
			.. tostring(math.floor((mods.charge_ratio or 1) * 100 + 0.5)) .. "%"
			.. (zh and " 重放 " or " replay ") .. tostring(mods.cursed_replays or 0)
	end
	local sc = tonumber(st.scale) or 1
	if math.abs(sc - 1) > 0.01 then
		lines[#lines + 1] = (zh and "弹体 " or "Size ") .. M.fmt_num(sc, 2)
			.. (zh and "×（泪/弹/炸）" or "x (tear/bomb)")
	end
	local fx_parts = M.effect_labels(profile.counts, zh)
	local ex = profile.extras or {}
	local seen_fx = {}
	for _, p in ipairs(fx_parts) do seen_fx[p] = true end
	local function push_fx(name)
		if not name or seen_fx[name] then return end
		seen_fx[name] = true
		fx_parts[#fx_parts + 1] = name
	end
	-- 方式已写「血泪」时，特效不再重复「血泪」短名
	if M.profile_shows_haemo_weapon(profile) then
		local hae_name = zh and "血泪" or "Haemolacria"
		seen_fx[hae_name] = true
		for i = #fx_parts, 1, -1 do
			if fx_parts[i] == hae_name then
				table.remove(fx_parts, i)
			end
		end
	end
	-- extras 布尔（科技2 等）：确保描述可见
	if ex.tech2 then push_fx(zh and "科技2" or "Tech2") end
	if ex.tech5 then push_fx(zh and "科技0.5" or "Tech5") end
	if ex.chocolate then push_fx(zh and "巧克力奶" or "Choco") end
	if ex.cursed_eye then push_fx(zh and "诅咒眼" or "CursedEye") end
	if ex.fruit_cake then push_fx(zh and "水果蛋糕" or "FruitCake") end
	-- 宝宝不进特效行；见下方独立「宝宝」行（also_fx 项仍可由 effect_labels/EXTRA_NAME 进特效）
	-- 制造复活源：特效行显示剩余/已用尽
	if player and profile.craft_uid then
		local ok_bp, bp = pcall(require, "Qing_Remaster_scripts.items.Item_Blue_Print")
		local rec = (ok_bp and bp and bp.find_craft) and bp.find_craft(player, profile.craft_uid) or nil
		if rec then
			for _, src in ipairs(M.CRAFT_REVIVE_SOURCES) do
				if ex[src.key] then
					local base = M.EXTRA_NAME[src.key]
					local old = base and (zh and base.zh or base.en)
					local neu = M.craft_revive_fx_label(src.key, rec, zh)
					if old and neu and old ~= neu then
						for i = #fx_parts, 1, -1 do
							if fx_parts[i] == old then fx_parts[i] = neu end
						end
					end
				end
			end
		end
	end
	local dyn_label = {
		money = {zh = "金钱力量", en = "Money"},
		whore = {zh = "大淫妇", en = "Whore"},
		bloody_lust = {zh = "嗜血", en = "Lust"},
		bloody_gust = {zh = "血怒", en = "Gust"},
		experimental = {zh = "针剂", en = "Exp"},
		adrenaline = {zh = "肾上腺素", en = "Adr"},
		crown_light = {zh = "白王冠", en = "CoL"},
		dark_crown = {zh = "黑王冠", en = "DPC"},
		purity = {zh = "白莲", en = "Purity"},
		lusty_blood = {zh = "杀戮嗜血", en = "Lusty"},
		libra = {zh = "天平", en = "Libra"},
		milk = {zh = "牛奶", en = "Milk"},
		camo_undies = {zh = "迷彩", en = "Camo"},
		jupiter = {zh = "木星", en = "Jupiter"},
		paschal_candle = {zh = "蜡烛层", en = "Paschal"},
		rock_bottom = {zh = "谷底石", en = "Rock Bottom"},
		red_stew = {zh = "红豆汤", en = "RedStew"},
		candy_heart = {zh = "糖心", en = "CandyHeart"},
		soul_locket = {zh = "魂匣", en = "SoulLocket"},
		heartbreak = {zh = "心碎", en = "Heartbreak"},
		keepers_sack = {zh = "店长袋", en = "KeepersSack"},
		binge_eater = {zh = "暴食", en = "Binge"},
		false_phd = {zh = "假博士", en = "FalsePHD"},
		neptunus = {zh = "海王星", en = "Neptunus"},
	}
	for _, tag in ipairs(profile.dyn_tags or {}) do
		local info = dyn_label[tag]
		if info then push_fx(zh and info.zh or info.en) end
	end
	if profile.runtime and profile.runtime.occult_stats_only then
		-- 覆盖泪弹 flag 名「可控泪弹」为降级标签
		for i = #fx_parts, 1, -1 do
			if fx_parts[i] == (zh and "可控泪弹" or "Eye of the Occult") then
				table.remove(fx_parts, i)
			end
		end
		seen_fx[zh and "可控泪弹" or "Eye of the Occult"] = nil
		push_fx(zh and "玄秘(属性)" or "Occult (stats)")
	end
	local body_m = tonumber(profile.body_scale_mul) or 1
	if math.abs(body_m - 1) > 0.01 then
		push_fx((zh and "体型×" or "Body×") .. M.fmt_num(body_m, 2))
	end
	for _, c in ipairs(M.compat_labels(profile, zh)) do
		push_fx(c)
	end
	-- 套装 / 宝宝单独一行；不再写入「特效」串，避免挤占与重复
	local forms = profile.forms or {}
	if player and profile.counts then
		local live_forms = M.resolve_player_forms(player, profile.counts, "audit_lines")
		for k, v in pairs(live_forms) do
			if v then forms[k] = true end
		end
	end
	local form_parts = M.form_effect_labels(forms, zh)
	if #form_parts > 0 then
		lines[#lines + 1] = (zh and "套装 " or "Form ") .. table.concat(form_parts, zh and "·" or ",")
	end
	local fam_parts = M.familiar_labels(ex, zh)
	if #fam_parts > 0 then
		-- 制造复活宝宝：标注剩余/已用尽
		if player and profile.craft_uid then
			local ok_bp, bp = pcall(require, "Qing_Remaster_scripts.items.Item_Blue_Print")
			local rec = (ok_bp and bp and bp.find_craft) and bp.find_craft(player, profile.craft_uid) or nil
			if rec then
				for _, src in ipairs(M.CRAFT_REVIVE_SOURCES) do
					if src.follower and ex[src.key] then
						local row_zh = nil
						local row_en = nil
						for _, row in ipairs(M.CRAFT_FAMILIAR_EXTRAS) do
							if row.key == src.key then
								row_zh, row_en = row.zh, row.en
								break
							end
						end
						local old = zh and row_zh or row_en
						local used = M.craft_revive_source_spent(rec, src.key)
						local uses = tonumber(src.uses) or 0
						local neu = old
						if old and uses > 0 then
							if used >= uses then
								neu = zh and (old .. "(已用尽)") or (old .. "(spent)")
							elseif used > 0 then
								local left = uses - used
								neu = zh and (old .. "(剩" .. tostring(left) .. ")") or (old .. "(left" .. tostring(left) .. ")")
							end
						end
						if old and neu and old ~= neu then
							for i, name in ipairs(fam_parts) do
								if name == old then fam_parts[i] = neu end
							end
						end
					end
				end
			end
		end
		local fam = table.concat(fam_parts, zh and "·" or ",")
		local fam_limit = 48
		if #fam > fam_limit then
			local keep = {}
			local used = 0
			for i = 1, #fam_parts do
				local part = fam_parts[i]
				local add = #part + ((#keep > 0) and 1 or 0)
				if used + add > fam_limit and #keep > 0 then break end
				keep[#keep + 1] = part
				used = used + add
			end
			fam = table.concat(keep, zh and "·" or ",")
				.. ((#keep < #fam_parts) and "…" or "")
		end
		lines[#lines + 1] = (zh and "宝宝 " or "Fam ") .. fam
	end
	local orb_parts = M.orbital_labels(profile.counts, zh)
	if #orb_parts > 0 then
		local orb = table.concat(orb_parts, zh and "·" or ",")
		local orb_limit = 48
		if #orb > orb_limit then
			local keep = {}
			local used = 0
			for i = 1, #orb_parts do
				local part = orb_parts[i]
				local add = #part + ((#keep > 0) and 1 or 0)
				if used + add > orb_limit and #keep > 0 then break end
				keep[#keep + 1] = part
				used = used + add
			end
			orb = table.concat(keep, zh and "·" or ",")
				.. ((#keep < #orb_parts) and "…" or "")
		end
		lines[#lines + 1] = (zh and "环绕物 " or "Orb ") .. orb
	end
	if #fx_parts > 0 then
		local e = table.concat(fx_parts, zh and "·" or ",")
		-- 兼容/行为标签优先可见：过长时从 tearflag 侧截断
		local limit = 48
		if #e > limit then
			local keep = {}
			local used = 0
			for i = #fx_parts, 1, -1 do
				local part = fx_parts[i]
				local add = #part + ((#keep > 0) and 1 or 0)
				if used + add > limit and #keep > 0 then break end
				keep[#keep + 1] = part
				used = used + add
			end
			local rev = {}
			for i = #keep, 1, -1 do rev[#rev + 1] = keep[i] end
			e = (#rev < #fx_parts and "…" or "") .. table.concat(rev, zh and "·" or ",")
		end
		lines[#lines + 1] = (zh and "特效 " or "FX ") .. e
	else
		lines[#lines + 1] = zh and "特效 （无）" or "FX (none)"
	end
	local uns = profile.unsupported_morphs or {}
	if #uns > 0 then
		local names = {}
		for _, w in ipairs(uns) do names[#names + 1] = M.weapon_label(w, zh) end
		lines[#lines + 1] = (zh and "未兼容 " or "Miss ") .. table.concat(names, "·")
	end
	return lines
end

--- Spread directions for multishot (count >= 1).
function M.multishot_dirs(base_dir, count)
	count = math.max(1, math.floor(tonumber(count) or 1))
	local dirs = {}
	if count <= 1 then
		dirs[1] = base_dir
		return dirs
	end
	local span = math.min(60, 10 * (count - 1))
	for i = 1, count do
		local t = (i - 1) / (count - 1) - 0.5
		dirs[i] = auxi.get_by_rotate(base_dir, t * span * 2)
	end
	return dirs
end

--- Mom's Eye（55）：min(100, luck*10+50)% 向后额外 1 发；幸运≥5 必出。
function M.moms_eye_chance(luck)
	luck = tonumber(luck) or 0
	return math.min(1, math.max(0, luck * 0.1 + 0.5))
end

--- Loki's Horns（87）：min(100, luck*5+25)% 另三正方向；幸运≤-5 为 0，≥15 必出。
function M.lokis_horns_chance(luck)
	luck = tonumber(luck) or 0
	return math.min(1, math.max(0, luck * 0.05 + 0.25))
end

--- 主弹道 + 套装额外弹道（Conjoined ±45°；Bookworm 25% 再 +1）
--- + Mom's Eye / Loki's Horns（按配方 counts 与档案 luck）
--- opts: {count=, roll_bookworm=, rng=, seed=}
function M.volley_dirs(base_dir, profile, opts)
	opts = opts or {}
	local count = opts.count
	if count == nil then
		count = (profile and profile.multishot and profile.multishot.count) or 1
	end
	local dirs = M.multishot_dirs(base_dir, count)
	local roll_opts = {
		roll_bookworm = opts.roll_bookworm == true,
		rng = opts.rng,
	}
	if roll_opts.roll_bookworm and not roll_opts.rng and opts.seed then
		roll_opts.rng = M.derived_rng(opts.seed, 91001)
	end
	for _, d in ipairs(M.form_extra_shot_dirs(base_dir, profile, roll_opts)) do
		dirs[#dirs + 1] = d
	end
	local counts = profile and profile.counts or {}
	local luck = opts.luck
	if luck == nil then
		luck = profile and profile.stats and profile.stats.luck or 0
	end
	luck = tonumber(luck) or 0
	local base_seed = opts.seed
	local function roll_with_salt(p, salt)
		if p <= 0 then return false end
		if p >= 1 then return true end
		local rng = opts.rng
		if not rng and base_seed then
			rng = M.derived_rng(base_seed, salt)
		end
		if rng and rng.RandomFloat then
			return rng:RandomFloat() < p
		end
		return math.random() < p
	end
	local aim = base_dir
	if not aim or aim:Length() < 0.01 then
		aim = Vector(10, 0)
	end
	local len = aim:Length()
	local aim_n = aim:Normalized()
	-- 妈妈的眼睛：向后 1 发（独立 RNG，不与洛基角抢同一流）
	-- 幸运 0 → 50%；幸运≥5 → 100%。不是接近 0。
	if M.count_of(counts, 55) > 0 and roll_with_salt(M.moms_eye_chance(luck), 55087) then
		dirs[#dirs + 1] = aim_n * (-len)
	end
	-- 洛基的角：其余三个正方向（相对当前射击方向四向对齐）
	-- 幸运 0 → 25%；幸运≥15 → 100%。
	-- 注意：用 get_by_rotate 相对瞄准，避免 MakeVector 与引擎角约定不一致时「四向看起来没变」。
	if M.count_of(counts, 87) > 0 and roll_with_salt(M.lokis_horns_chance(luck), 55097) then
		for _, add in ipairs({90, 180, 270}) do
			dirs[#dirs + 1] = auxi.get_by_rotate(aim, add, len)
		end
	end
	-- 眼瘤（558）：每份 1/3 出 1 发任意方向（对齐 attack_list_calculator 无 RGON 回退）。
	-- 禁止走玩家 GetMultiShotParams：那是持有者库存，不是配方。
	local eye_n = math.max(0, math.floor(M.count_of(counts, 558)))
	if eye_n > 0 then
		for copy = 1, eye_n do
			local rng = opts.rng
			if not rng and base_seed then
				rng = M.derived_rng(base_seed, 55800 + copy)
			end
			local proc = false
			local ang = nil
			if rng and rng.RandomFloat then
				proc = rng:RandomFloat() < (1 / 3)
				if proc then ang = rng:RandomFloat() * 360 end
			else
				proc = math.random() < (1 / 3)
				if proc then ang = math.random() * 360 end
			end
			if proc then
				dirs[#dirs + 1] = auxi.get_by_rotate(aim, ang or 0, len)
			end
		end
	end
	return dirs
end

--- ctx = {player=, rec=, air=, runtime=}；无 ctx 时仅静态配方（审计/预览）
function M.build_profile(ingredients, ctx)
	local counts = M.counts_from_ingredients(ingredients)
	local audit_fb = ctx and ctx.rec and ctx.rec.audit == true
	local source_counts = M.source_counts_from_ingredients(ingredients, audit_fb)
	-- 392 十二宫：虚拟叠加本层星座（不改 source_counts / 材料清单）
	local zodiac_effect = nil
	do
		local ok, Zodiac = pcall(require, "Qing_Remaster_scripts.others.craft_zodiac")
		if ok and Zodiac and Zodiac.apply_to_counts then
			zodiac_effect = Zodiac.apply_to_counts(counts, ctx)
		end
	end
	local list = M.list_from_counts(counts)
	local weapon, morph_items, extras, compat_consumed, unsupported_morphs = M.resolve_weapon(list, counts)
	extras.paschal_candle_visual = (counts[567] or 0) > 0
	extras.crown_of_light_visual = (counts[415] or 0) > 0
	extras.dark_princes_crown_visual = (counts[442] or 0) > 0
	local synergy = M.build_synergy(weapon, list, extras)
	local multishot = M.build_multishot(counts)
	local stats = M.stats_from_counts(counts)
	local body_scale_mul = M.body_scale_from_counts(counts)
	local dyn_tags = {}
	local runtime = {}

	local Dyn = require("Qing_Remaster_scripts.others.craft_dynamic_stats")
	if Dyn and Dyn.apply_to_stats then
		local dyn = Dyn.apply_to_stats(stats, {
			player = ctx and ctx.player,
			rec = ctx and ctx.rec,
			air = ctx and ctx.air,
			counts = counts,
			runtime = ctx and ctx.runtime,
		})
		if dyn then
			body_scale_mul = body_scale_mul * (dyn.body_scale_mul or 1)
			dyn_tags = dyn.tags or dyn_tags
			runtime = dyn.runtime or runtime
			if dyn.extras then
				for k, v in pairs(dyn.extras) do
					extras[k] = v
				end
			end
			if dyn.flag_extra and stats then
				-- flag OR 由调用方合并；此处挂到 profile
			end
			if dyn.flag_extra then
				runtime.flag_extra = dyn.flag_extra
			end
		end
	end

	-- 主武器射速倍率写入数值（审计行与开火共用）
	local wmul = M.weapon_fire_delay_mul(weapon)
	stats.firedelay_base = stats.firedelay
	stats.weapon_delay_mul = wmul
	-- 动态 fire_rate 倍率（溢泪/眼药水等）在武器倍率之后再折算
	local fr_mul = tonumber(stats.fire_rate_mul) or 1
	if fr_mul ~= 1 and fr_mul > 0 then
		local fr = 30 / (math.max(1, stats.firedelay) + 1)
		fr = fr * fr_mul
		stats.firedelay = math.max(1, 30 / fr - 1)
	end
	stats.firedelay = math.max(1, stats.firedelay * wmul)
	-- 血泪覆盖硫磺/博士：Wiki 在血泪 tears down 后再加固定 delay（不再叠武器倍率）
	if extras.haemo_override and extras.haemo_guests then
		local has_brim, has_dr = false, false
		for _, g in ipairs(extras.haemo_guests) do
			if g == 2 then has_brim = true end
			if g == 5 then has_dr = true end
		end
		if has_brim then
			stats.firedelay = stats.firedelay + 20
		elseif has_dr then
			stats.firedelay = stats.firedelay + 10
		end
	end
	stats.fire_rate_mul = 1
	body_scale_mul = math.max(0.25, math.min(3, body_scale_mul))

	local flag_mask = M.mask_from_counts(counts)
	local bomb_flag_mask, bomb_variant = M.bomb_effects_from_counts(counts, 0)
	if runtime.flag_extra then
		flag_mask = flag_mask | runtime.flag_extra
	end
	-- 血泪：不写 TEAR_BURSTSPLIT（原版 flag 会读玩家背包生成硫磺/炸弹等）；改自模拟。
	if extras.haemolacria and TearFlags and TearFlags.TEAR_BURSTSPLIT then
		flag_mask = flag_mask & ~TearFlags.TEAR_BURSTSPLIT
	end
	-- 玄秘：仅泪弹系主武保留 TEAR_OCCULT；其余只吃属性
	local occult_tear_weap = {
		[1] = true, [7] = true, [8] = true, [10] = true, [14] = true,
	}
	if (counts[572] or 0) > 0 and TearFlags and TearFlags.TEAR_OCCULT and not occult_tear_weap[weapon] then
		flag_mask = flag_mask & ~TearFlags.TEAR_OCCULT
		runtime.occult_stats_only = true
	end

	local forms = M.resolve_player_forms(
		ctx and ctx.player,
		counts,
		(ctx and ctx.air) and "air_bind" or ((ctx and ctx.commit_state) and "confirm" or "preview")
	)
	M.apply_player_form_stats(stats, forms)
	if M.enable_form_log then
		form_log_write({
			e = "profile_stats",
			src = (ctx and ctx.air) and "air_bind" or "preview",
			dmg = stats and stats.damage,
			spd = stats and stats.speed,
			forms = {
				bookworm = forms.bookworm and true or false,
				spun = forms.spun and true or false,
				guppy = forms.guppy and true or false,
				conjoined = forms.conjoined and true or false,
			},
			player = (ctx and ctx.player) and true or false,
		})
	end
	if forms.guppy and TearFlags and TearFlags.TEAR_MULLIGAN then
		flag_mask = flag_mask | TearFlags.TEAR_MULLIGAN
	end

	local rec = ctx and ctx.rec
	local commit_state = ctx and (ctx.commit_state == true or ctx.air ~= nil)
	-- 谷底石头允许在制造预览阶段就计入峰值；其它持续状态仍只服从 commit_state。
	local commit_rock_bottom = commit_state or (ctx and ctx.commit_rock_bottom == true)
	-- 562 移除时清峰值；保留 562 时：底层算完 → 更新峰值并覆写 → Libra
	if (counts[562] or 0) <= 0 then
		if commit_rock_bottom and rec then rec.rock_bottom_max = nil end
	elseif Dyn and Dyn.apply_rock_bottom and rec then
		if commit_rock_bottom then
			Dyn.apply_rock_bottom(stats, rec)
		elseif rec.rock_bottom_max then
			-- 预览：只读应用已有峰值，不更新
			local maxv = rec.rock_bottom_max
			if type(maxv) == "table" then
				if maxv.damage ~= nil then stats.damage = maxv.damage end
				if maxv.speed ~= nil then stats.speed = maxv.speed end
				if maxv.range ~= nil then stats.range = maxv.range end
				if maxv.shotspeed ~= nil then stats.shotspeed = maxv.shotspeed end
				if maxv.luck ~= nil then stats.luck = maxv.luck end
				if maxv.fire_rate ~= nil then
					stats.firedelay = math.max(1, 30 / math.max(0.1, maxv.fire_rate) - 1)
				end
			end
		end
	end
	if (counts[304] or 0) > 0 and Dyn and Dyn.apply_libra then
		Dyn.apply_libra(stats, ctx and ctx.player)
	end

	if zodiac_effect then
		runtime.zodiac_effect = zodiac_effect
		extras.zodiac = true
		extras.zodiac_effect = zodiac_effect
	elseif (counts[392] or 0) > 0 then
		extras.zodiac = true
	end

	M.apply_base_quality_to_stats(stats, M.resolve_base_quality(ctx))

	return {
		weapon = weapon,
		morph_items = morph_items,
		counts = counts,
		source_counts = source_counts,
		list = list,
		extras = extras,
		synergy = synergy,
		multishot = multishot,
		compat_consumed = compat_consumed or {},
		unsupported_morphs = unsupported_morphs or {},
		flag_mask = flag_mask,
		bomb_flag_mask = bomb_flag_mask,
		bomb_variant = bomb_variant,
		stats = stats,
		body_scale_mul = body_scale_mul,
		dyn_tags = dyn_tags,
		runtime = runtime,
		forms = forms,
		source_ingredients = ingredients,
	}
end

--- 纯逻辑自检（不依赖 Isaac API）：§14.3 样例 + BRANCH_COMPAT 成对消费
function M.verify_weapon_vote_examples()
	local function counts_from_ids(ids)
		local c = {}
		for _, id in ipairs(ids) do c[id] = (c[id] or 0) + 1 end
		return c
	end
	local cases = {
		{name = "Epic+Knife+Brim", ids = {168, 114, 118}, expect = 6},
		{name = "CSec+Knife+Tech", ids = {678, 114, 68}, expect = 14},
		{name = "Sword+Knife+Tech", ids = {579, 114, 68}, expect = 13},
		{name = "Knife+Brim+TechX+Lung", ids = {114, 118, 395, 229}, expect = 4},
		{name = "Dr+Lung", ids = {52, 229}, expect = 7},
		{name = "exact Brim+CSec", ids = {118, 678}, expect = 2},
		{name = "Brim+CSec+Knife", ids = {118, 678, 114}, expect = 14}, -- CSec 可消费两者
		-- §14.7.1–9 两件表决
		{name = "Knife+Tech", ids = {114, 68}, expect = 4},
		{name = "Brim+Dr", ids = {118, 52}, expect = 5},
		{name = "Brim+Sword", ids = {118, 579}, expect = 2},
		{name = "TechX+Tech", ids = {395, 68}, expect = 9},
		{name = "TechX+Dr", ids = {395, 52}, expect = 5},
		{name = "Tech+Dr", ids = {68, 52}, expect = 5},
		{name = "Epic+Dr", ids = {168, 52}, expect = 6},
		{name = "Epic+Sword", ids = {168, 579}, expect = 6},
		{name = "Dr+Sword", ids = {52, 579}, expect = 5},
		-- Ludovico 改形 / 仍被覆盖
		{name = "Ludo alone", ids = {329}, expect = 8},
		{name = "Ludo+Brim", ids = {329, 118}, expect = 8},
		{name = "Ludo+Tech", ids = {329, 68}, expect = 8},
		{name = "Ludo+TechX", ids = {329, 395}, expect = 8},
		{name = "Ludo+Knife", ids = {329, 114}, expect = 8},
		{name = "Ludo+Epic", ids = {329, 168}, expect = 6},
		{name = "Ludo+CSec", ids = {329, 678}, expect = 14},
		{name = "Ludo+Sword", ids = {329, 579}, expect = 13},
		-- §15.4 血泪覆盖可覆盖主武 → 眼泪（含妈刀）；卢多/剖腹产保留主武
		{name = "Hae+Brim", ids = {531, 118}, expect = 1},
		{name = "Hae+Tech", ids = {531, 68}, expect = 1},
		{name = "Hae+TechX", ids = {531, 395}, expect = 1},
		{name = "Hae+Dr", ids = {531, 52}, expect = 1},
		{name = "Hae+Knife", ids = {531, 114}, expect = 1},
		{name = "Hae+Brim+TechX", ids = {531, 118, 395}, expect = 1},
		{name = "Hae+Ludo", ids = {531, 329}, expect = 8},
		{name = "Hae+CSec", ids = {531, 678}, expect = 14},
		-- 肺/史诗仍优先于血泪
		{name = "Hae+Lung", ids = {531, 229}, expect = 7},
		{name = "Hae+Epic", ids = {531, 168}, expect = 6},
	}
	local report = {}
	local ok_all = true
	for _, case in ipairs(cases) do
		local counts = counts_from_ids(case.ids)
		local list = M.list_from_counts(counts)
		local w = M.resolve_weapon(list, counts)
		local pass = w == case.expect
		if not pass then ok_all = false end
		report[#report + 1] = {
			name = case.name, expect = case.expect, got = w, pass = pass,
		}
	end
	-- pair：两件配方必须选到能消费另一件的分支
	for host, can in pairs(M.BRANCH_COMPAT) do
		for guest in pairs(can) do
			local host_id, guest_id
			for _, m in ipairs(M.MORPH) do
				if m.weapon == host then host_id = m.id end
				if m.weapon == guest then guest_id = m.id end
			end
			if host_id and guest_id then
				local counts = counts_from_ids({host_id, guest_id})
				local list = M.list_from_counts(counts)
				local w, _, _, consumed = M.resolve_weapon(list, counts)
				local consumes = false
				for _, cw in ipairs(consumed or {}) do
					if cw == guest or cw == host then consumes = true end
				end
				-- 胜者必须是二者之一，且胜者 BRANCH_COMPAT 含另一者
				local other = (w == host) and guest or host
				local good = (w == host or w == guest)
					and M.BRANCH_COMPAT[w] and M.BRANCH_COMPAT[w][other]
				if not good then ok_all = false end
				report[#report + 1] = {
					name = "pair "..tostring(host).."+"..tostring(guest),
					expect = "either consumes",
					got = w,
					pass = good == true,
				}
			end
		end
	end
	return ok_all, report
end

--- 整表写入 TearFlags。激光优先 Clear+Add，避免 Fire* 继承玩家位后赋值粘滞。
function M.write_entity_tear_flags(ent, flags)
	if not ent or flags == nil or ent.TearFlags == nil then return end
	local laser = ent.ToLaser and ent:ToLaser()
	if laser and laser.ClearTearFlags then
		local cur = laser.TearFlags
		if cur then
			pcall(function() laser:ClearTearFlags(cur) end)
		end
		if laser.AddTearFlags then
			pcall(function() laser:AddTearFlags(flags) end)
		end
		laser.TearFlags = flags
		return
	end
	ent.TearFlags = flags
end

local function flag_bit(flags, bit)
	return bit and flags and ((flags & bit) == bit)
end

--- FireBrimstone / FireTech* 会把玩家「我的镜像」写进 CurveStrength、「弯勺」写进 HomingType，
--- 与 TearFlags 脱钩；只清 TearFlags 不够。按本次配方 flags 对齐激光运动场。
--- CurveStrength 缺省 1：玩家未持镜像而配方有时，Fire* 不会预填；精确常数可后续探针校准。
function M.apply_laser_craft_motion(ent, tear_flags)
	local laser = ent and ent.ToLaser and ent:ToLaser()
	if not laser then return end
	local flags = tear_flags
	if flags == nil and laser.TearFlags ~= nil then
		flags = laser.TearFlags
	end
	local want_boom = flag_bit(flags, TearFlags and TearFlags.TEAR_BOOMERANG)
	if laser.CurveStrength ~= nil then
		if want_boom then
			if (tonumber(laser.CurveStrength) or 0) == 0 then
				laser.CurveStrength = 1
			end
		else
			laser.CurveStrength = 0
		end
	end
	local want_home = flag_bit(flags, TearFlags and TearFlags.TEAR_HOMING)
	if laser.SetHomingType then
		pcall(function() laser:SetHomingType(want_home and 1 or 0) end)
	elseif laser.HomingType ~= nil then
		laser.HomingType = want_home and 1 or 0
	end
end

--- 制造激光身份：Spawner 改挂 Flight（抑制玩家镜像 CurveStrength 回写），并缓存 flags。
--- Homing sample 随父体移动：就地改 GetSamples 返回的内部 Vector（见 shift_homing_laser_samples）。
--- 权重：近端多拉、末端不动，避免整条路径刚体平移把弯勺尖端拖离目标。
M.CRAFT_LASER_FLAGS_KEY = "qing_craft_laser_flags"
M.CRAFT_LASER_AIR_KEY = "qing_craft_laser_air"
M.CRAFT_LASER_VARIANT_KEY = "qing_craft_laser_variant"
M.CRAFT_LASER_DAMAGE_KEY = "qing_craft_laser_damage"
M.CRAFT_LASER_LAST_POS_KEY = "qing_craft_laser_last_pos"
M.CRAFT_LASER_SAMPLE_PULL = {
	-- 近端「全量跟随」的点数（含 index 0）；之后按幂次衰减到末端
	near_full = 2,
	-- 末端保持不动的点数（至少 1）
	end_keep = 2,
	-- 中间段衰减指数：weight = (1 - u)^power，u 从近端区末端→末端保护区
	mid_power = 2,
}

function M.bind_craft_laser(laser, air, tear_flags, opts)
	if not laser then return end
	laser = laser.ToLaser and laser:ToLaser() or laser
	if not laser then return end
	opts = opts or {}
	local td = laser:GetData()
	if air and auxi.check_all_exists(air) then
		if laser.SpawnerEntity ~= nil then
			laser.SpawnerEntity = air
		end
		td[M.CRAFT_LASER_AIR_KEY] = air
	end
	if tear_flags ~= nil then
		td[M.CRAFT_LASER_FLAGS_KEY] = tear_flags
		M.write_entity_tear_flags(laser, tear_flags)
	elseif td[M.CRAFT_LASER_FLAGS_KEY] == nil and laser.TearFlags ~= nil then
		td[M.CRAFT_LASER_FLAGS_KEY] = laser.TearFlags
	end
	if opts.variant ~= nil then
		td[M.CRAFT_LASER_VARIANT_KEY] = opts.variant
		M.apply_laser_variant_skin(laser, opts.variant)
	end
	if opts.damage ~= nil and laser.CollisionDamage ~= nil then
		td[M.CRAFT_LASER_DAMAGE_KEY] = opts.damage
		laser.CollisionDamage = opts.damage
	end
	M.apply_laser_craft_motion(laser, td[M.CRAFT_LASER_FLAGS_KEY] or tear_flags or laser.TearFlags)
end

--- sample index → 父体位移权重：近端 1、末端 0、中间平滑衰减。
local function sample_pull_weight(index, count, cfg)
	if count <= 1 then return 0 end -- 单点视为末端，不拉（避免尖端跟着飞）
	cfg = cfg or M.CRAFT_LASER_SAMPLE_PULL
	local end_keep = math.max(1, math.floor(tonumber(cfg.end_keep) or 2))
	local near_full = math.max(1, math.floor(tonumber(cfg.near_full) or 2))
	local power = tonumber(cfg.mid_power) or 2
	if power < 1 then power = 1 end
	-- 点数少时压缩保护区，仍保证最后一个点 weight=0
	if count <= end_keep + 1 then
		if index >= count - 1 then return 0 end
		local u = index / math.max(1, count - 2)
		return (1 - u) ^ power
	end
	if index >= count - end_keep then
		return 0
	end
	if index < near_full then
		return 1
	end
	local mid_start = near_full
	local mid_end = count - end_keep - 1
	if mid_end <= mid_start then
		return 0
	end
	local u = (index - mid_start) / (mid_end - mid_start)
	if u < 0 then u = 0 elseif u > 1 then u = 1 end
	return (1 - u) ^ power
end

--- 按父体位移拉动 Homing sample 近端；末端不动；不重 init / 不乒乓 HomingType。
--- RGON 无 SetSamples；GetSamples 返回内部引用，改 .X/.Y 有效（已探针确认）。
--- 返回 true 表示至少写入一点且回读一致。
function M.shift_homing_laser_samples(laser)
	if not laser then return false end
	laser = laser.ToLaser and laser:ToLaser() or laser
	if not laser then return false end
	local td = laser:GetData()
	local pos = laser.Position
	if not pos then return false end
	local last = td[M.CRAFT_LASER_LAST_POS_KEY]
	td[M.CRAFT_LASER_LAST_POS_KEY] = Vector(pos.X, pos.Y)
	if not last then return false end
	local delta = pos - last
	if delta:LengthSquared() < 0.25 then return false end

	local cfg = M.CRAFT_LASER_SAMPLE_PULL
	local function shift_list(getter)
		if not getter then return false end
		local ok, samples = pcall(getter)
		if not ok or not samples or #samples < 1 then return false end
		local n = #samples
		local wrote = false
		for i = 0, n - 1 do
			local w = sample_pull_weight(i, n, cfg)
			if w > 1e-4 then
				local v = samples:Get(i)
				if v and v.X ~= nil then
					local nx = v.X + delta.X * w
					local ny = v.Y + delta.Y * w
					v.X = nx
					v.Y = ny
					local v2 = samples:Get(i)
					if v2 and math.abs((v2.X or 0) - nx) < 0.01 and math.abs((v2.Y or 0) - ny) < 0.01 then
						wrote = true
					end
				end
			end
		end
		return wrote
	end

	local a = shift_list(function() return laser:GetSamples() end)
	local b = false
	if laser.GetNonOptimizedSamples then
		b = shift_list(function() return laser:GetNonOptimizedSamples() end)
	end
	-- 末端不动：EndPoint 与最后 sample 对齐（勿 += delta）
	if laser.GetSamples then
		local ok, samples = pcall(function() return laser:GetSamples() end)
		if ok and samples and #samples > 0 and laser.EndPoint then
			local tip = samples:Get(#samples - 1)
			if tip then
				pcall(function() laser.EndPoint = Vector(tip.X, tip.Y) end)
			end
		end
	end
	td.qing_craft_sample_shift_ok = (a or b) == true
	return td.qing_craft_sample_shift_ok
end

--- POST_LASER_UPDATE 重申：Spawner 挂 Flight + TearFlags / CurveStrength / Variant / 伤害
function M.reassert_craft_laser(laser)
	if not laser then return false end
	laser = laser.ToLaser and laser:ToLaser() or laser
	if not laser then return false end
	local td = laser:GetData()
	local flags = td and td[M.CRAFT_LASER_FLAGS_KEY]
	local var = td and td[M.CRAFT_LASER_VARIANT_KEY]
	local dmg = td and td[M.CRAFT_LASER_DAMAGE_KEY]
	if flags == nil and var == nil and dmg == nil then return false end
	local air = td[M.CRAFT_LASER_AIR_KEY]
	if air and auxi.check_all_exists(air) and laser.SpawnerEntity ~= nil then
		laser.SpawnerEntity = air
	end
	if flags ~= nil then
		M.write_entity_tear_flags(laser, flags)
		M.apply_laser_craft_motion(laser, flags)
	end
	if var ~= nil then
		M.apply_laser_variant_skin(laser, var)
	end
	if dmg ~= nil and laser.CollisionDamage ~= nil then
		laser.CollisionDamage = dmg
	end
	return true
end

function M.apply_flag_mask(ent, profile)
	if not ent or not profile or not profile.flag_mask then return end
	if ent.TearFlags ~= nil then
		M.write_entity_tear_flags(ent, ent.TearFlags & profile.flag_mask)
	end
	M.apply_laser_craft_motion(ent, ent.TearFlags)
end

--- 兼容旧调用：已脱钩 GetTearHitParams；应每颗弹丸带 projectile_index / init_seed。
function M.sample_tear_flags(player, luck, profile, weapon_type, opts)
	opts = opts or {}
	if opts.craft_uid == nil and profile and profile.craft_uid then
		opts.craft_uid = profile.craft_uid
	end
	if opts.seed == nil and player and player.InitSeed then
		opts.seed = M.tear_flag_base_seed({
			shot_serial = opts.shot_serial,
			craft_uid = opts.craft_uid,
			projectile_index = opts.projectile_index,
			init_seed = opts.init_seed or (player.InitSeed % 1000003),
		})
	end
	return M.roll_tear_flags(luck, profile, opts)
end

--- opts: {damage_add=, damage_mul=} 单眼等额外伤
function M.apply_tear_stats(ent, profile, dmg_mul, tear_flags, opts)
	if not ent or not profile or not profile.stats then return end
	dmg_mul = dmg_mul or 1
	opts = opts or {}
	if ent.CollisionDamage ~= nil then
		local dmg = (profile.stats.damage + (opts.damage_add or 0)) * (opts.damage_mul or 1)
		ent.CollisionDamage = dmg * dmg_mul
	end
	if tear_flags ~= nil and ent.TearFlags ~= nil then
		M.write_entity_tear_flags(ent, tear_flags)
		M.apply_laser_craft_motion(ent, tear_flags)
	else
		M.apply_flag_mask(ent, profile)
	end
end

-- ---------- 制造命名：空行/空怖 + 附加型号 ----------
local ROMAN_VAL = {I = 1, V = 5, X = 10, L = 50, C = 100, D = 500, M = 1000}
local _hanzi_pinyin = nil
local NAME_STOP = {
	THE = true, OF = true, A = true, AN = true, AND = true, OR = true,
	TO = true, IN = true, ON = true, FOR = true, WITH = true, FROM = true,
	BY = true, AT = true, AS = true, IS = true,
}
local NAME_VOWEL = {A = true, E = true, I = true, O = true, U = true, Y = true}

local function split_utf8(str)
	local ret = {}
	local i = 1
	str = str or ""
	while i <= #str do
		local b = string.byte(str, i)
		local len = 1
		if b and b >= 240 then len = 4
		elseif b and b >= 224 then len = 3
		elseif b and b >= 192 then len = 2 end
		ret[#ret + 1] = string.sub(str, i, i + len - 1)
		i = i + len
	end
	return ret
end

local function ensure_hanzi_pinyin()
	if _hanzi_pinyin then return end
	_hanzi_pinyin = {}
	local ok, cih = pcall(require, "Qing_Remaster_scripts.others.Chinese_input_holder")
	if not ok or not cih or not cih.data then return end
	for syl, chars in pairs(cih.data) do
		for _, ch in ipairs(split_utf8(chars)) do
			if not _hanzi_pinyin[ch] then
				_hanzi_pinyin[ch] = syl
			end
		end
	end
end

local function name_to_latin(name)
	name = name or ""
	ensure_hanzi_pinyin()
	local parts = {}
	for _, ch in ipairs(split_utf8(name)) do
		local b = string.byte(ch, 1)
		if b and b < 128 then
			parts[#parts + 1] = ch
		else
			local py = _hanzi_pinyin and _hanzi_pinyin[ch]
			if py then parts[#parts + 1] = py end
		end
	end
	return table.concat(parts)
end

local function arabic_to_roman(n)
	n = math.floor(tonumber(n) or 0)
	if n <= 0 then return nil end
	if n > 3999 then n = ((n - 1) % 3999) + 1 end
	local vals = {1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1}
	local syms = {"M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"}
	local s = ""
	for i, v in ipairs(vals) do
		while n >= v do
			n = n - v
			s = s .. syms[i]
		end
	end
	return s ~= "" and s or nil
end

local function collectible_latin_name(id)
	id = tonumber(id) or id
	if not id or id == 0 then return "" end
	local col = Isaac.GetItemConfig():GetCollectible(id)
	if not col then return "" end
	return name_to_latin(col.Name or "")
end

-- 常用罗马数字（长到短）
local ROMAN_FIND = {
	"XXXIX", "XXXVIII", "XXXVII", "XXXVI", "XXXV", "XXXIV", "XXXIII", "XXXII", "XXXI", "XXX",
	"XXIX", "XXVIII", "XXVII", "XXVI", "XXV", "XXIV", "XXIII", "XXII", "XXI", "XX",
	"XIX", "XVIII", "XVII", "XVI", "XV", "XIV", "XIII", "XII", "XI", "X",
	"IX", "VIII", "VII", "VI", "IV", "V", "III", "II", "I",
	"XL", "L", "XC", "C", "CD", "D", "CM", "M",
}
local ROMAN_WORD = {}
for _, r in ipairs(ROMAN_FIND) do ROMAN_WORD[r] = true end

--- 在大写串中挑「最好」的罗马：更长优先；单字母仅词界匹配，且可被 min_len 排除以免抢占 II/CM 等
local function find_best_roman_in_upper(upper, opts)
	opts = opts or {}
	local min_len = tonumber(opts.min_len) or 1
	local best, best_len, best_pos = nil, 0, math.huge
	upper = upper or ""
	for _, r in ipairs(ROMAN_FIND) do
		if #r >= min_len then
			local pos = 1
			while true do
				local a, b = string.find(upper, r, pos, true)
				if not a then break end
				local ok = true
				if #r == 1 then
					local prev = a > 1 and string.sub(upper, a - 1, a - 1) or ""
					local nxt = b < #upper and string.sub(upper, b + 1, b + 1) or ""
					if prev:match("%a") or nxt:match("%a") then ok = false end
				end
				if ok and (#r > best_len or (#r == best_len and a < best_pos)) then
					best, best_len, best_pos = r, #r, a
				end
				pos = a + 1
			end
		end
	end
	return best
end

local function words_from_latin(latin)
	local upper = string.upper(latin or "")
	local words, digits = {}, {}
	for w in upper:gmatch("%a+") do
		if ROMAN_WORD[w] then
			words[#words + 1] = {roman = w}
		elseif NAME_STOP[w] then
			-- skip
		elseif #w == 1 and w == "S" then
			-- 所有格残留（Mom's → S）
		elseif #w >= 1 then
			words[#words + 1] = {text = w}
		end
	end
	for d in upper:gmatch("%d+") do
		digits[#digits + 1] = d
	end
	return words, digits, upper:gsub("[^%w]", "")
end

local function push_unique(bag, ch, max_same)
	max_same = max_same or 2
	local n = 0
	for i = 1, #bag do
		if bag[i] == ch then n = n + 1 end
	end
	if n < max_same then bag[#bag + 1] = ch end
end

local function take_from_pool(pool, count, used)
	used = used or {}
	local out = {}
	local i = 1
	while #out < count and i <= #pool do
		local ch = pool[i]
		if not used[ch] or used[ch] < 1 then
			out[#out + 1] = ch
			used[ch] = (used[ch] or 0) + 1
		elseif #pool - i < count - #out then
			out[#out + 1] = ch
			used[ch] = (used[ch] or 0) + 1
		end
		i = i + 1
	end
	i = 1
	while #out < count and #pool > 0 do
		out[#out + 1] = pool[((i - 1) % #pool) + 1]
		i = i + 1
		if i > #pool * 3 then break end
	end
	return table.concat(out), used
end

local function mark_roman_used(used, roman)
	used = used or {}
	for ch in (roman or ""):gmatch("%a") do
		used[ch] = (used[ch] or 0) + 1
	end
	return used
end

--- 从材料英文名组合附加型号，如 "MK NF 型"
--- 罗马：数字优先；再取最长匹配（≥2 可嵌在词内）；单字母 M/X…可整词采用，但单独作型号时会补字母，避免「OM M」
function M.build_model_code(ingredients)
	local initials, consonants, vowels, romans = {}, {}, {}, {}
	local digit_chunks = {}
	local joined_upper = {}
	local keys = {}
	for k, _ in pairs(ingredients or {}) do
		local idx = tonumber(k) or k
		if type(idx) == "number" then keys[#keys + 1] = idx end
	end
	table.sort(keys)
	if #keys == 0 then return nil end

	for _, idx in ipairs(keys) do
		local id = ingredients[idx] or ingredients[tostring(idx)]
		local latin = collectible_latin_name(id)
		local words, digs, compact = words_from_latin(latin)
		joined_upper[#joined_upper + 1] = compact or ""
		for _, d in ipairs(digs) do digit_chunks[#digit_chunks + 1] = d end
		for _, w in ipairs(words) do
			if w.roman then
				romans[#romans + 1] = w.roman
			elseif w.text then
				local t = w.text
				local first = string.sub(t, 1, 1)
				push_unique(initials, first, 2)
				for i = 2, #t do
					local ch = string.sub(t, i, i)
					if NAME_VOWEL[ch] then
						push_unique(vowels, ch, 2)
					else
						push_unique(consonants, ch, 2)
					end
				end
			end
		end
	end

	if #initials == 0 and #consonants == 0 and #vowels == 0
		and #romans == 0 and #digit_chunks == 0
	then
		return nil
	end

	local roman = nil
	if #digit_chunks > 0 then
		local num = tonumber(table.concat(digit_chunks))
		if num and num > 0 then roman = arabic_to_roman(num) end
	end
	-- 整词罗马：先要长度≥2（III/XIV…），避免单字母 M 抢占
	if not roman and #romans > 0 then
		table.sort(romans, function(a, b)
			if #a ~= #b then return #a > #b end
			return a < b
		end)
		for _, r in ipairs(romans) do
			if #r >= 2 then roman = r break end
		end
	end
	-- 子串同样只认 ≥2，MOM/KNIFE 内的 M、I 不会抢走 CM/II
	if not roman then
		roman = find_best_roman_in_upper(table.concat(joined_upper), {min_len = 2})
	end
	-- 再允许整词单字母罗马（M/X/V…）
	if not roman and #romans > 0 then
		for _, r in ipairs(romans) do
			if #r == 1 then roman = r break end
		end
	end
	if not roman then
		roman = find_best_roman_in_upper(table.concat(joined_upper), {min_len = 1})
	end

	local n_ing = #keys
	local want_prefix = math.max(2, math.min(5, math.max(#initials, 1 + n_ing)))
	local short_roman = roman ~= nil and #roman == 1
	local want_model = roman and (short_roman and 2 or 0)
		or math.max(2, math.min(3, 1 + math.floor(n_ing / 2)))

	local used = {}
	if roman and not short_roman then
		used = mark_roman_used(used, roman)
	elseif roman and short_roman then
		-- 单字母罗马可保留语义，但先占位；补字母后再统一 mark
		used[roman] = (used[roman] or 0) + 1
	end

	local prefix, used2 = take_from_pool(initials, want_prefix, used)
	used = used2
	if #prefix < want_prefix then
		local extra
		extra, used = take_from_pool(consonants, want_prefix - #prefix, used)
		prefix = prefix .. extra
	end
	if #prefix < want_prefix then
		local extra
		extra, used = take_from_pool(vowels, want_prefix - #prefix, used)
		prefix = prefix .. extra
	end
	if #prefix < 2 then
		local fill = consonants[1] or vowels[1] or initials[1] or "X"
		while #prefix < 2 do prefix = prefix .. fill end
	end
	if #prefix > 5 then prefix = string.sub(prefix, 1, 5) end

	if not roman then
		local model
		model, used = take_from_pool(consonants, want_model, used)
		if #model < want_model then
			local extra
			extra, used = take_from_pool(initials, want_model - #model, used)
			model = model .. extra
		end
		if #model < want_model then
			local extra
			extra, used = take_from_pool(vowels, want_model - #model, used)
			model = model .. extra
		end
		while #model < 2 do model = model .. "X" end
		if #model > 3 then model = string.sub(model, 1, 3) end
		roman = model
	elseif short_roman then
		-- 「M」可接受为罗马，但单独作型号太干：补 1–2 个未占用字母 → 如 M + NF
		local pad
		pad, used = take_from_pool(consonants, want_model, used)
		if #pad < want_model then
			local extra
			extra, used = take_from_pool(initials, want_model - #pad, used)
			pad = pad .. extra
		end
		if #pad < 1 then
			local extra
			extra, used = take_from_pool(vowels, 1, used)
			pad = pad .. extra
		end
		if #pad < 1 then pad = "X" end
		roman = roman .. pad
		if #roman > 3 then roman = string.sub(roman, 1, 3) end
	end

	return prefix .. " " .. roman .. " 型"
end

function M.build_display_name(target, serial, ingredients, zh)
	zh = zh ~= false
	local base_info = M.TARGET_BASE[target]
	local serial_s = string.format("%02d", math.max(1, math.floor(tonumber(serial) or 1)))
	local head
	if base_info then
		head = (zh and base_info.zh or base_info.en) .. serial_s .. (zh and "号" or "")
	else
		head = "#" .. serial_s
	end
	local model = M.build_model_code(ingredients)
	if model and model ~= "" then
		return head .. "·" .. model
	end
	return head
end

function M.apply_fetus_sec_flags(ent, profile)
	if not ent or not profile or not profile.counts then return end
	for id, flg in pairs(M.FETUS_SEC_FLAGS) do
		if (profile.counts[id] or 0) > 0 then
			ent.TearFlags = ent.TearFlags | flg
		end
	end
end

-- ---------- §15 小攻击方式：巧克力奶 / 诅咒之眼 / 血泪症 ----------

function M.charge_ratio_max(profile)
	local ex = profile and profile.extras or {}
	if ex.cursed_eye then return 3 end
	if ex.chocolate then return 2 end
	return 1
end

function M.clamp_charge_ratio(r, max_ratio)
	r = tonumber(r)
	if r == nil then return 1 end
	if r < 0.25 then return 0.25 end
	max_ratio = math.max(1, math.min(3, tonumber(max_ratio) or 3))
	if r > max_ratio then return max_ratio end
	return r
end

function M.snap_charge_ratio(r, max_ratio, enabled)
	r = M.clamp_charge_ratio(r, max_ratio)
	if enabled and r > 1 then
		-- 只在档位附近磁吸；巧克力 100%..200% 的其余区间必须保持连续可调。
		for mark = 1.5, max_ratio, 0.5 do
			if math.abs(r - mark) <= 0.05 then r = mark break end
		end
	end
	return M.clamp_charge_ratio(r, max_ratio)
end

--- 兼容旧名
function M.clamp_chocolate_ratio(r)
	return M.clamp_charge_ratio(r)
end

--- Rep+ 巧克力：200%=完整蓄力；伤害按蓄力帧连续增长，最高 400%。
function M.chocolate_modifiers(ratio, base_delay)
	local r = M.clamp_charge_ratio(ratio, 2)
	base_delay = math.max(-0.75, tonumber(base_delay) or 10)
	local tears = 30 / (base_delay + 1)
	if tears >= 30 then
		local damage_mul = tears / 75 * 4
		return {
			ratio = r, damage_mul = damage_mul, size_mul = damage_mul ^ 0.5,
			charge_frames = 2, delay_override = 1, continuous = true,
		}
	end
	local charge_frac = r / 2
	local max_frames = math.max(2, math.floor(75 / tears))
	local charge_frames = math.max(2, math.floor(max_frames * charge_frac + 0.5))
	local damage_mul = math.min(4, charge_frames * tears / 75 * 4)
	return {
		ratio = r,
		damage_mul = damage_mul,
		size_mul = damage_mul ^ 0.5,
		charge_frames = charge_frames,
		delay_override = math.max(1, charge_frames - 1),
	}
end

--- Tech X 蓄力：最低 25%；比例同时控制环尺寸、伤害与下一次攻击前的蓄力时间。
function M.techx_charge_modifiers(ratio)
	local r = math.min(1, M.clamp_charge_ratio(ratio, 3))
	return {
		ratio = r,
		-- 原版/本模组新蓄力口径：半径从 20+40r 变化；调用侧以满蓄力 60 为基准。
		radius_mul = (20 + 40 * r) / 60,
		damage_mul = r,
		delay_mul = r,
	}
end

--- 把 per-craft 设置合并进 profile（巧克力 / Tech X 蓄力）
function M.apply_craft_settings(profile, settings)
	if not profile then return profile end
	settings = settings or {}
	local ex = profile.extras or {}
	local legacy = settings.chocolate_charge_ratio or settings.techx_charge_ratio
	local raw = settings.main_charge_ratio or profile.main_charge_ratio or legacy or 1
	profile.main_charge_ratio = M.clamp_charge_ratio(raw, M.charge_ratio_max(profile))
	profile.chocolate_charge_ratio = ex.chocolate and math.min(2, profile.main_charge_ratio) or nil
	if (profile.weapon or 1) == 9 then
		profile.techx_charge_ratio = math.min(1, profile.main_charge_ratio)
	else
		profile.techx_charge_ratio = nil
	end
	return profile
end

--- 一次攻击开始时生成不可变倍率
function M.attack_modifiers_from_profile(profile)
	local mods = {
		chocolate = false,
		techx = false,
		ratio = 1,
		damage_mul = 1,
		size_mul = 1,
		delay_override = nil,
		charge_ratio = 1,
		cursed_replays = 0,
		techx_ratio = 1,
		techx_radius_mul = 1,
		techx_damage_mul = 1,
		techx_delay_mul = 1,
	}
	if not profile then return mods end
	mods.charge_ratio = M.clamp_charge_ratio(profile.main_charge_ratio, M.charge_ratio_max(profile))
	if profile.extras and profile.extras.cursed_eye then
		mods.cursed_replays = math.max(0, math.min(4, math.floor((mods.charge_ratio - 1) / 0.5 + 0.0001)))
	end
	if profile.extras and profile.extras.chocolate then
		local c = M.chocolate_modifiers(profile.chocolate_charge_ratio, profile.stats and profile.stats.firedelay)
		mods.chocolate = true
		mods.ratio = c.ratio
		mods.damage_mul = c.damage_mul
		mods.size_mul = c.size_mul
		mods.delay_override = c.delay_override
		mods.charge_frames = c.charge_frames
	end
	if (profile.weapon or 1) == 9 then
		local t = M.techx_charge_modifiers(profile.techx_charge_ratio)
		mods.techx = true
		mods.techx_ratio = t.ratio
		mods.techx_radius_mul = t.radius_mul
		mods.techx_damage_mul = t.damage_mul
		mods.techx_delay_mul = t.delay_mul
	end
	return mods
end

function M.attack_delay_from_modifiers(base_delay, mods)
	base_delay = math.max(1, tonumber(base_delay) or 10)
	mods = mods or {}
	if mods.delay_override ~= nil then return math.max(1, mods.delay_override) end
	return math.max(1, base_delay * (mods.techx_delay_mul or 1))
end

--- Fruit Cake 可随机的主武器（排除卢多占位 8、无开火分支 11/12）
M.SUPPORTED_RANDOM_WEAPONS = {1, 2, 3, 4, 5, 6, 7, 9, 10, 13, 14}

function M.pick_fruit_cake_weapon(rng)
	local pool = M.SUPPORTED_RANDOM_WEAPONS
	local i
	if rng and rng.RandomInt then
		i = rng:RandomInt(#pool) + 1
	else
		i = math.random(#pool)
	end
	return pool[i] or 1
end

--- 统一弹道方向：多发 + 套装 + 妈眼 + 洛基角（包装 volley_dirs）
function M.build_volley_directions(profile, aim_dir, opts)
	return M.volley_dirs(aim_dir, profile, opts)
end

--- 妈眼/洛基角独立判定；供离散齐射和 Ludo epoch 共用。
function M.roll_directional_extras(profile, luck, seed)
	local counts = profile and profile.counts or {}
	luck = tonumber(luck) or 0
	local function hit(id, chance, salt)
		if M.count_of(counts, id) <= 0 or chance <= 0 then return false end
		if chance >= 1 then return true end
		return M.derived_rng(seed, salt):RandomFloat() < chance
	end
	return hit(55, M.moms_eye_chance(luck), 55087),
		hit(87, M.lokis_horns_chance(luck), 55097)
end

--- 一次攻击上下文：伤害/冷却/弹速/射程/尺寸/诅咒眼重放
--- opts: {eye_bonus=, atk_mods=, aux_mul=, dead_eye_mul=, weapon=}
function M.build_attack_context(profile, opts)
	opts = opts or {}
	local mods = opts.atk_mods or M.attack_modifiers_from_profile(profile)
	local eye = opts.eye_bonus or {damage = 0, range = 0, shotspeed = 0, damage_mul = 1, blood_variant = false}
	local aux_mul = tonumber(opts.aux_mul) or 1
	local dead_eye_mul = tonumber(opts.dead_eye_mul) or 1
	local st = (profile and profile.stats) or {}
	local base_dmg = (tonumber(st.damage) or 3.5) + (tonumber(eye.damage) or 0)
	base_dmg = base_dmg * (tonumber(eye.damage_mul) or 1)
	local damage = base_dmg * (mods.damage_mul or 1) * aux_mul * dead_eye_mul
	local weapon = opts.weapon or (profile and profile.weapon) or 1
	local base_delay = M.craft_fire_delay(profile, weapon)
	local delay = M.attack_delay_from_modifiers(base_delay, mods)
	local shotspeed = (tonumber(st.shotspeed) or 1) + (tonumber(eye.shotspeed) or 0)
	local range = (tonumber(st.range) or 260) + (tonumber(eye.range) or 0)
	return {
		profile = profile,
		mods = mods,
		eye = eye,
		aux_mul = aux_mul,
		dead_eye_mul = dead_eye_mul,
		weapon = weapon,
		damage = damage,
		base_damage = base_dmg,
		delay = delay,
		shotspeed = shotspeed,
		range = range,
		scale = M.projectile_scale(profile, mods),
		luck = tonumber(st.luck) or 0,
		cursed_replays = tonumber(mods.cursed_replays) or 0,
		blood_variant = eye.blood_variant == true,
	}
end

--- 硫磺 synergy 伤害倍率（相对已 stamp 的 CollisionDamage；不回写基础伤）
function M.brimstone_synergy_mul(profile)
	local syn = profile and profile.synergy
	if not syn then return 1 end
	if syn.brim_tech then
		return 1.5 * (syn.thick_brim and 1.5 or 1)
	end
	if syn.thick_brim then return 1.5 end
	return 1
end

--- 按配方 synergy 选硫磺激光 Variant（禁止沿用玩家 FireBrimstone 的 Brim+Tech 等外观）。
--- 单份→THICK_RED；双份→THICKER_RED；+科技→BRIM_TECH / THICKER_BRIM_TECH。
function M.craft_brimstone_variant(profile)
	local syn = (profile and profile.synergy) or {}
	if syn.brim_tech then
		if syn.thick_brim and LaserVariant and LaserVariant.THICKER_BRIM_TECH then
			return LaserVariant.THICKER_BRIM_TECH
		end
		return (LaserVariant and LaserVariant.BRIM_TECH) or 9
	end
	if syn.thick_brim then
		return (LaserVariant and LaserVariant.THICKER_RED) or 11
	end
	return (LaserVariant and LaserVariant.THICK_RED) or 1
end

--- 激光 Variant → 原版 anm2（事后改 Variant 不换皮，须 Load）。
local LASER_VARIANT_ANM2 = {
	[1] = "gfx/007.001_thick red laser.anm2",
	[2] = "gfx/007.002_thin red laser.anm2",
	[3] = "gfx/007.003_shoop laser.anm2",
	[6] = "gfx/007.006_giant red laser.anm2",
	[9] = "gfx/007.009_brimtech.anm2",
	[11] = "gfx/007.011_thicker red laser.anm2",
	[14] = "gfx/007.014_thicker red laser tech.anm2",
	[15] = "gfx/007.015_giant red laser tech.anm2",
}

--- FireBrimstone 后按配方换皮：写 Variant + Load 对应 anm2。保留 Fire* 的「玩家发射硫磺」兼容链。
function M.apply_laser_variant_skin(laser, variant)
	if not laser or variant == nil then return false end
	laser = laser.ToLaser and laser:ToLaser() or laser
	if not laser then return false end
	local path = LASER_VARIANT_ANM2[variant]
	laser.Variant = variant
	if not path then return false end
	local s = laser.GetSprite and laser:GetSprite()
	if not s or not s.Load then return false end
	-- 已是目标皮则跳过（reassert 每帧调用）
	local cur = s.GetFilename and s:GetFilename()
	if cur and cur:lower() == path:lower() then
		return true
	end
	s:Load(path, true)
	if s.Play then
		s:Play("LargeRedLaser", true)
	end
	return true
end

--- 用 FireBrimstone 生成（保留玩家硫磺兼容），再按配方换皮。勿用 ShootAngle 当主路径。
--- opts: {profile, air, player, dir, position, position_offset, timeout, damage_mul}
--- 返回 laser, variant
function M.spawn_craft_brimstone(opts)
	opts = opts or {}
	local profile = opts.profile
	local air = opts.air
	local player = opts.player
	if not player or not player.FireBrimstone then return nil, M.craft_brimstone_variant(profile) end
	local dir = opts.dir or Vector(1, 0)
	if dir:Length() < 0.01 then
		dir = Vector(1, 0)
	else
		dir = dir:Normalized()
	end
	local var = M.craft_brimstone_variant(profile)
	local pos = opts.position
	if not pos and air then pos = air.Position end
	if not pos then pos = player.Position end
	local po = opts.position_offset or Vector(0, 0)
	local timeout = opts.timeout
	if timeout == nil then timeout = 30 end
	local dmg_mul = opts.damage_mul
	if dmg_mul == nil then dmg_mul = 1 end
	local source = air or player
	local laser = player:FireBrimstone(dir, source, dmg_mul)
	if not laser then return nil, var end
	laser = laser:ToLaser() or laser
	laser.Parent = air or laser.Parent
	laser.Position = pos
	if laser.PositionOffset ~= nil then
		laser.PositionOffset = po
	end
	if laser.ParentOffset ~= nil then
		laser.ParentOffset = Vector(0, 0)
	end
	if air and laser.SpawnerEntity ~= nil then
		laser.SpawnerEntity = air
	end
	if air then
		if laser.SetDisableFollowParent then
			laser:SetDisableFollowParent(false)
		elseif laser.DisableFollowParent ~= nil then
			laser.DisableFollowParent = false
		end
	end
	M.apply_laser_variant_skin(laser, var)
	if laser.SetTimeout and timeout then
		laser:SetTimeout(timeout)
	end
	return laser, var
end

function M.decorate_brimstone(laser, profile, ent, player, dir, fire_pos)
	if not laser or not profile then return end
	local syn = profile.synergy or {}
	local var = M.craft_brimstone_variant(profile)
	M.apply_laser_variant_skin(laser, var)
	local mul = M.brimstone_synergy_mul(profile)
	if mul ~= 1 and laser.CollisionDamage ~= nil then
		laser.CollisionDamage = laser.CollisionDamage * mul
	end
	M.apply_flag_mask(laser, profile)
	local td = laser:GetData()
	td.qing_craft_brim_tech = syn.brim_tech == true
	td.qing_craft_thick_brim = syn.thick_brim == true
	td.qing_craft_syn_mul = mul
	local bind_opts = {
		variant = var,
		damage = laser.CollisionDamage,
	}
	if ent then
		M.bind_craft_laser(laser, ent, laser.TearFlags, bind_opts)
	else
		td[M.CRAFT_LASER_VARIANT_KEY] = var
		if laser.CollisionDamage ~= nil then
			td[M.CRAFT_LASER_DAMAGE_KEY] = laser.CollisionDamage
		end
	end
end

--- 配方弹体尺寸 × 巧克力尺寸倍率（博士炸弹 / 泪弹共用）
function M.projectile_scale(profile, atk_mods)
	local base = 1
	if profile and profile.stats and profile.stats.scale then
		base = tonumber(profile.stats.scale) or 1
	end
	local choco = 1
	if atk_mods and atk_mods.size_mul then
		choco = tonumber(atk_mods.size_mul) or 1
	end
	return math.max(0.12, base * choco)
end

function M.apply_bomb_scale(bomb, scale)
	if not bomb or not scale then return end
	scale = math.max(0.12, tonumber(scale) or 1)
	if bomb.SetScale then
		bomb:SetScale(scale)
		if bomb.SetLoadCostumes then bomb:SetLoadCostumes(true) end
	end
	if bomb.SpriteScale ~= nil then
		bomb.SpriteScale = Vector(scale, scale)
	end
	local spr = bomb.GetSprite and bomb:GetSprite()
	if spr and spr.Scale then
		spr.Scale = Vector(scale, scale)
	end
	if bomb.RadiusMultiplier ~= nil then
		bomb.RadiusMultiplier = scale
	end
end

--- 泪弹设绝对 Scale；炸弹走 SetScale；激光半径由发射点自行乘
function M.apply_projectile_scale(ent, scale)
	if not ent or not scale then return end
	scale = math.max(0.12, tonumber(scale) or 1)
	if ent.ToBomb and ent:ToBomb() then
		M.apply_bomb_scale(ent:ToBomb(), scale)
		return
	end
	if ent.ToLaser and ent:ToLaser() then
		return
	end
	if ent.Scale ~= nil then
		ent.Scale = scale
	elseif ent.SpriteScale ~= nil then
		ent.SpriteScale = Vector(scale, scale)
	end
end

function M.apply_size_mul(ent, size_mul)
	if not ent or not size_mul or size_mul == 1 then return end
	if ent.Scale ~= nil then ent.Scale = ent.Scale * size_mul end
	if ent.SpriteScale ~= nil then
		ent.SpriteScale = Vector(ent.SpriteScale.X * size_mul, ent.SpriteScale.Y * size_mul)
	end
	if ent.Radius ~= nil then ent.Radius = ent.Radius * size_mul end
end

function M.profile_has_haemolacria(profile)
	if not profile then return false end
	if profile.extras and profile.extras.haemolacria then return true end
	return profile.list and (profile.list.hae or 0) > 0
end

function M.haemo_burst_mode(profile)
	if not profile then return "tears" end
	local syn = profile.synergy or {}
	local ex = profile.extras or {}
	local mode = syn.haemo_burst_mode or ex.haemo_burst_mode or "tears"
	-- 旧档案 mixed / 多 guest：落地一次 shared，不再拆成多发主气球
	if mode == "mixed" or mode == "multi" then
		return "shared"
	end
	return mode
end

--- 妈刀是否已作为血泪均分 guest（不再在 tears/brim burst 里二次分摊刀）
function M.haemo_knife_is_share_guest(profile)
	if not profile then return false end
	local syn = profile.synergy or {}
	local ex = profile.extras or {}
	local guests = syn.haemo_share_guests or ex.haemo_share_guests or {}
	for _, g in ipairs(guests) do
		if g == 4 then return true end
	end
	return false
end

--- 掷某一 mode 的自然产量（自身倍率区间）
function M.haemo_roll_mode_count(mode)
	local r = M.HAEMO_MODE_BASE_COUNT[mode or "tears"] or M.HAEMO_MODE_BASE_COUNT.tears
	local lo, hi = r[1] or 6, r[2] or 11
	if hi < lo then lo, hi = hi, lo end
	return math.random(lo, hi)
end

--- 多 mode 并存：面额均分 × 总加成 → 该 mode 实际发数
--- count = max(1, round(base * (1+0.2*(n-1)) / n))
function M.haemo_scale_mode_count(base_count, n_modes)
	base_count = math.max(1, math.floor(tonumber(base_count) or 1))
	n_modes = math.max(1, math.floor(tonumber(n_modes) or 1))
	if n_modes <= 1 then return base_count end
	local mul = 1 + (tonumber(M.HAEMO_SHARE_BONUS) or 0.2) * (n_modes - 1)
	return math.max(1, math.floor(base_count * mul / n_modes + 0.5))
end

--- 侧车爆发（卢多等）可参与的 mode 列表：配方里出现的可分摊 guest；皆无则 tears
function M.haemo_burst_guest_modes(profile)
	local list = profile and profile.list or {}
	local modes = {}
	local function add(cond, mode)
		if cond and mode then modes[#modes + 1] = mode end
	end
	add((list.brimstone or 0) > 0, "brim")
	add((list.tech or 0) > 0, "tech")
	add((list.techX or 0) > 0, "techx")
	add((list.dr or 0) > 0, "bombs")
	add((list.knife or 0) > 0, "knife")
	if #modes == 0 then
		modes[1] = "tears"
	end
	return modes
end

--- 给制造主血泪挂上自模拟 burst 标记（禁止依赖 TEAR_BURSTSPLIT）
function M.clear_craft_haemo_burst_flag(tear)
	if not tear or not TearFlags or not TearFlags.TEAR_BURSTSPLIT then return end
	if tear.ClearTearFlags then
		tear:ClearTearFlags(TearFlags.TEAR_BURSTSPLIT)
	end
	if tear.TearFlags ~= nil then
		tear.TearFlags = tear.TearFlags & ~TearFlags.TEAR_BURSTSPLIT
	end
end

function M.mark_craft_haemo_tear(tear, profile, player, context)
	if not tear or not M.profile_has_haemolacria(profile) then return end
	local d = tear:GetData()
	if d.craft_haemo_child or d.craft_no_haemo then return end
	context = context or {}
	local mode = context.mode or M.haemo_burst_mode(profile)
	d.craft_haemo = {
		profile = profile,
		player = player,
		mods = context.mods,
		dir = context.dir,
		damage = context.damage,
		mode = mode,
	}
	-- 必须清掉引擎/玩家继承的 BURSTSPLIT，否则落地会再喷一波原版小血泪
	M.clear_craft_haemo_burst_flag(tear)
end

--- 主血泪终结时触发（ENTITY_REMOVE / 碰撞兜底）；子泪与已触发跳过
--- opts.force：允许卢多概率路径显式触发（默认忽略带 ludo_proc 的标记，避免控泪移除时误爆）
function M.try_trigger_craft_haemo_tear(tear, opts)
	if not tear then return false end
	local d = tear:GetData()
	if not d or not d.craft_haemo or d.craft_haemo_done or d.craft_haemo_child or d.craft_no_haemo then
		return false
	end
	local ch = d.craft_haemo
	if ch.ludo_proc and not (opts and opts.force) then
		return false
	end
	-- 触发前再清一次，避免碰撞帧原版仍读到 BURSTSPLIT
	M.clear_craft_haemo_burst_flag(tear)
	d.craft_haemo_done = true
	local profile = ch.profile
	local player = ch.player
	local dir = ch.dir
	if (not dir or dir:Length() < 0.01) and tear.Velocity then
		dir = tear.Velocity
	end
	local mode = ch.mode or M.haemo_burst_mode(profile)
	M.spawn_craft_haemolacria_burst(profile, tear.Position, dir, tear, {
		player = player,
		damage_mul = nil,
		parent_damage = ch.damage or tear.CollisionDamage,
		size_mul = tear.Scale,
		mods = ch.mods,
		mode = mode,
	})
	return true
end

--- 卢多控泪有效伤害 tick：低概率血泪爆发（伤害继承攻击实体 CollisionDamage）
function M.try_ludo_haemo_burst(attack, target, profile, player, context)
	if not attack or not target or not M.profile_has_haemolacria(profile) then return false end
	local ex = profile.extras or {}
	if not ex.haemo_ludo_proc and not (ex.haemolacria and (profile.weapon or 1) == 8) then
		return false
	end
	context = context or {}
	local luck = tonumber(context.luck) or tonumber(profile.stats and profile.stats.luck) or 0
	local chance = tonumber(M.HAEMO_LUDO_BURST_CHANCE) or 0.12
	chance = math.min(0.35, math.max(0.02, chance + luck * 0.01))
	local seed = (attack.InitSeed or 0)
		+ (target.InitSeed or 0)
		+ (Game():GetFrameCount() or 0) * 17
		+ (tonumber(context.shot_serial) or 0) * 131
	local rng = M.derived_rng(seed, 531 * 65537 + (tonumber(context.projectile_index) or 1))
	if rng:RandomFloat() >= chance then return false end
	local dir = context.dir
	if (not dir or dir:Length() < 0.01) and attack.Velocity then
		dir = attack.Velocity
	end
	if not dir or dir:Length() < 0.01 then dir = Vector(1, 0) end
	local dmg = tonumber(context.parent_damage)
	if not dmg or dmg <= 0 then
		dmg = tonumber(attack.CollisionDamage)
	end
	if (not dmg or dmg <= 0) and profile.stats then
		dmg = tonumber(profile.stats.damage) or 3.5
	end
	M.spawn_craft_haemolacria_burst(profile, target.Position, dir, attack, {
		player = player,
		parent_damage = dmg,
		size_mul = context.size_mul or attack.Scale or 1,
		mods = context.mods,
		-- 侧车：各 guest 均分面额后套自身倍率（含妈刀 3–6 全向）
		mode = "shared",
	})
	return true
end

--- 卢多泪血泪染色（Colorize；Tint 保持白）
function M.apply_haemo_ludo_color(tear)
	if not tear or not tear.SetColor then return end
	local c = Color(1, 1, 1, 1, 0, 0, 0)
	if c.SetColorize then
		c:SetColorize(0.9, 0.12, 0.12, 1)
	end
	tear:SetColor(c, -1, 1, false, false)
end

local function haemo_child_flags(profile, context)
	local flags = context.tear_flags
	if flags == nil then flags = profile.flag_mask or BitSet128(0, 0) end
	if TearFlags and TearFlags.TEAR_BURSTSPLIT then
		flags = flags & ~TearFlags.TEAR_BURSTSPLIT
	end
	return flags
end

--- 爆裂子弹分摊：妈刀 / 剑泪 与眼泪并列成独立 mode，各掷自身区间再按 mode 数均分面额
--- 若妈刀已是主泪均分 guest，则 tears burst 不再带刀
local function haemo_child_mode_plan(profile)
	local list = profile and profile.list or {}
	local modes = {"tears"}
	local knife_share = M.haemo_knife_is_share_guest(profile)
	if (list.knife or 0) > 0 and not knife_share then
		modes[#modes + 1] = "knife"
	end
	if (list.sword or 0) > 0 then
		modes[#modes + 1] = "sword"
	end
	local n = #modes
	local plan = {}
	for _, mode in ipairs(modes) do
		local base = M.haemo_roll_mode_count(mode)
		plan[#plan + 1] = {
			mode = mode,
			count = M.haemo_scale_mode_count(base, n),
		}
	end
	return plan
end

local function spawn_haemo_knife_child(profile, position, direction, player, context, damage, opts)
	opts = opts or {}
	local shot
	if opts.full_spread then
		shot = auxi.MakeVector(math.random() * 360)
	else
		local dir = direction
		if not dir or dir:Length() < 0.01 then dir = Vector(1, 0) end
		dir = dir:Normalized()
		local ang = (math.random(1200) / 10) - 60
		shot = auxi.get_by_rotate(dir, ang)
	end
	local flags = haemo_child_flags(profile, context)
	local params = {
		cooldown = 40,
		Accerate = 0.85,
		player = player,
		tearflags = flags,
		hold_knife_path = true,
		PosOffset = Vector(0, -8),
	}
	local q = auxi.fire_knife(position, shot, damage, nil, params)
	if q then
		q:Shoot(1, 40 + math.random(30))
		local qd = q:GetData()
		qd.craft_haemo_child = true
		qd.craft_no_haemo = true
		if q.Parent and q.Parent.GetData then
			local pd = q.Parent:GetData()
			pd.craft_haemo_child = true
			pd.craft_no_haemo = true
		end
	end
	return q
end

local function spawn_haemo_sword_tear_child(profile, position, direction, player, context, damage, size_mul)
	local dir = direction
	if not dir or dir:Length() < 0.01 then dir = Vector(1, 0) end
	dir = dir:Normalized()
	local stats = profile.stats or M.BASE_STATS
	local shotspeed = tonumber(stats.shotspeed) or 1
	local ang = (math.random(1200) / 10) - 60
	local spd = 3 + (math.random(1000) / 1000) * (shotspeed * 10)
	local vel = auxi.get_by_rotate(dir, ang) * spd
	local q = player:FireTear(position, vel, false, true, false)
	if not q then return nil end
	local want = TearVariant.SWORD_BEAM or 47
	if q.ChangeVariant and q.Variant ~= want then
		q:ChangeVariant(want)
		if q.ResetSpriteScale then q:ResetSpriteScale() end
	end
	q.CollisionDamage = damage
	q.TearFlags = haemo_child_flags(profile, context)
	if q.ClearTearFlags and TearFlags and TearFlags.TEAR_BURSTSPLIT then
		q:ClearTearFlags(TearFlags.TEAR_BURSTSPLIT)
	end
	q.Scale = (0.7 + (math.random(250) / 1000)) * math.max(0.35, (size_mul or 1) * 0.7)
	q.FallingAcceleration = 0.8
	q.FallingSpeed = -8.9 + auxi.random_2() * 2
	local qd = q:GetData()
	qd.craft_haemo_child = true
	qd.craft_no_haemo = true
	return q
end

local function spawn_haemo_tear_children(profile, position, direction, player, context, forced_count)
	local stats = profile.stats or M.BASE_STATS
	local parent_dmg = tonumber(context.parent_damage)
	local size_mul = context.size_mul or 1
	local tear_count = tonumber(forced_count)
	if not tear_count then
		-- 仅眼泪，或与刀/剑并列时由 plan 拆开；此处只发眼泪份
		local plan = haemo_child_mode_plan(profile)
		local knife_n, sword_n = 0, 0
		for _, p in ipairs(plan) do
			if p.mode == "tears" then tear_count = p.count end
			if p.mode == "knife" then knife_n = p.count end
			if p.mode == "sword" then sword_n = p.count end
		end
		tear_count = tear_count or M.haemo_roll_mode_count("tears")
		-- 刀/剑在本函数末尾按自身份发射（全向刀）
		context._haemo_plan_knife = knife_n
		context._haemo_plan_sword = sword_n
	end
	local dir = direction
	if not dir or dir:Length() < 0.01 then dir = Vector(1, 0) end
	dir = dir:Normalized()
	local flags = haemo_child_flags(profile, context)
	local shotspeed = tonumber(stats.shotspeed) or 1
	local mods = context.mods or {}
	local dmg_mul = tonumber(mods.damage_mul) or 1
	local stats_dmg = (tonumber(stats.damage) or 3.5) * (tonumber(context.damage_mul) or 0.66) * dmg_mul

	local function child_dmg()
		if parent_dmg and parent_dmg > 0 then
			return parent_dmg * (0.5 + math.random() * (1 / 3))
		end
		return stats_dmg
	end

	for _ = 1, tear_count or 0 do
		local ang = (math.random(1200) / 10) - 60
		local spd = 3 + (math.random(1000) / 1000) * (shotspeed * 10)
		local vel = auxi.get_by_rotate(dir, ang) * spd
		local q = player:FireTear(position, vel, false, true, false)
		if q then
			if q.ChangeVariant then q:ChangeVariant(TearVariant.BLOOD) end
			q.CollisionDamage = child_dmg()
			q.TearFlags = flags
			if q.ClearTearFlags and TearFlags and TearFlags.TEAR_BURSTSPLIT then
				q:ClearTearFlags(TearFlags.TEAR_BURSTSPLIT)
			end
			q.Scale = (0.55 + (math.random(350) / 1000)) * math.max(0.35, size_mul * 0.55)
			local qd = q:GetData()
			qd.craft_haemo_child = true
			qd.craft_no_haemo = true
		end
	end
	local knife_n = tonumber(context._haemo_plan_knife) or 0
	local sword_n = tonumber(context._haemo_plan_sword) or 0
	context._haemo_plan_knife = nil
	context._haemo_plan_sword = nil
	for _ = 1, knife_n do
		spawn_haemo_knife_child(profile, position, dir, player, context, child_dmg(), {full_spread = true})
	end
	for _ = 1, sword_n do
		spawn_haemo_sword_tear_child(profile, position, dir, player, context, child_dmg(), size_mul)
	end
end

local function spawn_haemo_brim_burst(profile, position, direction, player, context, forced_count)
	local parent_dmg = tonumber(context.parent_damage) or ((profile.stats and profile.stats.damage) or 3.5)
	local count = tonumber(forced_count) or M.haemo_roll_mode_count("brim")
	local syn = profile.synergy or {}
	local air = context.source
	for _ = 1, count do
		-- 真随机方向（非均分圆）；按配方 Variant 生成，避免继承玩家科技硫磺外观
		local shot = auxi.MakeVector(math.random() * 360)
		local q = M.spawn_craft_brimstone({
			profile = profile,
			air = (air and air.ToFamiliar and air:ToFamiliar()) and air or nil,
			player = player,
			dir = shot,
			position = position,
			position_offset = Vector(0, 0),
			timeout = 9,
		})
		if q then
			q.Parent = air or player
			q.CollisionDamage = parent_dmg
			if syn.thick_brim and q.SpriteScale then
				q.SpriteScale = Vector(1.35, 1.35)
			end
			-- 始终 decorate：强制 Variant + brim_tech/双硫磺加伤；无 synergy 时 mul=1
			M.decorate_brimstone(q, profile, air, player, shot, position)
			if q.SetTimeout then q:SetTimeout(9) end -- 探针：Timeout=9
			local qd = q:GetData()
			qd.craft_haemo_child = true
			qd.craft_no_haemo = true
		end
	end
end

local function spawn_haemo_tech_burst(profile, position, direction, player, context, forced_count)
	local parent_dmg = tonumber(context.parent_damage) or ((profile.stats and profile.stats.damage) or 3.5)
	local count = tonumber(forced_count) or M.haemo_roll_mode_count("tech")
	for _ = 1, count do
		local shot = auxi.MakeVector(math.random() * 360)
		local q = player:FireTechLaser(position, 0, shot, false, true)
		if q then
			q.CollisionDamage = parent_dmg
			M.apply_flag_mask(q, profile)
			if q.SetTimeout then q:SetTimeout(2) end -- 探针：Timeout=2
			local qd = q:GetData()
			qd.craft_haemo_child = true
			qd.craft_no_haemo = true
		end
	end
end

local function spawn_haemo_techx_burst(profile, position, direction, player, context, forced_count)
	local parent_dmg = tonumber(context.parent_damage) or ((profile.stats and profile.stats.damage) or 3.5)
	local count = tonumber(forced_count) or M.haemo_roll_mode_count("techx")
	local mods = context.mods or {}
	local base_r = 40 * (tonumber(mods.techx_radius_mul) or 1)
	for _ = 1, count do
		local rad = base_r * (0.55 + math.random() * 0.9) -- 探针约 22..80
		local vel = auxi.MakeVector(math.random() * 360) * (0.8 + math.random() * 1.4)
		local q = player:FireTechXLaser(position, vel, rad, player, 1)
		if q then
			q.CollisionDamage = parent_dmg
			M.apply_flag_mask(q, profile)
			local qd = q:GetData()
			qd.craft_haemo_child = true
			qd.craft_no_haemo = true
		end
	end
end

--- 博士+血泪：小炸弹（吃档案伤害/flag/倍率）
--- 探针：Size=8、RadiusMul≈0.65、水平速≈3–6；上飞为 PO.Y 抛物线（Y0=-3，vy+=0.8）
local function spawn_haemo_bomb_burst(profile, position, direction, player, context, forced_count)
	local parent_dmg = tonumber(context.parent_damage) or ((profile.stats and profile.stats.damage) or 3.5)
	local mods = context.mods or {}
	local dmg_mul = tonumber(mods.damage_mul) or 1
	-- 低于博士主武满伤：半伤 × 蓄力等倍率（仍吃 tear/bomb flag）
	local bomb_dmg = parent_dmg * 0.5 * dmg_mul
	local count = tonumber(forced_count) or M.haemo_roll_mode_count("bombs")
	local size = 0.65 * (tonumber(mods.size_mul) or 1)
	for _ = 1, count do
		-- 连续角真随机，避免整数角/均分观感
		local ang = math.random() * 360
		local spd = 3 + math.random() * 3 -- ≈3..6
		local vel = auxi.MakeVector(ang) * spd
		local q = player:FireBomb(position, vel, player)
		if q then
			q.ExplosionDamage = bomb_dmg
			-- 探针：首帧 PO.Y=-3；之后由 Bomb_holder 按 vy+=0.8 积分上飞
			q.PositionOffset = Vector(0, -3)
			if q.RadiusMultiplier ~= nil then q.RadiusMultiplier = size end
			M.apply_bomb_scale(q, size)
			local Bomb_holder = require("Qing_Remaster_scripts.mimics.Bomb_holder")
			Bomb_holder.attach_craft_aux(q, profile, player, {
				damage_mul = 0.5 * dmg_mul,
				size_mul = size,
			})
			local craft = q:GetData()[Bomb_holder.own_key .. "craft"]
			if craft then
				-- 血泪子炸弹不再二次爆血泪
				craft.haemo = false
				-- vy0 ≈ -3.5..-8（探针首帧ΔY）；apex≈第7–8帧
				craft.hae_jump = {
					y = -3,
					vy = -(3.5 + math.random() * 4.5),
					accel = 0.8,
					done = false,
				}
			end
			local qd = q:GetData()
			qd.craft_haemo_child = true
			qd.craft_no_haemo = true
			qd.craft_bomb = true
		end
	end
end

local function spawn_haemo_knife_burst(profile, position, direction, player, context, forced_count)
	local total = tonumber(forced_count) or M.haemo_roll_mode_count("knife")
	local stats = profile.stats or M.BASE_STATS
	local parent_dmg = tonumber(context.parent_damage)
	local dmg_mul = tonumber((context.mods or {}).damage_mul) or 1
	local stats_dmg = (tonumber(stats.damage) or 3.5) * (tonumber(context.damage_mul) or 0.66) * dmg_mul
	local function child_dmg()
		if parent_dmg and parent_dmg > 0 then
			return parent_dmg * (0.5 + math.random() * (1 / 3))
		end
		return stats_dmg
	end
	for _ = 1, total do
		-- 全向散射；禁止 ±60° 锥里堆在同一侧
		spawn_haemo_knife_child(profile, position, direction, player, context, child_dmg(), {full_spread = true})
	end
end

local function spawn_haemo_mode(mode, profile, position, direction, player, context, forced_count)
	if mode == "brim" then
		spawn_haemo_brim_burst(profile, position, direction, player, context, forced_count)
	elseif mode == "tech" then
		spawn_haemo_tech_burst(profile, position, direction, player, context, forced_count)
	elseif mode == "techx" then
		spawn_haemo_techx_burst(profile, position, direction, player, context, forced_count)
	elseif mode == "bombs" then
		spawn_haemo_bomb_burst(profile, position, direction, player, context, forced_count)
	elseif mode == "knife" then
		spawn_haemo_knife_burst(profile, position, direction, player, context, forced_count)
	elseif mode == "sword" then
		local n = tonumber(forced_count) or M.haemo_roll_mode_count("sword")
		local stats = profile.stats or M.BASE_STATS
		local parent_dmg = tonumber(context.parent_damage) or (tonumber(stats.damage) or 3.5)
		local function cd()
			return parent_dmg * (0.5 + math.random() * (1 / 3))
		end
		for _ = 1, n do
			spawn_haemo_sword_tear_child(profile, position, direction, player, context, cd(), context.size_mul or 1)
		end
	else
		spawn_haemo_tear_children(profile, position, direction, player, context, forced_count)
	end
end

--- 统一血泪 burst：按档案 mode 自模拟产物，不依赖 TEAR_BURSTSPLIT / 玩家背包
--- mode="shared"：侧车（卢多等）一次触发，对各 guest 均分面额后套各自倍率
function M.spawn_craft_haemolacria_burst(profile, position, direction, source, context)
	if not M.profile_has_haemolacria(profile) then return end
	if not position then return end
	context = context or {}
	context.source = source
	local player = context.player
	if not player and source then
		if source.ToPlayer then player = source:ToPlayer() end
		if not player then player = auxi.check_spawner_player(source) end
	end
	if not player then return end
	local mode = context.mode or M.haemo_burst_mode(profile)
	if mode == "shared" or mode == "multi" then
		local modes = M.haemo_burst_guest_modes(profile)
		local n = #modes
		for _, m in ipairs(modes) do
			local base = M.haemo_roll_mode_count(m)
			local c = M.haemo_scale_mode_count(base, n)
			-- tears 在 shared 里不要再嵌套刀/剑 plan
			if m == "tears" then
				spawn_haemo_tear_children(profile, position, direction, player, context, c)
			else
				spawn_haemo_mode(m, profile, position, direction, player, context, c)
			end
		end
		return
	end
	-- 单一 mode（主泪 mark 的那份面额）：用该 mode 满额自身倍率
	spawn_haemo_mode(mode, profile, position, direction, player, context, nil)
end

--- 概率发射剑泪外观的主血泪（英灵剑兼容）；返回 tear 或 nil（调用方负责 stamp + mark）
function M.try_fire_haemo_sword_beam(profile, player, position, direction, damage, context)
	if not M.profile_has_haemolacria(profile) then return nil end
	local list = profile.list or {}
	if (list.sword or 0) <= 0 then return nil end
	context = context or {}
	local luck = tonumber(profile.stats and profile.stats.luck) or 0
	local chance = math.min(0.65, 0.35 + luck * 0.02)
	local rng = context.rng
	local roll = rng and rng.RandomFloat and rng:RandomFloat() or math.random()
	if roll >= chance then return nil end
	local dir = direction
	if not dir or dir:Length() < 0.01 then dir = Vector(10, 0) end
	local q = player:FireTear(position, dir, true, true, true)
	if not q then return nil end
	if damage then q.CollisionDamage = damage end
	q.FallingAcceleration = 0.8
	q.FallingSpeed = -8.9
	return q
end

--- 激光/剑等「攻击实例×敌人」去重：同一攻击对同一敌人只触发一次
function M.mark_haemo_hit(attack_data, enemy)
	if not attack_data or not enemy then return false end
	attack_data.haemo_hit = attack_data.haemo_hit or {}
	local ptr = GetPtrHash(enemy)
	if attack_data.haemo_hit[ptr] then return false end
	attack_data.haemo_hit[ptr] = true
	return true
end

return M
