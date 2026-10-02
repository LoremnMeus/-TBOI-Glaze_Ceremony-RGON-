local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Lure,
	own_key = "Thoth_cd11_Lur_",
}

local OFFER_START_DISTANCE = 72
local OFFER_CANCEL_DISTANCE = 104
local OFFER_KEY = item.own_key.."offer"
local OFFER_SPRITE_CACHE_KEY = item.own_key.."offer_sprite_cache"

-- Room-local: marked, unsatisfied enemies that may become Offer targets.
local offer_targets = {}
local offer_target_count = 0

-- Shared static demand icons (Idle frame 0 only; never mutated at render time).
local WANT_SPRITES = {}

-- Indexed 1..4 for RandomInt(#WANTS)+1
-- gfx paths are real vanilla anm2 names (variant ids ≠ 20/30/40/10, not filenames).
local WANTS = {
	[1] = {
		variant = PickupVariant.PICKUP_COIN,
		subtype = CoinSubType.COIN_PENNY,
		gfx = "gfx/005.021_penny.anm2",
	},
	[2] = {
		variant = PickupVariant.PICKUP_KEY,
		subtype = KeySubType.KEY_NORMAL,
		gfx = "gfx/005.031_key.anm2",
	},
	[3] = {
		variant = PickupVariant.PICKUP_BOMB,
		subtype = BombSubType.BOMB_NORMAL,
		gfx = "gfx/005.041_bomb.anm2",
	},
	[4] = {
		variant = PickupVariant.PICKUP_HEART,
		subtype = HeartSubType.HEART_FULL,
		gfx = "gfx/005.011_heart.anm2",
	},
}

local function is_firing(player)
	return player:GetShootingInput():Length() > 0.1
		or player:GetFireDirection() ~= Direction.NO_DIRECTION
end

local function has_resource(player, id)
	if id == 1 then
		return player:GetNumCoins() > 0
	elseif id == 2 then
		return player:GetNumKeys() > 0
	elseif id == 3 then
		return player:GetNumBombs() > 0
	elseif id == 4 then
		return player:GetHearts() >= 2
	end
	return false
end

local function pay_resource(player, id)
	if id == 1 then
		player:AddCoins(-1)
	elseif id == 2 then
		player:AddKeys(-1)
	elseif id == 3 then
		player:AddBombs(-1)
	elseif id == 4 then
		player:AddHearts(-2)
	end
end

local function register_offer_target(npc)
	if not npc then
		return
	end
	local hash = GetPtrHash(npc)
	if offer_targets[hash] then
		return
	end
	offer_targets[hash] = npc
	offer_target_count = offer_target_count + 1
end

local function unregister_offer_target(npc_or_hash)
	local hash
	if type(npc_or_hash) == "number" then
		hash = npc_or_hash
	elseif npc_or_hash then
		hash = GetPtrHash(npc_or_hash)
	end
	if not hash or not offer_targets[hash] then
		return
	end
	offer_targets[hash] = nil
	offer_target_count = math.max(0, offer_target_count - 1)
end

local function clear_offer_targets()
	offer_targets = {}
	offer_target_count = 0
end

local function get_want_sprite(id)
	local sprite = WANT_SPRITES[id]
	if sprite then
		return sprite
	end
	local info = WANTS[id]
	if not info then
		return nil
	end
	sprite = Sprite()
	sprite:Load(info.gfx, true)
	sprite:SetFrame("Idle", 0)
	sprite.Scale = Vector(0.7, 0.7)
	WANT_SPRITES[id] = sprite
	return sprite
end

local function get_offer_sprite(player, id)
	local pd = player:GetData()
	local cache = pd[OFFER_SPRITE_CACHE_KEY]
	if not cache then
		cache = {}
		pd[OFFER_SPRITE_CACHE_KEY] = cache
	end
	local sprite = cache[id]
	if sprite then
		sprite:SetFrame("Idle", 0)
		sprite.Scale = Vector.One
		sprite.Rotation = 0
		sprite.Color = Color(1, 1, 1, 1)
		return sprite
	end
	local info = WANTS[id]
	if not info then
		return nil
	end
	sprite = Sprite()
	sprite:Load(info.gfx, true)
	sprite:SetFrame("Idle", 0)
	cache[id] = sprite
	return sprite
end

-- One-shot marking: context lives only for this USE_CARD call stack.
local function assign_want(npc, context)
	if not npc or not npc:IsActiveEnemy(false) or not npc:IsVulnerableEnemy() then
		return false
	end
	local d = npc:GetData()
	if d[item.own_key.."want"] then
		return false
	end
	local rng = auxi.rng_for_sake(npc:GetDropRNG())
	local id = rng:RandomInt(#WANTS) + 1
	d[item.own_key.."want"] = id
	d[item.own_key.."owner"] = context.owner
	d[item.own_key.."cloth"] = context.cloth
	d[item.own_key.."eligible"] = true
	d[item.own_key.."satisfied"] = nil
	register_offer_target(npc)
	return true
end

local function offer_distance(player, npc)
	local center = player.Position:Distance(npc.Position)
	return math.max(0, center - (player.Size or 0) - (npc.Size or 0))
end

local function npc_alive(npc)
	return auxi.check_all_exists(npc) and not npc:IsDead()
end

local function get_offer(player)
	return player:GetData()[OFFER_KEY]
end

-- room_change: hide without hunting a new target this frame.
local function cancel_offer(player, room_change)
	local pd = player:GetData()
	local offer = pd[OFFER_KEY]
	if not offer then
		return
	end
	if offer.sprite then
		player:AnimatePickup(offer.sprite, true, "HideItem")
	end
	pd[OFFER_KEY] = nil
end

local function finish_offer(player)
	local pd = player:GetData()
	local offer = pd[OFFER_KEY]
	if not offer then
		return
	end
	pd[OFFER_KEY] = nil
	player:AnimateHappy()
end

local function clear_all_offers(room_change)
	for i = 0, Game():GetNumPlayers() - 1 do
		cancel_offer(Game():GetPlayer(i), room_change)
	end
end

local function satisfy_enemy(npc)
	local d = npc:GetData()
	if d[item.own_key.."satisfied"] then
		return
	end
	d[item.own_key.."satisfied"] = true
	unregister_offer_target(npc)
	if not npc:IsBoss() then
		npc.CanShutDoors = false
	end
	npc:SetColor(Color(1, 0.82, 0.88, 1, 0.12, 0.02, 0.05), 30, 80, true, false)
end

-- Docs: true = ignore collision; false = physically collide but skip internal contact damage.
local function skip_contact_damage()
	return false
end

local function get_reward_count(npc, data, rng)
	if npc:IsBoss() then
		return 2
	end
	local chance = data[item.own_key.."cloth"] and 0.75 or 0.35
	if rng:RandomFloat() < chance then
		return 2
	end
	return 1
end

local function spawn_reward(npc)
	local d = npc:GetData()
	if d[item.own_key.."rewarded"] then
		return
	end
	if not d[item.own_key.."eligible"] or not d[item.own_key.."satisfied"] then
		return
	end
	local id = d[item.own_key.."want"]
	local info = id and WANTS[id]
	if not info then
		return
	end
	d[item.own_key.."rewarded"] = true

	local drop_rng = npc.GetDropRNG and npc:GetDropRNG() or nil
	local rng = auxi.rng_for_sake(drop_rng)
	if not rng then
		rng = RNG()
		rng:SetSeed(npc.InitSeed ~= 0 and npc.InitSeed or 1, 35)
	end

	local count = get_reward_count(npc, d, rng)
	local room = Game():GetRoom()
	local base = npc.Position
	for _ = 1, count do
		local vel = auxi.MakeVector(rng:RandomInt(360)) * (2 + rng:RandomFloat() * 2)
		local pos = room:FindFreePickupSpawnPosition(base, 0, true)
		Isaac.Spawn(
			EntityType.ENTITY_PICKUP,
			info.variant,
			info.subtype,
			pos,
			vel,
			nil
		)
	end
end

local function start_offer(player, npc, id)
	local pd = player:GetData()
	if pd[OFFER_KEY] then
		return
	end
	if player:IsHoldingItem() then
		return
	end
	if player:IsExtraAnimationFinished() ~= true then
		return
	end
	local sprite = get_offer_sprite(player, id)
	if not sprite then
		return
	end
	pd[OFFER_KEY] = {
		target = npc,
		target_hash = GetPtrHash(npc),
		want = id,
		sprite = sprite,
		lifting = true,
		ready = false,
	}
	player:AnimatePickup(sprite, true, "LiftItem")
end

local function find_offer_target(player)
	local best, best_dist
	local stale
	for hash, npc in pairs(offer_targets) do
		local valid = npc_alive(npc)
		local d
		if valid then
			d = npc:GetData()
			valid = d[item.own_key.."eligible"]
				and not d[item.own_key.."satisfied"]
				and d[item.own_key.."want"] ~= nil
		end
		if not valid then
			stale = stale or {}
			stale[#stale + 1] = hash
		else
			local id = d[item.own_key.."want"]
			if has_resource(player, id) then
				local dist = offer_distance(player, npc)
				if dist <= OFFER_START_DISTANCE and (not best_dist or dist < best_dist) then
					best, best_dist = npc, dist
				end
			end
		end
	end
	if stale then
		for i = 1, #stale do
			unregister_offer_target(stale[i])
		end
	end
	return best
end

local function update_offer(player)
	local offer = get_offer(player)
	if offer then
		local npc = offer.target
		local invalid = not npc_alive(npc)
			or GetPtrHash(npc) ~= offer.target_hash
			or npc:GetData()[item.own_key.."satisfied"]
			or not npc:GetData()[item.own_key.."eligible"]
			or npc:GetData()[item.own_key.."want"] ~= offer.want
			or not has_resource(player, offer.want)
			or is_firing(player)
			or offer_distance(player, npc) > OFFER_CANCEL_DISTANCE

		if invalid then
			cancel_offer(player)
			return
		end

		if offer.lifting then
			if player:IsHoldingItem() or player:IsExtraAnimationFinished() then
				offer.lifting = false
				offer.ready = true
			end
		end
		return
	end

	if offer_target_count <= 0 then
		return
	end
	if is_firing(player) then
		return
	end

	local target = find_offer_target(player)
	if target then
		start_offer(player, target, target:GetData()[item.own_key.."want"])
	end
end

local function get_want_render_pos(npc, render_offset)
	local world = npc.Position + (npc.PositionOffset or Vector.Zero)
	local anchor = ui.GetEntityHeadAnchor(npc, {
		top = true,
		centerX = true,
		paddingY = 8,
		-- Floating UI marker only; never texel/scalp scan.
		useTexel = false,
	})
	return Isaac.WorldToRenderPosition(world) + (render_offset or Vector.Zero) + anchor
end

local function want_bob(npc)
	-- Visual-only; do not touch DropRNG.
	-- Render ~60 Hz vs Game frame 30 Hz — drive with Isaac clock.
	local phase = (npc.InitSeed % 60) * 0.1
	local t = Isaac.GetFrameCount() * 0.06 + phase
	local y = math.sin(t) * 2
	return Vector(0, y)
end

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_ROOM,
	Function = function()
		clear_all_offers(true)
		clear_offer_targets()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	Function = function()
		clear_all_offers(true)
		clear_offer_targets()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PEFFECT_UPDATE,
	Function = function(_, player)
		update_offer(player)
	end,
})

table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_NPC_COLLISION,
	Function = function(_, npc, collider)
		local player = collider and collider:ToPlayer()
		if not player or player.Variant ~= 0 then
			return
		end
		local d = npc:GetData()
		if d[item.own_key.."eligible"] and d[item.own_key.."satisfied"] then
			return skip_contact_damage()
		end

		local id = d[item.own_key.."want"]
		if not id or not d[item.own_key.."eligible"] then
			return
		end

		local offer = get_offer(player)
		if not offer then
			return
		end
		if offer.target_hash ~= GetPtrHash(npc) or offer.want ~= id then
			return
		end
		if is_firing(player) or not has_resource(player, id) then
			return
		end

		pay_resource(player, id)
		satisfy_enemy(npc)
		finish_offer(player)
		return skip_contact_damage()
	end,
})

table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_PLAYER_COLLISION,
	Function = function(_, player, collider)
		if not player or player.Variant ~= 0 then
			return
		end
		local npc = collider and collider:ToNPC()
		local d = npc and npc:GetData()
		if d and d[item.own_key.."eligible"] and d[item.own_key.."satisfied"] then
			return skip_contact_damage()
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NPC_RENDER,
	Function = function(_, npc, offset)
		if offer_target_count <= 0 then
			return
		end
		if not offer_targets[GetPtrHash(npc)] then
			return
		end
		if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then
			return
		end
		local d = npc:GetData()
		local id = d[item.own_key.."want"]
		if not id
			or not d[item.own_key.."eligible"]
			or d[item.own_key.."satisfied"]
		then
			return
		end
		local sprite = get_want_sprite(id)
		if not sprite then
			return
		end
		sprite:Render(get_want_render_pos(npc, offset) + want_bob(npc), Vector.Zero, Vector.Zero)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_ENTITY_KILL,
	Function = function(_, ent)
		local npc = ent and ent:ToNPC()
		if npc then
			unregister_offer_target(npc)
			spawn_reward(npc)
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NPC_DEATH,
	Function = function(_, npc)
		unregister_offer_target(npc)
		spawn_reward(npc)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_USE_CARD,
	params = item.entity,
	Function = function(_, cardtype, player, useFlags)
		if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
			return
		end
		local context = {
			owner = player,
			cloth = player:GetData().tarot_cloth_used == cardtype,
		}
		local entities = Isaac.GetRoomEntities()
		for i = 1, #entities do
			local npc = entities[i]:ToNPC()
			if npc then
				assign_want(npc, context)
			end
		end
	end,
})

return item
