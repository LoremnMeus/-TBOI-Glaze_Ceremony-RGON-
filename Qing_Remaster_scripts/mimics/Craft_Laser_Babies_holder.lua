-- §16.7 第二批：激光 / 近距自动射手
-- Robo-Baby：full + FireTechLaser（随 Air Flight intent）
-- Robo-Baby 2：move_only（放行原版对齐激光；帧末只纠正编队）
-- Demon Baby：full + auto_seek（原版强制跟玩家，必须手写覆盖）
local Craft_Familiar_holder = require("Qing_Remaster_scripts.mimics.Craft_Familiar_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "Craft_Laser_Babies_holder_",
}

local H = Craft_Familiar_holder
local CD_STD = 22 -- wiki Robo≈1.36/s
local CD_DEMON = 10 -- wiki≈3发/秒

local function register(variant, adapter)
	H.register_adapter(variant, adapter)
end

register(FamiliarVariant.ROBO_BABY, {
	name = "robo_baby",
	extra_key = "robo_baby",
	collectible = CollectibleType.COLLECTIBLE_ROBO_BABY or 95,
	class = "laser",
	control_mode = "full",
	mongo_copyable = true,
	supports_bffs = true,
	supports_lullaby = true,
	supports_bender = false,
	base_cooldown = CD_STD,
	damage = 3.5,
	head_delay = 8,
	laser_offset = LaserOffset.LASER_TECH1_OFFSET,
	fire = function(adapter, ctx)
		local opts = {}
		if ctx and type(ctx.fire_opts) == "table" then
			for k, v in pairs(ctx.fire_opts) do opts[k] = v end
		end
		return H.fire_tech_laser(ctx.familiar, ctx.player, ctx.aim_vector, adapter, opts) ~= nil
	end,
})

-- 原版会按射击方向移动并在对齐时自行激光；绑定后只接管编队移动
register(FamiliarVariant.ROBO_BABY_2, {
	name = "robo_baby_2",
	extra_key = "robo_baby_2",
	collectible = CollectibleType.COLLECTIBLE_ROBO_BABY_2 or 267,
	class = "laser",
	control_mode = "move_only",
	mongo_copyable = false,
	supports_lullaby = false,
})

-- 原版 AI 强制 FollowParent/跟玩家；绑定后 PRE 跳过并手写近距索敌
register(FamiliarVariant.DEMON_BABY, {
	name = "demon_baby",
	extra_key = "demon_baby",
	collectible = CollectibleType.COLLECTIBLE_DEMON_BABY or 113,
	class = "auto_seek",
	control_mode = "full",
	mongo_copyable = true,
	auto_seek = true,
	seek_range = 120,
	base_cooldown = CD_DEMON,
	projectile_speed = 8,
	damage = 3.5,
	head_delay = 8,
	fire = function(adapter, ctx)
		local opts = {}
		if ctx and type(ctx.fire_opts) == "table" then
			for k, v in pairs(ctx.fire_opts) do opts[k] = v end
		end
		return H.fire_basic_tear(ctx.familiar, ctx.player, ctx.aim_vector, adapter, opts) ~= nil
	end,
})

function item.sync_air_flight(air, player, profile)
	return H.sync_air_flight(air, player, profile)
end

function item.release_for_air(air)
	return H.release_for_air(air)
end

return item
