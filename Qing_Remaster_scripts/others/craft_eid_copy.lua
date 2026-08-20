-- 蓝图材料 → 玩家可见 EID 文案（正式句式）。
-- 审计短名仍用 FLAG_NAME / EXTRA_NAME；本模块不把短名直接拼进 EID。
-- 审阅：codex_work/notes/blueprint_eid_length_and_orbit_review.md
local enums = require("Qing_Remaster_scripts.core.enums")
local json = require("json")
local dev_env = require("Qing_Remaster_scripts.core.dev_environment")

local M = {}

local WEAPON_FULL = {
	[1] = {zh = "眼泪", en = "tears"},
	[2] = {zh = "硫磺火", en = "Brimstone"},
	[3] = {zh = "科技激光", en = "Technology"},
	[4] = {zh = "妈妈的刀子", en = "Mom's Knife"},
	[5] = {zh = "胎儿博士", en = "Dr. Fetus"},
	[6] = {zh = "史诗胎儿", en = "Epic Fetus"},
	[7] = {zh = "萌死戳的肺", en = "Monstro's Lung"},
	[8] = {zh = "鲁多维科科技", en = "Ludovico Technique"},
	[9] = {zh = "科技X", en = "Tech X"},
	[10] = {zh = "骨棒", en = "Bone Club"},
	[13] = {zh = "英灵剑", en = "Spirit Sword"},
	[14] = {zh = "剖腹产", en = "C Section"},
}

local STAT_ICON_ORDER = {
	{key = "damage", icon = "Damage", also = "damage_mul"},
	{key = "firedelay", icon = "Tears", also = "firedelay_mul"},
	{key = "range", icon = "Range", also = "range_mul"},
	{key = "shotspeed", icon = "Shotspeed", also = "shotspeed_mul"},
	{key = "speed", icon = "Speed", also = "speed_mul"},
	{key = "luck", icon = "Luck", also = "luck_mul"},
}

local ZH_LINE_SOFT = 32
local EN_LINE_SOFT = 90

--- module_zh/en 可为 string 或 {string,...}；多行用数组。
--- status: supported | testing | unsupported（testing 不向玩家暴露）
M.CRAFT_EID_META = {
	[318] = {
		status = "testing",
		movement = "free",
		familiar_zh = "双子座",
		familiar_en = "Gemini",
		module_zh = {"双子座在飞行器附近自由行动，发现敌人后追撞。"},
		module_en = {"Gemini moves freely near the Air Flight and charges enemies it finds."},
	},
	[73] = {
		status = "supported",
		movement = "orbit",
		familiar_zh = "肉块",
		familiar_en = "Cube of Meat",
		module_zh = {
			"肉块环绕飞行器，阻挡弹幕并造成接触伤害。",
			"重复装载会升级形态。",
		},
		module_en = {
			"Cube of Meat orbits the Air Flight, blocking shots and dealing contact damage.",
			"Repeats upgrade its form.",
		},
	},
	[207] = {
		status = "supported",
		movement = "orbit",
		familiar_zh = "绷带球",
		familiar_en = "Ball of Bandages",
		module_zh = {
			"绷带球环绕飞行器，阻挡弹幕并造成接触伤害。",
			"重复装载会升级形态。",
		},
		module_en = {
			"Ball of Bandages orbits the Air Flight, blocking shots and dealing contact damage.",
			"Repeats upgrade its form.",
		},
	},
	[10] = {
		status = "supported",
		movement = "orbit",
		familiar_zh = "苍蝇光环",
		familiar_en = "Halo of Flies",
		module_zh = {"两只苍蝇环绕飞行器并阻挡弹幕。"},
		module_en = {"Two flies orbit the Air Flight and block projectiles."},
	},
	[57] = {
		status = "supported",
		movement = "orbit",
		familiar_zh = "仰慕之交",
		familiar_en = "Distant Admiration",
		module_zh = {"红苍蝇环绕飞行器并造成接触伤害。"},
		module_en = {"A red fly orbits the Air Flight and deals contact damage."},
	},
	[112] = {
		status = "supported",
		movement = "orbit",
		familiar_zh = "守护天使",
		familiar_en = "Guardian Angel",
		module_zh = {
			"天使环绕飞行器，阻挡弹幕并造成接触伤害。",
			"提高同飞行器其它环绕物的转速。",
		},
		module_en = {
			"An angel orbits the Air Flight, blocking shots and dealing contact damage.",
			"Speeds up other orbitals on the same Air Flight.",
		},
	},
	[128] = {
		status = "supported",
		movement = "orbit",
		familiar_zh = "永远孤独",
		familiar_en = "Forever Alone",
		module_zh = {"蓝苍蝇在较远轨道环绕飞行器并造成接触伤害。"},
		module_en = {"A blue fly orbits farther from the Air Flight and deals contact damage."},
	},
	[172] = {
		status = "supported",
		movement = "orbit",
		familiar_zh = "献祭匕首",
		familiar_en = "Sacrificial Dagger",
		module_zh = {"匕首环绕飞行器，阻挡弹幕并造成高额接触伤害。"},
		module_en = {"A dagger orbits the Air Flight, blocking shots and dealing high contact damage."},
	},
	[279] = {
		status = "supported",
		movement = "orbit",
		familiar_zh = "大粉丝",
		familiar_en = "Big Fan",
		module_zh = {
			"大型苍蝇环绕飞行器并造成接触伤害。",
			"降低同飞行器其它环绕物的转速。",
		},
		module_en = {
			"A large fly orbits the Air Flight and deals contact damage.",
			"Slows other orbitals on the same Air Flight.",
		},
	},
	[364] = {
		status = "supported",
		movement = "orbit",
		familiar_zh = "朋友区",
		familiar_en = "Friend Zone",
		module_zh = {"苍蝇环绕飞行器并造成接触伤害。"},
		module_en = {"A fly orbits the Air Flight and deals contact damage."},
	},
	[508] = {
		status = "supported",
		movement = "orbit",
		familiar_zh = "妈妈的剃刀",
		familiar_en = "Mom's Razor",
		module_zh = {
			"剃刀环绕飞行器。",
			"接触伤害随飞行器伤害缩放，并施加流血。",
		},
		module_en = {
			"A razor orbits the Air Flight.",
			"Contact damage scales with Air Flight damage and applies bleeding.",
		},
	},
	[542] = {
		status = "supported",
		movement = "orbit",
		familiar_zh = "滑肋骨",
		familiar_en = "Slipped Rib",
		module_zh = {"肋骨环绕飞行器并反弹敌弹。"},
		module_en = {"A rib orbits the Air Flight and reflects enemy projectiles."},
	},
	[11] = {
		status = "supported",
		movement = "follow",
		familiar_zh = "一命菇",
		familiar_en = "1up!",
		module_zh = {"一命菇跟随飞行器；首次坠毁时使其复原。"},
		module_en = {"1up! follows the Air Flight; its first crash restores it."},
	},
	[81] = {
		status = "supported",
		movement = "follow",
		familiar_zh = "九命猫",
		familiar_en = "Dead Cat",
		module_zh = {"九命猫跟随飞行器；坠毁时使其复原，最多9次。"},
		module_en = {"Dead Cat follows the Air Flight; crashes restore it up to 9 times."},
	},
	[436] = {
		status = "supported",
		movement = "follow",
		familiar_zh = "牛奶",
		familiar_en = "Milk!",
		module_zh = {"牛奶跟随飞行器并挡弹；破碎后，本层提高射速。"},
		module_en = {"Milk! follows the Air Flight and blocks shots; breaking raises fire rate for the floor."},
	},
	[8] = {
		module_zh = {"波比弟弟跟随飞行器，朝其瞄准方向攻击。"},
		module_en = {"Brother Bobby follows the Air Flight and attacks in its aim direction."},
	},
	[67] = {
		module_zh = {"玛姬妹妹跟随飞行器，朝其瞄准方向攻击。"},
		module_en = {"Sister Maggy follows the Air Flight and attacks in its aim direction."},
	},
	[100] = {
		module_zh = {"小史蒂文跟随飞行器，发射追踪泪弹。"},
		module_en = {"Little Steve follows the Air Flight and fires homing tears."},
	},
	[99] = {
		module_zh = {"小吉什跟随飞行器，发射减速泪弹。"},
		module_en = {"Little Gish follows the Air Flight and fires slowing tears."},
	},
	[163] = {
		module_zh = {"幽灵宝宝跟随飞行器，发射幽灵泪弹。"},
		module_en = {"Ghost Baby follows the Air Flight and fires spectral tears."},
	},
	[167] = {
		module_zh = {"小丑宝宝跟随飞行器，朝其瞄准方向双发。"},
		module_en = {"Harlequin Baby follows the Air Flight and double-shots in its aim direction."},
	},
	[174] = {
		module_zh = {"彩虹宝宝跟随飞行器，每次随机采用一种宝宝攻击。"},
		module_en = {"Rainbow Baby follows the Air Flight and each shot randomly uses a familiar attack."},
	},
	[435] = {
		module_zh = {"小洛基跟随飞行器，朝四个方向攻击。"},
		module_en = {"Lil Loki follows the Air Flight and attacks in four directions."},
	},
	[608] = {
		module_zh = {"冰冻宝宝跟随飞行器，发射冰冻泪弹。"},
		module_en = {"Freezer Baby follows the Air Flight and fires freezing tears."},
	},
	[390] = {
		module_zh = {"六翼天使跟随飞行器，发射追踪幽灵泪弹。"},
		module_en = {"Seraphim follows the Air Flight and fires homing spectral tears."},
	},
	[95] = {
		module_zh = {"机器人宝宝跟随飞行器，朝其瞄准方向发射激光。"},
		module_en = {"Robo-Baby follows the Air Flight and fires lasers in its aim direction."},
	},
	[267] = {
		module_zh = {"机器人宝宝2.0跟随飞行器，自动向附近敌人发射激光。"},
		module_en = {"Robo-Baby 2.0 follows the Air Flight and auto-fires lasers at nearby enemies."},
	},
	[268] = {
		module_zh = {"腐烂宝宝跟随飞行器；蓝苍蝇消失后重新生成。"},
		module_en = {"Rotten Baby follows the Air Flight; it respawns its blue fly when it dies."},
	},
	[322] = {
		module_zh = {"蒙戈宝宝跟随飞行器，复制同机其他宝宝的攻击。"},
		module_en = {"Mongo Baby follows the Air Flight and copies other familiars on the craft."},
	},
	[361] = {
		module_zh = {"宿命的报答跟随飞行器，复制其攻击方式。"},
		module_en = {"Fate's Reward follows the Air Flight and copies its attack type."},
	},
	[180] = {
		status = "supported",
		module_zh = {"所属玩家受伤后，飞行器释放毒气屁。"},
		module_en = {"After the owning player takes damage, the Air Flight releases a poison fart."},
	},
	[214] = {
		status = "supported",
		module_zh = {"所属玩家受伤后，本房间飞行器移动时留下血迹。"},
		module_en = {"After the owning player takes damage, the Air Flight leaves blood creep while moving this room."},
	},
	[452] = {
		status = "supported",
		module_zh = {"所属玩家受伤后，飞行器环射血泪。"},
		module_en = {"After the owning player takes damage, the Air Flight fires a ring of blood tears."},
	},
	[560] = {
		status = "supported",
		module_zh = {
			"所属玩家受伤后，飞行器环射大血泪并留下血迹。",
			"本房间提高飞行器射速。",
		},
		module_en = {
			"After the owning player takes damage, the Air Flight fires large blood tears with creep.",
			"Raises the Air Flight's fire rate for the room.",
		},
	},
	[502] = {
		status = "supported",
		module_zh = {
			"所属玩家受伤后，飞行器发射减速痘泪并留下白水迹。",
			"基础齐射时有概率额外发射一发痘泪。",
		},
		module_en = {
			"After the owner takes damage, the Air Flight fires a slowing booger tear that leaves white creep.",
			"Base volleys have a chance to fire an extra booger tear.",
		},
	},
	[447] = {
		status = "supported",
		module_zh = {"飞行器连续攻击约4秒后在脚下生成毒气云。"},
		module_en = {"After ~4s of continuous attack, the Air Flight spawns a linger gas cloud."},
	},
	[446] = {
		status = "supported",
		module_zh = {"飞行器攻击时散发绿色毒气环，使附近敌人中毒。"},
		module_en = {"While attacking, the Air Flight emits a green poison ring."},
	},
	[574] = {
		status = "supported",
		module_zh = {"飞行器周围出现圣体光，对范围内敌人持续造成伤害。"},
		module_en = {"A Monstrance halo around the Air Flight damages nearby enemies."},
	},
	[559] = {
		status = "supported",
		module_zh = {"飞行器周期性对附近敌人释放链式电击。"},
		module_en = {"The Air Flight periodically chains lightning to nearby enemies."},
	},
	[423] = {
		status = "supported",
		module_zh = {
			"飞行器周围出现保护之环，定期伤害环内敌人。",
			"敌弹进入环时有概率转为追踪友方泪。",
		},
		module_en = {
			"A Circle of Protection around the Air Flight periodically damages enemies inside.",
			"Enemy shots entering the ring may become friendly homing tears.",
		},
	},
	[399] = {
		status = "supported",
		module_zh = {"持续攻击蓄满后，飞行器自动释放黑色虚空环。"},
		module_en = {"While attacking, a full charge makes the Air Flight release a black Maw ring."},
	},
	[643] = {
		status = "supported",
		module_zh = {"持续攻击蓄满后，飞行器自动沿瞄准方向发射圣光激光。"},
		module_en = {"While attacking, a full charge makes the Air Flight fire a holy light beam along aim."},
	},
	[597] = {
		status = "supported",
		module_zh = {"不攻击时蓄积；攻击时消耗蓄积并提高射速。"},
		module_en = {"Charges while not attacking; attacking drains the charge to boost fire rate."},
	},
	[408] = {
		status = "unsupported",
		module_zh = {"原版已无受伤触发效果；制造侧受伤虚空环兼容已停用。"},
		module_en = {"Vanilla no longer triggers on hurt; craft Athame Maw-ring compat disabled."},
	},
	[573] = {
		status = "supported",
		module_zh = {"攻击时有概率额外发射环绕幽灵泪。"},
		module_en = {"Attacks have a chance to fire an extra orbiting spectral tear."},
	},
	[595] = {
		status = "supported",
		module_zh = {"进入房间时，飞行器周围出现环绕幽灵泪。"},
		module_en = {"On room entry, orbiting spectral tears appear around the Air Flight."},
	},
	[410] = {
		status = "supported",
		module_zh = {"攻击时有概率生成会自行射击的邪眼。"},
		module_en = {"Attacks have a chance to spawn an Evil Eye that fires on its own."},
	},
	[243] = {
		status = "supported",
		module_zh = {"飞行器前方出现可挡敌弹的盾。"},
		module_en = {"A shield ahead of the Air Flight blocks enemy shots."},
	},
	[400] = {
		status = "supported",
		module_zh = {"飞行器前方出现造成接触伤害的长枪。"},
		module_en = {"A spear ahead of the Air Flight deals contact damage."},
	},
	[693] = {
		status = "supported",
		module_zh = {"飞行器周围出现可挡弹的苍蝇；挡弹后变为蓝苍蝇。"},
		module_en = {"Orbiting flies around the Air Flight block shots and become blue flies."},
	},
	[702] = {
		status = "supported",
		module_zh = {"受伤后飞行器周围出现会射击的复仇之火；下楼清空。"},
		module_en = {"After damage, orbiting vengeful fires shoot from the Air Flight; cleared on new floors."},
	},
	[392] = {
		status = "supported",
		module_zh = {"每层为飞行器随机赋予一种星座效果。"},
		module_en = {"Each floor grants the Air Flight a random zodiac effect."},
	},
	[299] = {
		status = "supported",
		module_zh = {"敌房中逐渐加速，满速后短暂冲锋并造成接触伤害。"},
		module_en = {"In hostile rooms, gradually speeds up, then briefly charges with contact damage."},
	},
	[187] = {
		status = "supported",
		module_zh = {"毛球挂在飞行器上甩击；击杀可成长。"},
		module_en = {"A hairball flails from the Air Flight and grows on kills."},
	},
	[273] = {
		status = "supported",
		module_zh = {"攻击时冲出爆炸脑浆，稍后重生。"},
		module_en = {"Attacks launch an exploding brain that later respawns."},
	},
	[178] = {
		status = "supported",
		module_zh = {"攻击时掷出圣水瓶，命中留下圣水。"},
		module_en = {"Attacks throw Holy Water that leaves holy creep on hit."},
	},
	[274] = {
		status = "supported",
		module_zh = {"所属玩家受伤后，生成本房间环绕飞行器的苍蝇。"},
		module_en = {"After the owning player takes damage, spawns a room-long fly that orbits the Air Flight."},
	},
	[525] = {
		status = "supported",
		module_zh = {"所属玩家受伤后，为飞行器补充可破损环绕肉块，最多3块。"},
		module_en = {"After the owning player takes damage, adds a breakable orbital flesh chunk (max 3)."},
	},
	[275] = {
		module_zh = {"小硫磺火跟随飞行器，随攻击意图蓄力发射硫磺火。"},
		module_en = {"Lil Brimstone follows the Air Flight and charge-fires Brimstone with its attack intent."},
	},
	[679] = {
		module_zh = {"亚巴顿宝宝跟随飞行器，随攻击意图蓄力发射激光。"},
		module_en = {"Lil Abaddon follows the Air Flight and charge-fires beams with its attack intent."},
	},
	[471] = {
		module_zh = {"萌死戳宝宝跟随飞行器，随攻击意图蓄力齐射。"},
		module_en = {"Lil Monstro follows the Air Flight and charge-fires tear volleys with its attack intent."},
	},
	[88] = {
		module_zh = {"小胖蛆跟随飞行器，随攻击意图蓄力冲锋。"},
		module_en = {"Little Chubby follows the Air Flight and charge-dashes with its attack intent."},
	},
	[473] = {
		module_zh = {"大胖蛆跟随飞行器，随攻击意图蓄力冲锋。"},
		module_en = {"Big Chubby follows the Air Flight and charge-dashes with its attack intent."},
	},
	[384] = {
		module_zh = {"肉山宝宝跟随飞行器，随攻击意图蓄力冲锋。"},
		module_en = {"Lil Gurdy follows the Air Flight and charge-dashes with its attack intent."},
	},
	[113] = {
		module_zh = {"恶魔宝宝跟随飞行器，自动攻击附近敌人。"},
		module_en = {"Demon Baby follows the Air Flight and auto-attacks nearby enemies."},
	},
	[417] = {
		module_zh = {"魅魔跟随飞行器，复制其攻击并提供伤害光环。"},
		module_en = {"Succubus follows the Air Flight, copies its attacks, and provides a damage aura."},
	},
	[360] = {
		module_zh = {"淫魔跟随飞行器，复制其完整攻击。"},
		module_en = {"Incubus follows the Air Flight and copies its full attack."},
	},
	[698] = {
		module_zh = {"作孽双子分列飞行器两侧，复制其完整攻击。"},
		module_en = {"Twisted Pair flanks the Air Flight and copies its full attack."},
	},
	[319] = {
		module_zh = {"该隐的另一只眼跟随飞行器，向随机方向复制完整攻击。"},
		module_en = {"Cain's Other Eye follows the Air Flight and copies its full attack in random directions."},
	},
	[155] = {
		module_zh = {"窥眼保持斜向漂浮，并使飞行器左眼发射强化血泪。"},
		module_en = {"Peeper keeps its diagonal drift and makes the Air Flight's left eye fire stronger blood tears."},
	},
}

-- EXTRA_IMPL 键 → 条件/特效；可用 lines_zh/en 覆盖整段多行
local EXTRA_EID = {
	money_is_power = {
		lines_zh = {"根据所属玩家的硬币数量，为飞行器提供攻击属性。"},
		lines_en = {"Based on the owning player's coins, provides the Air Flight with offensive stats."},
	},
	whore_of_babylon = {
		lines_zh = {"所属玩家处于低血量时，为飞行器提供攻击属性。"},
		lines_en = {"While the owning player is at low health, provides the Air Flight with offensive stats."},
	},
	bloody_lust = {
		lines_zh = {"所属玩家本层每受到一次有效伤害，提高飞行器伤害。"},
		lines_en = {"Each valid hit the owner takes this floor raises the Air Flight's damage."},
	},
	bloody_gust = {
		lines_zh = {"所属玩家本层每受到一次有效伤害，提高飞行器射速与移速。"},
		lines_en = {"Each valid hit the owner takes this floor raises the Air Flight's fire rate and speed."},
	},
	purity = {
		lines_zh = {"所属玩家受伤后移除当前属性增益；下个房间重新获得随机增益。"},
		lines_en = {"After the owner takes damage, removes the current buff; next room grants a new random buff."},
	},
	crown_of_light = {
		lines_zh = {
			"满红心时为飞行器提供增幅。",
			"受伤后，本房间失效。",
		},
		lines_en = {
			"At full red hearts, boosts the Air Flight.",
			"After taking damage, the room bonus ends.",
		},
	},
	paschal_candle = {
		lines_zh = {"清房逐层提高飞行器射速；所属玩家受伤时清空层数。"},
		lines_en = {"Room clears stack Air Flight fire rate; taking damage clears stacks."},
	},
	epiphora = {
		lines_zh = {"飞行器持续向同一方向攻击时，逐渐提高射速。"},
		lines_en = {"While the Air Flight keeps firing one way, gradually raises fire rate."},
	},
	dead_eye = {
		lines_zh = {"连续命中会提高飞行器伤害。"},
		lines_en = {"Consecutive hits raise the Air Flight's damage."},
	},
	lusty_blood = {
		lines_zh = {"飞行器击杀敌人后，本房间提高伤害。"},
		lines_en = {"After the Air Flight kills an enemy, raises damage for the room."},
	},
	camo_undies = {
		lines_zh = {"进入新房间后进入迷彩；首次攻击获得伤害与射速爆发。"},
		lines_en = {"On a new room, camo engages; the first attack bursts damage and fire rate."},
	},
	moms_eye = {
		lines_zh = {"齐射时额外向后发射。"},
		lines_en = {"Adds a backward shot to each volley."},
	},
	lokis_horns = {
		lines_zh = {"攻击时有概率向其余三个方向额外开火。"},
		lines_en = {"Attacks have a chance to also fire in the other three cardinal directions."},
	},
	tech2 = {
		lines_zh = {"为飞行器附加持续激光。"},
		lines_en = {"Adds a continuous Technology laser to the Air Flight."},
	},
	tech5 = {
		lines_zh = {"攻击时有概率附加科技激光。"},
		lines_en = {"Attacks have a chance to add a Technology laser."},
	},
	chocolate = {
		lines_zh = {"使飞行器改为可调蓄力攻击，蓄力影响伤害与攻击间隔。"},
		lines_en = {"Makes the Air Flight use adjustable charged attacks that scale damage and delay."},
	},
	cursed_eye = {
		lines_zh = {"使飞行器蓄力齐射；蓄力时所属玩家受伤，会传送飞行器及关联宝宝。"},
		lines_en = {"Makes the Air Flight charge multi-shots; taking damage while charging teleports it and linked familiars."},
	},
}

local function profile()
	return require("Qing_Remaster_scripts.others.craft_combat_profile")
end

local function merge_meta(dst, src)
	if not src then return dst end
	dst = dst or {}
	for k, v in pairs(src) do
		if dst[k] == nil then dst[k] = v end
	end
	return dst
end

local function as_line_list(v)
	if v == nil then return nil end
	if type(v) == "table" then
		local out = {}
		for _, s in ipairs(v) do
			if type(s) == "string" and s ~= "" then out[#out + 1] = s end
		end
		return #out > 0 and out or nil
	end
	if type(v) == "string" and v ~= "" then return {v} end
	return nil
end

local function icons_from_delta(delta)
	local icons = {}
	local seen = {}
	if not delta then return icons end
	for _, row in ipairs(STAT_ICON_ORDER) do
		local v = delta[row.key]
		local m = delta[row.also]
		if (v ~= nil and v ~= 0) or (m ~= nil and m ~= 1) then
			if not seen[row.icon] then
				seen[row.icon] = true
				icons[#icons + 1] = row.icon
			end
		end
	end
	if delta.scale_mul and delta.scale_mul ~= 1 and not seen.TearSize then
		icons[#icons + 1] = "TearSize"
	end
	return icons
end

local function find_familiar_row(key)
	local CP = profile()
	for _, row in ipairs(CP.CRAFT_FAMILIAR_EXTRAS or {}) do
		if row.key == key then return row end
	end
	return nil
end

local function resolve_meta(id)
	local CP = profile()
	id = tonumber(id)
	if not id then return nil end
	local meta = {}
	for k, v in pairs(M.CRAFT_EID_META[id] or {}) do
		meta[k] = v
	end

	if CP.is_ingredient_banned and CP.is_ingredient_banned(id) then
		meta.status = "unsupported"
		return meta
	end

	for _, m in ipairs(CP.MORPH or {}) do
		if m.id == id then
			meta.weapon = meta.weapon or m.weapon
			meta.status = meta.status or "supported"
			break
		end
	end

	local delta = CP.STAT_DELTA and CP.STAT_DELTA[id]
	if delta and meta.stats == nil then
		local icons = icons_from_delta(delta)
		if #icons > 0 then
			meta.stats = icons
			meta.status = meta.status or "supported"
		end
	end
	local oe = CP.ONE_EYE and CP.ONE_EYE[id]
	if oe and not meta.stats then
		meta.stats = {"Damage"}
		meta.status = meta.status or "supported"
	elseif oe and meta.stats then
		-- keep
	end

	local fn = CP.FLAG_NAME and CP.FLAG_NAME[id]
	if fn and (fn.eid_zh or fn.eid_en) then
		meta.tear_effect_zh = meta.tear_effect_zh or fn.eid_zh
		meta.tear_effect_en = meta.tear_effect_en or fn.eid_en
		meta.status = meta.status or "supported"
	end

	local bn = CP.BOMB_NAME and CP.BOMB_NAME[id]
	if bn and (bn.eid_zh or bn.eid_en) then
		meta.bomb_effect_zh = meta.bomb_effect_zh or bn.eid_zh
		meta.bomb_effect_en = meta.bomb_effect_en or bn.eid_en
		meta.status = meta.status or "supported"
	end

	local ek = CP.EXTRA_IMPL and CP.EXTRA_IMPL[id]
	if ek then
		local row = find_familiar_row(ek)
		if row and row.movement then
			meta.movement = meta.movement or row.movement
			meta.familiar_zh = meta.familiar_zh or row.zh
			meta.familiar_en = meta.familiar_en or row.en
			meta.module_zh = meta.module_zh or row.module_zh
			meta.module_en = meta.module_en or row.module_en
			meta.status = meta.status or (row.status or "supported")
		end
		local ex = EXTRA_EID[ek]
		if ex then
			meta = merge_meta(meta, ex)
			meta.status = meta.status or "supported"
		end
	end

	if not meta.status and CP.has_impl and CP.has_impl(id) then
		return nil
	end
	return meta
end

local function has_content(meta)
	if not meta then return false end
	if meta.status == "unsupported" then return true end
	return meta.weapon ~= nil
		or (meta.stats and #meta.stats > 0)
		or meta.tear_effect_zh or meta.tear_effect_en
		or meta.bomb_effect_zh or meta.bomb_effect_en
		or meta.module_zh or meta.module_en
		or meta.lines_zh or meta.lines_en
		or meta.familiar_zh or meta.familiar_en
		or meta.condition_zh or meta.condition_en
		or meta.effect_zh or meta.effect_en
		or meta.special_zh or meta.special_en
end

local function push_line(lines, text)
	if text and text ~= "" then
		lines[#lines + 1] = text
	end
end

local function push_lines(lines, list)
	if not list then return end
	for _, s in ipairs(list) do
		push_line(lines, s)
	end
end

local function finish_sentence(s, zh)
	if not s or s == "" then return nil end
	if zh then
		if s:find("。") then return s end
		return s.."。"
	end
	if s:find("%.$") then return s end
	return s.."."
end

local function sentence_weapon(meta, zh)
	local w = meta.weapon
	if not w then return nil end
	local info = WEAPON_FULL[w]
	local name = info and (zh and info.zh or info.en) or tostring(w)
	if zh then
		return "将飞行器的主攻击方式改为"..name.."。"
	end
	return "Changes the Air Flight's primary attack to "..name.."."
end

--- 固定句；仅在确有属性继承时输出，不列图标
local function sentence_stats(meta, zh)
	if not meta.stats or #meta.stats == 0 then return nil end
	if zh then return "该模块为飞行器提供对应属性。" end
	return "Provides the Air Flight with the corresponding stats."
end

--- eid_* 已是完整句，原样返回
local function sentence_tear(meta, zh)
	return finish_sentence(zh and meta.tear_effect_zh or meta.tear_effect_en, zh)
end

local function sentence_bomb(meta, zh)
	local fx = zh and meta.bomb_effect_zh or meta.bomb_effect_en
	if not fx or fx == "" then return nil end
	-- 若已是完整句则原样
	if zh and (fx:find("装载") or fx:find("飞行器") or fx:find("生成的炸弹")) then
		return finish_sentence(fx, true)
	end
	if (not zh) and (fx:find("[Ww]hen") or fx:find("[Bb]omb")) then
		return finish_sentence(fx, false)
	end
	if zh then
		return "装载炸弹攻击模块时，生成的炸弹会"..fx.."。"
	end
	return "When a bomb-attack module is installed, generated bombs "..fx.."."
end

local function sentence_familiar_fallback(meta, zh)
	local name = zh and meta.familiar_zh or meta.familiar_en
	local mov = meta.movement
	if not name or not mov then return nil end
	if mov == "orbit" then
		if zh then return name.."环绕飞行器。" end
		return name.." orbits the Air Flight."
	elseif mov == "free" then
		if zh then return name.."在飞行器附近自由行动。" end
		return name.." moves freely near the Air Flight."
	elseif mov == "charge" then
		if zh then return name.."跟随飞行器，随攻击意图蓄力。" end
		return name.." follows the Air Flight and charges with its attack intent."
	end
	if zh then return name.."跟随飞行器。" end
	return name.." follows the Air Flight."
end

local function push_module_lines(lines, meta, zh)
	local list = as_line_list(zh and meta.module_zh or meta.module_en)
		or as_line_list(zh and meta.lines_zh or meta.lines_en)
	if list then
		for _, s in ipairs(list) do
			push_line(lines, finish_sentence(s, zh))
		end
		return true
	end
	return false
end

local function sentence_conditional(meta, zh)
	-- 已有 module/lines 时不再拼接 condition+effect，避免重复
	if as_line_list(zh and meta.module_zh or meta.module_en)
		or as_line_list(zh and meta.lines_zh or meta.lines_en) then
		return nil
	end
	local cond = zh and meta.condition_zh or meta.condition_en
	local eff = zh and meta.effect_zh or meta.effect_en
	if cond and eff then
		if zh then return cond.."，"..eff.."。" end
		return cond..", "..eff.."."
	end
	if eff and not cond then
		return finish_sentence(eff, zh)
	end
	return nil
end

local function sentence_special(meta, zh)
	local s = zh and meta.special_zh or meta.special_en
	if not s then return nil end
	if zh and (s:find("验收") or s:find("探针")) then return nil end
	if (not zh) and (s:find("validat") or s:find("probe") or s:find("under probe")) then return nil end
	return finish_sentence(s, zh)
end

function M.collectible_craft_eid_lines(id, zh)
	id = tonumber(id)
	if not id or id <= 0 then return nil end
	local bp = enums.Items.Blue_Print
	local af = enums.Items.Air_Flight
	if id == bp or id == af then return nil end

	local meta = resolve_meta(id)
	if not meta or not has_content(meta) then return nil end

	local lines = {}
	if meta.status == "unsupported" then
		push_line(lines, zh and "该道具暂不可作为飞行器材料。" or "This item cannot currently be used as an Air Flight ingredient.")
		return lines
	end

	push_line(lines, sentence_weapon(meta, zh))
	push_line(lines, sentence_stats(meta, zh))
	push_line(lines, sentence_tear(meta, zh))
	push_line(lines, sentence_bomb(meta, zh))

	local had_module = push_module_lines(lines, meta, zh)
	if not had_module then
		push_line(lines, sentence_familiar_fallback(meta, zh))
		push_line(lines, sentence_conditional(meta, zh))
	end
	push_line(lines, sentence_special(meta, zh))

	if #lines == 0 then return nil end
	return lines
end

function M.collectible_craft_eid_text(id, zh)
	local lines = M.collectible_craft_eid_lines(id, zh)
	if not lines then return nil end
	return table.concat(lines, " ")
end

local function utf8_len(s)
	if not s or s == "" then return 0 end
	local n, i = 0, 1
	local len = #s
	while i <= len do
		local c = s:byte(i)
		if not c then break end
		if c < 0x80 then i = i + 1
		elseif c < 0xE0 then i = i + 2
		elseif c < 0xF0 then i = i + 3
		else i = i + 4 end
		n = n + 1
	end
	return n
end

local function line_too_long(s, zh)
	if zh then return utf8_len(s) > ZH_LINE_SOFT end
	return #s > EN_LINE_SOFT
end

--- 导出全部可组装蓝图 EID，供长度审计
function M.export_eid_audit(zh)
	if not dev_env.probes_allowed() then
		return false, "public release: probes disabled", {count = 0, rows = {}}
	end
	zh = zh ~= false
	local rows = {}
	local cfg = Isaac.GetItemConfig()
	local limit = CollectibleType.NUM_COLLECTIBLES or 733
	for id = 1, limit - 1 do
		local col = cfg and cfg:GetCollectible(id)
		local lines = M.collectible_craft_eid_lines(id, zh)
		if lines then
			local name = col and (zh and col.Name or col.Name) or tostring(id)
			local too = false
			local lens = {}
			for i, line in ipairs(lines) do
				local n = zh and utf8_len(line) or #line
				lens[i] = n
				if line_too_long(line, zh) then too = true end
			end
			rows[#rows + 1] = {
				id = id,
				name = name,
				lines = lines,
				line_lens = lens,
				too_long = too,
			}
		end
	end
	local payload = {
		schema = "qing_blueprint_eid_audit_v1",
		zh = zh,
		soft_limit = zh and ZH_LINE_SOFT or EN_LINE_SOFT,
		count = #rows,
		rows = rows,
	}
	if not io or not io.open or not json or not json.encode then
		return false, "io/json unavailable", payload
	end
	local ok_enc, encoded = pcall(json.encode, payload)
	if not ok_enc then return false, tostring(encoded), payload end
	local fname = zh and "blueprint_eid_audit_zh.json" or "blueprint_eid_audit_en.json"
	-- 唯一规范文件；仅两种相对写法（禁止根目录/机器绝对路径兜底）
	local paths = {
		"mods/Qing_remaster/codex_work/logs/"..fname,
		"../mods/Qing_remaster/codex_work/logs/"..fname,
	}
	for _, path in ipairs(paths) do
		local ok, f = pcall(io.open, path, "w")
		if ok and f then
			f:write(encoded)
			f:close()
			return true, path, payload
		end
	end
	return false, "unable to open audit json", payload
end

return M
