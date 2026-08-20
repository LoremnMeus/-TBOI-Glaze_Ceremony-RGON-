-- 蓝图逾越节蜡烛视觉宝宝：只显示 Flight 自维护层数，不向玩家添加道具/effect/cache。
local Craft_Familiar_holder = require("Qing_Remaster_scripts.mimics.Craft_Familiar_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "Craft_Paschal_holder_",
}

local adapter = {
	name = "paschal_candle_visual",
	extra_key = "paschal_candle_visual",
	control_mode = "full",
	custom_animation = true,
	always_spawn_synthetic = true,
}

function adapter:spawn(air, player, profile)
	local fam = Isaac.Spawn(
		EntityType.ENTITY_FAMILIAR,
		FamiliarVariant.PASCHAL_CANDLE,
		0,
		air.Position,
		Vector(0, 0),
		player
	):ToFamiliar()
	if fam then fam.Player = player end
	return fam
end

function adapter:update(ctx)
	local profile = ctx.bind and ctx.bind.profile
	local layers = profile and profile.runtime and tonumber(profile.runtime.paschal_layers) or 0
	layers = math.max(0, math.min(5, math.floor(layers or 0)))
	local sprite = ctx.familiar:GetSprite()
	local anim = "Idle" .. tostring(layers)
	if sprite and sprite:HasAnimation(anim) and not sprite:IsPlaying(anim) then
		sprite:Play(anim, true)
	end
end

-- 视觉宝宝不攻击；返回 false，避免写入开火冷却。
function adapter:fire(ctx)
	return false
end

Craft_Familiar_holder.register_adapter(FamiliarVariant.PASCHAL_CANDLE, adapter)
item.adapter = adapter

return item
