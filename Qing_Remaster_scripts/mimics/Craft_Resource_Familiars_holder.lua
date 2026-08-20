-- 蓝图第二组·资源宝宝：脱离玩家 follower 链；AI=原版（掉落/充能/胶囊）；AI 后 FollowPosition + 强 Velocity
-- 范围：blueprint_familiar_batch_scope_v2.md §第二组
-- 禁止 keep_vanilla_ai 特殊轨道路径；普通 move_only 的 FollowPosition 强驱动由公共 holder 统一完成
local H = require("Qing_Remaster_scripts.mimics.Craft_Familiar_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "Craft_Resource_Familiars_holder_",
}

local function register(variant, adapter)
	if adapter.supports_bffs == nil then adapter.supports_bffs = false end
	if adapter.supports_lullaby == nil then adapter.supports_lullaby = false end
	if adapter.supports_bender == nil then adapter.supports_bender = false end
	-- AI 放行原版；PRE/UPDATE 保持脱队，FAMILIAR_UPDATE 用 FollowPosition + 强 Velocity。
	adapter.control_mode = "move_only"
	adapter.keep_vanilla_ai = false
	adapter.trail_follow = false
	adapter.strict_follow = false
	if adapter.no_fire == nil then adapter.no_fire = true end
	if adapter.formation_priority == nil then adapter.formation_priority = 7000 end
	H.register_adapter(variant, adapter)
end

local function res(opts)
	register(opts.variant, {
		name = opts.name,
		extra_key = opts.key,
		collectible = opts.collectible,
		formation_priority = opts.priority,
	})
end

-- 94 Sack of Pennies
res({
	variant = FamiliarVariant.SACK_OF_PENNIES or 21,
	name = "sack_of_pennies",
	key = "sack_of_pennies",
	collectible = CollectibleType.COLLECTIBLE_SACK_OF_PENNIES or 94,
	priority = 7000,
})

-- 96 Little C.H.A.D.
res({
	variant = FamiliarVariant.LITTLE_CHAD or 22,
	name = "little_chad",
	key = "little_chad",
	collectible = CollectibleType.COLLECTIBLE_LITTLE_CHAD or 96,
	priority = 7010,
})

-- 98 The Relic
res({
	variant = FamiliarVariant.RELIC or 23,
	name = "relic",
	key = "relic",
	collectible = CollectibleType.COLLECTIBLE_RELIC or 98,
	priority = 7020,
})

-- 131 Bomb Bag
res({
	variant = FamiliarVariant.BOMB_BAG or 20,
	name = "bomb_bag",
	key = "bomb_bag",
	collectible = CollectibleType.COLLECTIBLE_BOMB_BAG or 131,
	priority = 7030,
})

-- 271 Mystery Sack
res({
	variant = FamiliarVariant.MYSTERY_SACK or 57,
	name = "mystery_sack",
	key = "mystery_sack",
	collectible = CollectibleType.COLLECTIBLE_MYSTERY_SACK or 271,
	priority = 7040,
})

-- 362 Lil Chest
res({
	variant = FamiliarVariant.LIL_CHEST or 82,
	name = "lil_chest",
	key = "lil_chest",
	collectible = CollectibleType.COLLECTIBLE_LIL_CHEST or 362,
	priority = 7050,
})

-- 372 Charged Baby
res({
	variant = FamiliarVariant.CHARGED_BABY or 86,
	name = "charged_baby",
	key = "charged_baby",
	collectible = CollectibleType.COLLECTIBLE_CHARGED_BABY or 372,
	priority = 7060,
})

-- 389 Rune Bag
res({
	variant = FamiliarVariant.RUNE_BAG or 91,
	name = "rune_bag",
	key = "rune_bag",
	collectible = CollectibleType.COLLECTIBLE_RUNE_BAG or 389,
	priority = 7070,
})

-- 491 Acid Baby
res({
	variant = FamiliarVariant.ACID_BABY or 112,
	name = "acid_baby",
	key = "acid_baby",
	collectible = CollectibleType.COLLECTIBLE_ACID_BABY or 491,
	priority = 7080,
})

-- 500 Sack of Sacks
res({
	variant = FamiliarVariant.SACK_OF_SACKS or 114,
	name = "sack_of_sacks",
	key = "sack_of_sacks",
	collectible = CollectibleType.COLLECTIBLE_SACK_OF_SACKS or 500,
	priority = 7090,
})

-- 539 Mystery Egg：蛋体跟随；受伤召唤仍靠原版/on-hurt 归属
res({
	variant = FamiliarVariant.MYSTERY_EGG or 124,
	name = "mystery_egg",
	key = "mystery_egg",
	collectible = CollectibleType.COLLECTIBLE_MYSTERY_EGG or 539,
	priority = 7100,
})

return item
