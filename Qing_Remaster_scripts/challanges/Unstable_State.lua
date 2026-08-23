local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")

local item = {
	ToCall = {},
	entity = enums.Challenges.Unstable_State,
	own_key = "Challange_Unstable_State_",
	drop_count = 3,
	icon_spr = Sprite(),
	icon_id = nil,
}

local TAG_QUEST = ItemConfig.TAG_QUEST or (1 << 15)

local function is_droppable(id)
	id = tonumber(id)
	if not id or id <= 0 then return false end
	local cfg = Isaac.GetItemConfig():GetCollectible(id)
	if not cfg or cfg.Hidden then return false end
	if cfg:HasTags(TAG_QUEST) then return false end
	return cfg.Type == ItemType.ITEM_PASSIVE or cfg.Type == ItemType.ITEM_FAMILIAR
end

local function owned_passives(player)
	local tbl = {}
	local itemConfig = Isaac.GetItemConfig()
	local sz = itemConfig:GetCollectibles().Size
	for i = 1, sz do
		if is_droppable(i) then
			local n = player:GetCollectibleNum(i, true)
			for _ = 1, n do
				tbl[#tbl + 1] = i
			end
		end
	end
	return tbl
end

local function take_random(list, rng, count)
	local out = {}
	local n = math.min(count, #list)
	for _ = 1, n do
		local idx = rng:RandomInt(#list) + 1
		out[#out + 1] = list[idx]
		table.remove(list, idx)
	end
	return out
end

local function spawn_dropped(player, id)
	local room = Game():GetRoom()
	local pos = room:FindFreePickupSpawnPosition(player.Position, 40, true)
	local q = Isaac.Spawn(5, 100, id, pos, Vector(0, 0), player):ToPickup()
	if not q then return end
	q.Touched = true
	q.Wait = 20
	q:GetData()[item.own_key.."drop"] = true
end

local function steal_pickup(npc, pickup)
	local id = pickup.SubType
	if not id or id <= 0 then return end
	local d = npc:GetData()
	if d[item.own_key.."stolen"] then return end
	d[item.own_key.."stolen"] = id
	d[item.own_key.."base_hp"] = npc.MaxHitPoints
	npc.MaxHitPoints = npc.MaxHitPoints * 1.5
	npc.HitPoints = npc.HitPoints * 1.5
	pickup:Remove()
end

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG, params = EntityType.ENTITY_PLAYER,
Function = function(_, ent, amt, flag, source, cooldown)
	if Game().Challenge ~= item.entity then return end
	if (amt or 0) <= 0 then return end
	local player = ent:ToPlayer()
	if not player then return end
	if not auxi.is_damage_from_enemy(ent, amt, flag, source, cooldown) then return end
	delay_buffer.addeffe(function()
		if not player or player:IsDead() or not player:Exists() then return end
		local rng = player:GetDropRNG()
		local pool = owned_passives(player)
		local dropped = take_random(pool, rng, item.drop_count)
		for i = 1, #dropped do
			player:RemoveCollectible(dropped[i])
			spawn_dropped(player, dropped[i])
		end
	end, {}, 1)
end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_NPC_UPDATE, params = nil,
Function = function(_, npc)
	if Game().Challenge ~= item.entity then return end
	if not npc or not npc:IsVulnerableEnemy() or npc:IsBoss() then return end
	if npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then return end
	local d = npc:GetData()
	local stolen = d[item.own_key.."stolen"]
	if stolen then
		npc.Velocity = npc.Velocity * 1.2
		local cd = npc.ProjectileCooldown
		if type(cd) == "number" then
			if cd > (d[item.own_key.."last_cd"] or 0) + 2 then
				npc.ProjectileCooldown = math.max(1, math.floor(cd * 0.8))
			end
			d[item.own_key.."last_cd"] = npc.ProjectileCooldown
		end
		return
	end
	local pickups = Isaac.FindInRadius(npc.Position, npc.Size + 20, EntityPartition.PICKUP)
	for i = 1, #pickups do
		local pickup = pickups[i]:ToPickup()
		if pickup and pickup.Variant == PickupVariant.PICKUP_COLLECTIBLE and pickup:GetData()[item.own_key.."drop"] and pickup.SubType > 0 then
			steal_pickup(npc, pickup)
			break
		end
	end
end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_NPC_DEATH, params = nil,
Function = function(_, npc)
	if Game().Challenge ~= item.entity then return end
	local d = npc:GetData()
	local id = d[item.own_key.."stolen"]
	if not id then return end
	local room = Game():GetRoom()
	local q = Isaac.Spawn(5, 100, id, room:FindFreePickupSpawnPosition(npc.Position, 10, true), Vector(0, 0), nil):ToPickup()
	if q then
		q.Touched = true
		q.Wait = 10
		q:GetData()[item.own_key.."drop"] = true
	end
end,
})

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_NPC_RENDER, params = nil,
Function = function(_, npc, offset)
	if Game().Challenge ~= item.entity then return end
	if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
	local id = npc:GetData()[item.own_key.."stolen"]
	if not id then return end
	if item.icon_id ~= id then
		auxi.load_item(id, {sprite = item.icon_spr})
		item.icon_id = id
	end
	item.icon_spr.Scale = Vector(0.5, 0.5)
	item.icon_spr.Color = Color(1, 1, 1, 0.9)
	local pos = Isaac.WorldToScreen(npc.Position + (npc.PositionOffset or Vector(0, 0))) + (offset or Vector(0, 0)) + Vector(0, -28)
	item.icon_spr:Render(pos, Vector(0, 0), Vector(0, 0))
end,
})

return item
