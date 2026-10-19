-- Craft static registry: declarations, lookup, compat registration.
-- Structural extract from craft_combat_profile.lua. No combat semantic changes.
local enums = require("Qing_Remaster_scripts.core.enums")

local Mod = {}

function Mod.attach(M)

M.BASE_STATS = {
		damage = 3.5,
		firedelay = 10,
		shotspeed = 1,
		range = 260,
		luck = 0,
		speed = 1,
	}
M.TARGET_BASE = {
		-- serial display: 空行01号 / AF01（Air Terror 保留供旧档显示，当前不可新造）
		[enums.Items.Air_Flight] = {zh = "空行", en = "AF"},
		[enums.Items.Air_Terror] = {zh = "空怖", en = "AT"},
	}
	-- 底座品质 0–4 → 材料槽数 / 整体属性倍率（未放底座时槽数为 0、倍率 1）
M.BASE_QUALITY_SLOTS = {
		[0] = 1, [1] = 2, [2] = 3, [3] = 4, [4] = 5,
	}
M.BASE_QUALITY_STAT_MUL = {
		[0] = 0.80, [1] = 0.90, [2] = 1.00, [3] = 1.15, [4] = 1.30,
	}

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
	["2,9"] = 9,  -- Brim + Tech X → Tech X 环形载体（蓄力硫磺圈）
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

--- Ghost Pepper / Bird's Eye（495/616）：原生火焰 Effect 生成概率。
--- 单项 1/max(2, 12-⌊luck⌋)；双持 1/max(1, 8-⌊luck⌋) 后 50/50 选蓝/红。
function M.candle_fire_chance(luck, both)
	local l = math.floor(tonumber(luck) or 0)
	if both then
		return 1 / math.max(1, 8 - l)
	end
	return 1 / math.max(2, 12 - l)
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
	[329] = {zh = "幽灵穿透", en = "Spectral Piercing", effect_key = "spectral_piercing", eid_zh = "飞行器发射的泪弹带有幽灵穿透。", eid_en = "The Air Flight's tears become spectral and piercing."},
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

-- Mod collectible static combat stats (Flight profile; not player EvaluateItems).
-- Player CACHE often uses get_damage_multiplier(player). Flight does NOT inherit character
-- damage multipliers — STAT_DELTA values are Isaac damage units on the independent profile.
-- Nihilistic Artificial Eye: player = +0.33 × character damage multiplier × copies;
-- Blueprint = +0.33 damage × recipe copies (no holder character multiplier).
if enums.Items.Nihilistic_Artificial_Eye and enums.Items.Nihilistic_Artificial_Eye > 0 then
	M.STAT_DELTA[enums.Items.Nihilistic_Artificial_Eye] = {damage = 0.33}
end
-- Pageant Cross-dresser: +2 Luck × copies (costume/visual not inherited).
if enums.Items.Pageant_Cross_dresser and enums.Items.Pageant_Cross_dresser > 0 then
	M.STAT_DELTA[enums.Items.Pageant_Cross_dresser] = {luck = 2}
end
-- Hunger Burger: +1 Damage / +0.3 Speed × copies (hearts / mini-burger spawn not inherited).
if enums.Items.Hunger_Burger and enums.Items.Hunger_Burger > 0 then
	M.STAT_DELTA[enums.Items.Hunger_Burger] = {damage = 1, speed = 0.3}
end
-- Cursed Mask: +2 Damage × copies. Seija +2 Tears is conditional — not in STAT_DELTA.
if enums.Items.Cursed_Mask and enums.Items.Cursed_Mask > 0 then
	M.STAT_DELTA[enums.Items.Cursed_Mask] = {damage = 2}
end

-- Cheater's Blessing: per-copy micro stats. Tears (+0.01 TearsUp) → craft_dynamic fire_rate_add.
if enums.Items.Cheater_s_Blessing and enums.Items.Cheater_s_Blessing > 0 then
	M.STAT_DELTA[enums.Items.Cheater_s_Blessing] = {
		speed = 0.01,
		damage = 0.01,
		range = 0.4,
		luck = 0.01,
		shotspeed = 0.01,
	}
end

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
	[495] = "candle", -- Ghost Pepper：攻击时概率生成 BLUE_FLAME（与 616 联合 proc）
	[558] = "eye", -- Eye Sore：volley 概率随机方向额外弹
	[600] = "eye_drops",
	[605] = "scooper",
	[616] = "candle", -- Bird's Eye：攻击时概率生成 RED_CANDLE_FLAME（与 495 联合 proc）
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

--- Explicit Blueprint incompatibilities (not "pending impl").
--- id → {reason=, zh=, en=}；不注册 EXTRA_IMPL；并入 STAT_AUDIT_EXCLUDE 以免遗漏报警。
M.CRAFT_EXCLUDED = {}

function M.is_craft_excluded(id)
	id = tonumber(id)
	return id ~= nil and M.CRAFT_EXCLUDED[id] ~= nil
end

function M.register_craft_excluded(id, meta)
	id = tonumber(id)
	if not id or id <= 0 then return nil end
	meta = type(meta) == "table" and meta or {reason = tostring(meta or "excluded")}
	M.CRAFT_EXCLUDED[id] = meta
	M.STAT_AUDIT_EXCLUDE[id] = true
	return meta
end

--- FireTear 从玩家状态原生继承的效果：不重复模拟，不作为独立模块，不可装载。
--- 无 pedestal Blueprint EID；has_impl=false；并入 is_ingredient_banned。
M.INHERITED_PLAYER_EFFECT = {}

function M.is_inherited_player_effect(id)
	id = tonumber(id)
	return id ~= nil and M.INHERITED_PLAYER_EFFECT[id] ~= nil
end

function M.register_inherited_player_effect(id, meta)
	id = tonumber(id)
	if not id or id <= 0 then return nil end
	meta = type(meta) == "table" and meta or {reason = tostring(meta or "inherited_player_effect")}
	meta.compat = meta.compat or "inherited_player_effect"
	M.INHERITED_PLAYER_EFFECT[id] = meta
	M.STAT_AUDIT_EXCLUDE[id] = true
	return meta
end

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
	{key = "shade", list = "shade", zh = "阴影", en = "Shade", movement = "trail"},
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
	if not id or id <= 0 then return false end
	if M.INGREDIENT_BAN[id] == true then return true end
	-- FireTear 原生继承：不可装入材料槽，也不进 counts
	if M.is_inherited_player_effect(id) then return true end
	return false
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
	if M.is_craft_excluded(id) then return false end
	if M.is_active_collectible(id) then return false end
	if M.EXTRA_IMPL[id] then return false end -- 动态/行为已登记
	if M.is_morph_item(id) then return false end
	if M.TEAR_FLAG_MASK[id] then return false end
	if M.BOMB_EFFECTS[id] then return false end
	if M.FETUS_SEC_FLAGS[id] then return false end
	return M.has_stat_cache(id) and M.STAT_DELTA[id] == nil
end

function M.is_stat_item(id)
	id = tonumber(id)
	if not id or id <= 0 then return false end
	if M.STAT_DELTA[id] then return true end
	local memo = _stat_cache_memo[id]
	if memo ~= nil then return memo end
	-- CacheFlags / items.xml cache= ≠ 已实现数值；仅 TAG_TEARS_UP 等显式属性 tag 可作兼容信号。
	-- 模组道具有 cache 时走 missing_stat_delta 审计，不可自动 has_impl。
	local ok = false
	local col = Isaac.GetItemConfig():GetCollectible(id)
	if col and ItemConfig.TAG_TEARS_UP and col.Tags and (col.Tags & ItemConfig.TAG_TEARS_UP) ~= 0 then
		ok = true
	end
	_stat_cache_memo[id] = ok
	return ok
end

function M.has_impl(id)
	id = tonumber(id)
	if not id or id <= 0 then return false end
	-- 原生继承 ≠ Blueprint 模块实装
	if M.is_inherited_player_effect(id) then return false end
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
	if M.is_inherited_player_effect(id) then tags[#tags + 1] = "inherited_player_effect" end
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

-- 新增蓝图兼容的单一登记入口。旧表继续可读；新模块禁止再分别手写
-- EXTRA_IMPL / EXTRA_NAME / CRAFT_FAMILIAR_EXTRAS / CRAFT_ORBITAL_EXTRAS。
M.COMPAT_REGISTRY = {}
M.COMPAT_RUNTIME_ADAPTERS = {}

local function upsert_row(rows, key, row)
	for index, old in ipairs(rows) do
		if old.key == key then rows[index] = row return end
	end
	rows[#rows + 1] = row
end

--- def = {id, key, zh, en, category="effect|familiar|orbital", list, movement,
---        also_fx, status, runtime_adapter}
function M.register_compat(def)
	if type(def) ~= "table" then return nil, "definition must be a table" end
	local id = tonumber(def.id)
	local key = def.key
	if not id or id <= 0 or type(key) ~= "string" or key == "" then
		return nil, "id and key are required"
	end
	local old = M.COMPAT_REGISTRY[id]
	if old and old.key ~= key then return nil, "collectible already registered as "..tostring(old.key) end
	-- familiar 的默认 list key = compat key；必须写回 def，list_from_counts 读的是 COMPAT_REGISTRY 原表。
	if def.category == "familiar" and (type(def.list) ~= "string" or def.list == "") then
		def.list = key
	end
	M.COMPAT_REGISTRY[id] = def
	M.EXTRA_IMPL[id] = key
	if def.zh or def.en then
		M.EXTRA_NAME[key] = {zh = def.zh or key, en = def.en or key}
	end
	if def.category == "familiar" then
		local row = {
			key = key, list = def.list or key,
			zh = def.zh or key, en = def.en or key,
			movement = def.movement or "follow",
			also_fx = def.also_fx == true,
			status = def.status,
		}
		upsert_row(M.CRAFT_FAMILIAR_EXTRAS, key, row)
		M.CRAFT_FAMILIAR_EXTRAS_KEY_SET[key] = true
		M.CRAFT_FAMILIAR_EXTRA_LIST_KEY[key] = row.list
		M.CRAFT_FAMILIAR_ALSO_FX[key] = row.also_fx or nil
	elseif def.category == "orbital" then
		local row = {key = key, id = id, zh = def.zh or key, en = def.en or key, status = def.status}
		upsert_row(M.CRAFT_ORBITAL_EXTRAS, key, row)
		M.CRAFT_ORBITAL_EXTRAS_KEY_SET[key] = true
	end
	if def.runtime_adapter then M.COMPAT_RUNTIME_ADAPTERS[key] = def.runtime_adapter end
	_impl_cache = nil
	return def
end

function M.register_runtime_adapter(key, adapter_id)
	if type(key) ~= "string" or key == "" then return false end
	M.COMPAT_RUNTIME_ADAPTERS[key] = adapter_id or true
	return true
end

--- 将现有稳定表投影到统一 manifest。这里只建立索引，不重写旧表或改变运行行为；
--- 后续迁移某一项时，用 register_compat 同 id/key 覆盖 legacy 定义即可。
function M.bootstrap_legacy_compat_registry()
	local familiar_rows, orbital_rows = {}, {}
	for _, row in ipairs(M.CRAFT_FAMILIAR_EXTRAS) do familiar_rows[row.key] = row end
	for _, row in ipairs(M.CRAFT_ORBITAL_EXTRAS) do orbital_rows[row.key] = row end
	for id, key in pairs(M.EXTRA_IMPL) do
		if type(key) == "string" and M.COMPAT_REGISTRY[id] == nil then
			local name = M.EXTRA_NAME[key] or {}
			local familiar = familiar_rows[key]
			local orbital = orbital_rows[key]
			local category = familiar and "familiar" or (orbital and "orbital" or "effect")
			M.COMPAT_REGISTRY[id] = {
				id = id,
				key = key,
				zh = familiar and familiar.zh or (orbital and orbital.zh or name.zh),
				en = familiar and familiar.en or (orbital and orbital.en or name.en),
				category = category,
				list = familiar and (familiar.list or key) or nil,
				movement = familiar and familiar.movement or nil,
				status = familiar and familiar.status or (orbital and orbital.status or nil),
				legacy = true,
			}
			M.COMPAT_RUNTIME_ADAPTERS[key] = M.COMPAT_RUNTIME_ADAPTERS[key]
				or (category == "familiar" and "legacy:Craft_Familiar_holder")
				or (category == "orbital" and "legacy:Craft_Orbital_holder")
				or "legacy:effect_router"
		end
	end
end

--- 启动/ImGui 可调用的纯只读接线审计。
M.bootstrap_legacy_compat_registry()

-- Batch-1 Attack consumer modules (register_compat syncs EXTRA_IMPL / EXTRA_NAME / has_impl).
-- Names from translations/translate.lua formal Name fields.
do
	local function reg_attack_consumer(id, key, zh, en)
		if not id or id <= 0 then return end
		M.register_compat({
			id = id,
			key = key,
			zh = zh,
			en = en,
			category = "effect",
			runtime_adapter = "attack_consumer:" .. key,
		})
	end
	reg_attack_consumer(enums.Items.Tech_9, "tech9", "科技IX", "Tech IX")
	reg_attack_consumer(enums.Items.Assassin_s_Eye, "assassin", "刺杀者之眼", "Assassin's Eye")
	reg_attack_consumer(enums.Items.Tears_of_Pearl, "pearl", "鲛人之泪", "Tears of Pearl")
	reg_attack_consumer(enums.Items.Evil_Intervention, "evil_intervention", "邪恶干涉", "Evil Intervention")
	reg_attack_consumer(enums.Items.Seeker_s_Eye, "seeker", "求索者之眼", "Seeker's Eye")
	reg_attack_consumer(enums.Items.Gospel, "gospel", "福音", "Gospel")
end

do
	local function reg_effect(id, key, zh, en, adapter)
		if not id or id <= 0 then return end
		M.register_compat({
			id = id,
			key = key,
			zh = zh,
			en = en,
			category = "effect",
			runtime_adapter = adapter,
		})
	end
	reg_effect(enums.Items.Cursed_Mask, "cursed_mask", "诅咒面具", "Cursed Mask", "craft:cursed_mask_aim")
	reg_effect(enums.Items.Field, "field", "逆反力场", "Anti-Field", "craft_dynamic:field")
	reg_effect(enums.Items.Wavering_Eyes, "wavering_eyes", "摇摆之眼", "Wavering Eyes", "craft:wavering_eyes")
	reg_effect(enums.Items.Procrastination, "procrastination", "拖延症", "Procrastination", "craft_dynamic:procrastination")
	reg_effect(enums.Items.Aphasia, "aphasia", "失语症", "Aphasia", "craft_dynamic:aphasia")
	reg_effect(enums.Items.Crown_of_the_glaze, "crown_glaze", "琉璃的冠冕", "Crown of the Glaze", "craft_dynamic:crown_glaze")
	reg_effect(enums.Items.Mental_Hypnosis, "mental_hypnosis", "精神控制", "Mental Hypnosis", "craft_dynamic:mental_hypnosis")
	reg_effect(enums.Items.Cheater_s_Blessing, "cheater_blessing", "作弊者的祝福", "Cheater's Blessing", "craft_dynamic:cheater_blessing")
	reg_effect(enums.Items.Hypermnesia, "hypermnesia", "超忆症", "Hypermnesia", "craft_dynamic:hypermnesia")
	reg_effect(enums.Items.Darkness, "darkness", "暗之六面", "Darkness", "craft_dynamic:darkness")
	reg_effect(enums.Items.Dragon_Tooth, "dragon_tooth", "深渊龙牙", "Dragon Tooth", "craft_dynamic:dragon_tooth")
	reg_effect(enums.Items.Giant_Punch, "giant_punch", "巨大化", "Giant Punch", "craft_dynamic:giant_punch")
	reg_effect(enums.Items.Moment, "moment", "妖星·一瞬", "Moment", "craft_dynamic:moment")
	reg_effect(enums.Items.Sacred_Mind_Shield, "sacred_mind_shield", "神圣心之防护罩－心灵之力", "Sacred Mind Shield", "craft_dynamic:sacred_mind_shield")
	reg_effect(enums.Items.The_Watcher, "watcher", "监视", "The Watcher", "craft:watcher_network")
	reg_effect(enums.Items.Tech_14, "tech14", "科技XIV", "Tech XIV", "craft:tech14_path")
end

-- Colorblindness: pool like/dislike system; stale items.xml cache removed — not a Flight stat module.
if enums.Items.Colorblindness and enums.Items.Colorblindness > 0 then
	M.register_craft_excluded(enums.Items.Colorblindness, {
		reason = "player_pool_rating",
		zh = "道具池评价/跨局封禁属于玩家系统，不适用于飞行器。",
		en = "Item-pool like/dislike and next-run bans are player systems; not applicable to Air Flight.",
	})
end

-- Book of Voice: active contract DamageMul — not a passive Flight stat.
if enums.Items.Book_of_Voice and enums.Items.Book_of_Voice > 0 then
	M.STAT_AUDIT_EXCLUDE[enums.Items.Book_of_Voice] = true
end

-- Blaststone: full player input / charge / recoil / independent effect attack — not Flight-compatible.
if enums.Items.Blaststone and enums.Items.Blaststone > 0 then
	M.register_craft_excluded(enums.Items.Blaststone, {
		reason = "player_controlled_attack",
		zh = "玩家专属蓄力/位移攻击系统，不适用于飞行器。",
		en = "Player-controlled charge/recoil attack; not applicable to Air Flight.",
	})
end

-- Abiogenesis: 道具触发后转为永久玩家宝宝，本体不再是可持续持有的 Familiar 材料。
if enums.Items.Abiogenesis and enums.Items.Abiogenesis > 0 then
	M.register_craft_excluded(enums.Items.Abiogenesis, {
		reason = "transformed_permanent_familiar",
		zh = "触发后转为永久玩家宝宝，道具本体不再作为飞行器宝宝材料。",
		en = "Transforms into a permanent player familiar; the collectible is not a Flight familiar source.",
	})
end

-- The Mulligan: FireTear 从玩家库存原生产蝇，Lua TearFlags / PRE_APPLY 都看不见。
-- 不再 1/6 模拟 TEAR_MULLIGAN，避免与原生继承叠乘。
M.register_inherited_player_effect(151, {
	reason = "player_firetear_inherited",
	zh = "飞行器会继承玩家持有的该效果；无法作为独立模块配置。",
	en = "The Air Flight inherits this effect from the player; it cannot be configured as its own module.",
})

--- 制造宝宝审计短名（独立「宝宝」行；不挤占特效）
M.CHARGE_RULES = {
	chocolate = {
		domain = { intervals = { { 0.25, 2.00 } } },
	},
	techx = {
		domain = { intervals = { { 0.25, 1.00 } } },
	},
	knife = {
		domain = { intervals = { { 0.25, 1.00 } } },
	},
	cursed_eye = {
		domain = {
			points = { 1.00, 1.50, 2.00, 2.50, 3.00 },
		},
	},
}

M.SUPPORTED_RANDOM_WEAPONS = {1, 2, 3, 4, 5, 6, 7, 9, 10, 13, 14}

end

return Mod
