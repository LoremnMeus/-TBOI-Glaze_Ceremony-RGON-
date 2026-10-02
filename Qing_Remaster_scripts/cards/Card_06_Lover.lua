local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Nil_holder = require("Qing_Remaster_scripts.others.Nil_holder")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Lover,
	own_key = "Thoth_cd6_Lov_",
	heart_anm2 = "gfx/cards/cd06_lover_heart.anm2",
	flight_duration = 16,
	land_fade_frames = 9,
	layer_aura = 0,
	layer_heart = 1,
	heart_color = Color(1, 0.72, 0.82, 1, 0.12, 0.02, 0.05),
}

-- Lover uses a strict pickup whitelist.
-- Only resources that cannot normally be dropped back onto the floor,
-- plus one-shot chest pickups, are allowed.
--
-- Do NOT add cards, runes, soul stones, pills, trinkets or other
-- inventory-like pickups here: picking them up and dropping them again
-- creates a fresh pickup entity and would allow repeated duplication rolls.
local COPYABLE_VARIANTS = {
	-- 基础资源
	[PickupVariant.PICKUP_HEART] = true,
	[PickupVariant.PICKUP_COIN] = true,
	[PickupVariant.PICKUP_KEY] = true,
	[PickupVariant.PICKUP_BOMB] = true,
	[PickupVariant.PICKUP_LIL_BATTERY] = true,
	[PickupVariant.PICKUP_GRAB_BAG] = true,
	[PickupVariant.PICKUP_POOP] = true,

	-- 箱子（接触即判定；不要求本帧已成功开启）
	[PickupVariant.PICKUP_CHEST] = true,
	[PickupVariant.PICKUP_BOMBCHEST] = true,
	[PickupVariant.PICKUP_SPIKEDCHEST] = true,
	[PickupVariant.PICKUP_ETERNALCHEST] = true,
	[PickupVariant.PICKUP_MIMICCHEST] = true,
	[PickupVariant.PICKUP_OLDCHEST] = true,
	[PickupVariant.PICKUP_WOODENCHEST] = true,
	[PickupVariant.PICKUP_MEGACHEST] = true,
	[PickupVariant.PICKUP_HAUNTEDCHEST] = true,
	[PickupVariant.PICKUP_LOCKEDCHEST] = true,
	[PickupVariant.PICKUP_REDCHEST] = true,
}

local function smoothstep(a, b, t)
	t = math.max(0, math.min(1, t))
	t = t * t * (3 - 2 * t)
	return a + (b - a) * t
end

local function bezier3(p0, p1, p2, p3, t)
	local u = 1 - t
	local uu = u * u
	local tt = t * t
	return p0 * (uu * u) + p1 * (3 * uu * t) + p2 * (3 * u * tt) + p3 * (tt * t)
end

local function flight_scale(t)
	if t <= 0.2 then
		return smoothstep(0.62, 0.82, t / 0.2)
	elseif t <= 0.8 then
		return 0.82
	end
	return smoothstep(0.82, 0.70, (t - 0.8) / 0.2)
end

-- 视觉升空：PositionOffset.Y 负向上。起跳约 -18，中段约 -34，落地 0。
local function flight_lift(t)
	return -100 * t * (1 - t) - 18 * (1 - t)
end

-- 飞行进度：背后 aura 出现 → 峰值 → 落地前收掉。
local function flight_aura_alpha(t)
	return 0.9 * math.sin(math.pi * math.max(0, math.min(1, t)))
end

local function safe_layer(sprite, id)
	if not sprite or not sprite.GetLayer or id == nil then return nil end
	local ok, layer = pcall(function() return sprite:GetLayer(id) end)
	if ok then return layer end
	return nil
end

local function set_layer_color(sprite, layer_id, color)
	local layer = safe_layer(sprite, layer_id)
	if layer and layer.SetColor then
		layer:SetColor(color)
		if layer.SetVisible then layer:SetVisible(color.A > 0.01) end
	end
end

local function apply_heart_visual(s, scale, heart_alpha, rotation, aura_alpha)
	s.Scale = Vector(scale, scale)
	s.Rotation = rotation or 0
	-- 根 Color 保持白，避免把 aura 乘成脏粉；分层上色。
	s.Color = Color(1, 1, 1, 1, 0, 0, 0)
	local base = item.heart_color
	set_layer_color(s, item.layer_heart, Color(base.R, base.G, base.B, heart_alpha, base.RO, base.GO, base.BO))
	set_layer_color(s, item.layer_aura, Color(1, 1, 1, math.max(0, aura_alpha or 0), 0, 0, 0))
end

local function resolve_love_copy(payload, normal_landing)
	if not payload or payload.resolved then
		return
	end
	payload.resolved = true
	local landing = payload.landing_pos or Vector.Zero
	local copy = Isaac.Spawn(
		EntityType.ENTITY_PICKUP,
		payload.variant,
		payload.subtype,
		landing,
		Vector.Zero,
		payload.player
	):ToPickup()
	if copy then
		copy:GetData()[item.own_key.."copy"] = true
	end
	if normal_landing then
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_HEARTIN, 0.35, 1, false, 0, 2)
	end
end

local function begin_landing(ent, d, s, fx)
	fx.landing = true
	fx.land_fade = 0
	ent.Position = fx.p3
	ent.Velocity = Vector.Zero
	ent.PositionOffset = Vector.Zero
	resolve_love_copy(fx.payload, true)
	-- 落地瞬间：爱心略弹，aura 短暂亮一下再一起柔和消散。
	apply_heart_visual(s, 0.72, 1, 0, 0.55)
end

local function spawn_love_heart(player, pickup, landing_pos)
	local p0 = player.Position
	local p3 = landing_pos
	local delta = p3 - p0
	local dist = delta:Length()
	local side_sign = (pickup.InitSeed % 2 == 0) and 1 or -1
	local dir
	if dist > 0.5 then
		dir = delta:Normalized()
	else
		dir = auxi.MakeVector(pickup.InitSeed % 360)
	end
	local perp = Vector(-dir.Y, dir.X) * side_sign
	local side = math.min(30, math.max(20, 20 + dist * 0.2))
	local p1 = p0 + dir * 10 + perp * side
	local p2 = p3 - dir * 8 + perp * (side * 0.25)

	local heart = auxi.fire_nil(p0, Vector.Zero, {
		cooldown = 45,
		player = player,
	})
	if not heart then
		resolve_love_copy({
			variant = pickup.Variant,
			subtype = pickup.SubType,
			landing_pos = landing_pos,
			player = player,
			resolved = false,
		}, false)
		return
	end

	heart = heart:ToEffect()
	heart.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	heart.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	heart.PositionOffset = Vector(0, flight_lift(0))

	local s = heart:GetSprite()
	s:Load(item.heart_anm2, true)
	s:Play("Idle", true)
	apply_heart_visual(s, 0.62, 1, 0, flight_aura_alpha(0))

	local d = heart:GetData()
	d.nil_mode = "card_06_lover_heart"
	d[item.own_key.."love_fx"] = {
		age = 0,
		duration = item.flight_duration,
		p0 = p0,
		p1 = p1,
		p2 = p2,
		p3 = p3,
		side_sign = side_sign,
		payload = {
			variant = pickup.Variant,
			subtype = pickup.SubType,
			landing_pos = landing_pos,
			player = player,
			resolved = false,
		},
		landing = false,
		land_fade = nil,
	}

	local next_pos = bezier3(p0, p1, p2, p3, 1 / item.flight_duration)
	heart.Velocity = next_pos - heart.Position
end

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, Function = function()
	for i = 0, Game():GetNumPlayers() - 1 do
		Game():GetPlayer(i):GetData()[item.own_key.."chance"] = nil
	end
end})

table.insert(item.pre_ToCall, {CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, Function = function(_, pickup, collider)
	local player = collider:ToPlayer()
	if not player or not COPYABLE_VARIANTS[pickup.Variant] then
		return
	end
	local chance = player:GetData()[item.own_key.."chance"]
	if not chance then return end
	local data = pickup:GetData()
	if data[item.own_key.."copy"] or data[item.own_key.."checked"] or pickup.Price ~= 0 or pickup.OptionsPickupIndex ~= 0 then return end
	if not auxi.will_pick_up(player, pickup) or not auxi.can_buy(pickup, player) then return end
	data[item.own_key.."checked"] = true
	local rng = auxi.rng_for_sake(player:GetCardRNG(item.entity))
	if rng:RandomFloat() >= chance then return end
	local angle = rng:RandomInt(360)
	local landing_pos = Game():GetRoom():FindFreePickupSpawnPosition(
		pickup.Position + auxi.MakeVector(angle) * 24,
		10,
		true
	)
	spawn_love_heart(player, pickup, landing_pos)
end})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_USE_CARD, params = item.entity, Function = function(_, cardtype, player, useFlags)
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then return end
	player:GetData()[item.own_key.."chance"] = player:GetData().tarot_cloth_used == cardtype and .75 or .5
end})

Nil_holder.register("card_06_lover_heart", {
	detect = function(d)
		return d[item.own_key.."love_fx"] ~= nil
	end,
	update = function(ent, d, s)
		local fx = d[item.own_key.."love_fx"]
		if not fx then
			ent:Remove()
			return
		end

		if fx.landing then
			fx.land_fade = (fx.land_fade or 0) + 1
			ent.Velocity = Vector.Zero
			ent.PositionOffset = Vector.Zero
			local u = math.min(1, fx.land_fade / item.land_fade_frames)
			-- 前半：轻微胀大 + aura 闪一下；后半：一起柔和收透明度，避免硬切。
			local heart_scale = smoothstep(0.72, 1.16, math.min(1, u / 0.55))
			local heart_alpha = 1 - smoothstep(0, 1, math.max(0, (u - 0.25) / 0.75))
			local aura_peak = smoothstep(0.55, 0.95, math.min(1, u / 0.22))
			local aura_alpha = aura_peak * (1 - smoothstep(0, 1, math.max(0, (u - 0.18) / 0.55)))
			apply_heart_visual(s, heart_scale, heart_alpha, 0, aura_alpha)
			if fx.land_fade >= item.land_fade_frames then
				ent:Remove()
			end
			return
		end

		local next_t = math.min(1, (fx.age + 1) / fx.duration)
		local next_pos = bezier3(fx.p0, fx.p1, fx.p2, fx.p3, next_t)
		ent.Velocity = next_pos - ent.Position

		local t = fx.age / fx.duration
		ent.PositionOffset = Vector(0, flight_lift(t))
		local rot = fx.side_sign * 7 * math.sin(math.pi * t)
		apply_heart_visual(s, flight_scale(t), 1, rot, flight_aura_alpha(t))

		fx.age = fx.age + 1
		if fx.age >= fx.duration then
			begin_landing(ent, d, s, fx)
		end
	end,
	remove = function(ent, d)
		local fx = d[item.own_key.."love_fx"]
		if fx and fx.payload and not fx.payload.resolved then
			resolve_love_copy(fx.payload, false)
		end
	end,
})

return item
