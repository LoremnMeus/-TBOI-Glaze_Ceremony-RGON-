local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")

-- X - 命运?：普通掉落 → Options 命运环；再次使用按「组」追加候选（非按组内实体）。
-- 软上限 64 / 硬上限 80；半径封顶。复用 Consistance + Option_Index，不新建 registry。

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Wheel_of_Destiny_r,
	own_key = "Thoth_cd10r_Whe_",
	check_variant = {
		[10] = true,
		[20] = true,
		[30] = true,
		[40] = true,
		[42] = true,
		[69] = true,
		[70] = true,
		[90] = true,
		[300] = true,
		[350] = true,
	},
}

local PICKUP_SOFT_CAP = 64
local PICKUP_HARD_CAP = 80

local function effect_store()
	save.elses[item.own_key .. "effect"] = save.elses[item.own_key .. "effect"] or {}
	return save.elses[item.own_key .. "effect"]
end

local function is_wheel_group(ndx)
	ndx = ndx or 0
	if ndx <= 0 then return false end
	local g = effect_store()[ndx]
	return type(g) == "table"
end

local function count_convertible_pickups()
	local count = 0
	for _, ent in ipairs(Isaac.GetRoomEntities()) do
		if ent.Type == EntityType.ENTITY_PICKUP and item.check_variant[ent.Variant] then
			count = count + 1
		end
	end
	return count
end

local function roll_add_count(rng, tarot_cloth)
	if tarot_cloth then
		return 5 + rng:RandomInt(3)
	end
	return 3 + rng:RandomInt(3)
end

local function get_soft_add_cap(room_count)
	if room_count < PICKUP_SOFT_CAP then
		return math.huge
	elseif room_count < 70 then
		return 4
	elseif room_count < 75 then
		return 3
	elseif room_count < 80 then
		return 2
	end
	return 0
end

-- 候选越多半径越大，但封顶以免甩出房间
local function get_group_radius(n)
	n = math.max(1, n or 1)
	return math.min(28 + n * 6, 96)
end

local function prune_group(group)
	if type(group) ~= "table" then return 0 end
	for i = #group, 1, -1 do
		local q = group[i]
		if auxi.check_all_exists(q) == false then
			table.remove(group, i)
		end
	end
	return #group
end

local function group_center(group)
	if type(group) ~= "table" or #group == 0 then return nil end
	if group.position then
		return Vector(group.position.X, group.position.Y)
	end
	local sum = Vector(0, 0)
	for i = 1, #group do
		sum = sum + group[i].Position
	end
	return sum / #group
end

local function group_price(group)
	for i = 1, #group do
		local q = group[i]
		if auxi.check_all_exists(q) and q.Price ~= nil then
			return q.Price
		end
	end
	return 0
end

--- 向已有 Options 组追加 count 个候选（与首次展开同一 Consistance / Spawn 语义）
local function spawn_group_members(ndx, count, center, price, player, rng)
	if count <= 0 or not center then return 0 end
	local store = effect_store()
	store[ndx] = store[ndx] or {}
	local group = store[ndx]
	local nidx = rng:RandomInt(360)
	local spawned = 0
	for i = 1, count do
		local ang = i * 360 / count + nidx
		local q = Isaac.Spawn(
			EntityType.ENTITY_PICKUP,
			0,
			1,
			center + auxi.MakeVector(ang) * 5,
			Vector(0, 0),
			player
		):ToPickup()
		q.OptionsPickupIndex = ndx
		q.Price = price
		consistance_holder.try_hold_entity(q, item.own_key)
		table.insert(group, #group + 1, q)
		spawned = spawned + 1
	end
	return spawned
end

local function expand_existing_group(ndx, add_count, player, rng)
	local store = effect_store()
	local group = store[ndx]
	if type(group) ~= "table" then return 0 end
	if prune_group(group) == 0 then
		store[ndx] = nil
		return 0
	end
	local center = group_center(group)
	if not center then return 0 end
	local price = group_price(group)
	return spawn_group_members(ndx, add_count, center, price, player, rng)
end

local function expand_new_pickup(pickup, actual_count, player, rng)
	if not pickup or not pickup.Exists or not pickup:Exists() then return 0 end
	local ndx = option_index_holder.find_a_new_index()
	local price = pickup.Price
	local pos = pickup.Position
	consistance_holder.try_remove_entity(pickup, item.own_key)
	local spawned = spawn_group_members(ndx, actual_count, pos, price, player, rng)
	pickup:Remove()
	return spawned
end

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	if continue then
	else
		save.elses[item.own_key .. "effect"] = {}
	end
	save.elses[item.own_key .. "effect"] = save.elses[item.own_key .. "effect"] or {}
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_NEW_LEVEL, params = nil,
Function = function(_)
	save.elses[item.own_key .. "effect"] = {}
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	local store = effect_store()
	for u, v in pairs(store) do
		if type(v) == "table" then
			local tg_pos = nil
			for i = #v, 1, -1 do
				local q = v[i]
				if auxi.check_all_exists(q) == false then
					table.remove(v, i)
				else
					tg_pos = (tg_pos or Vector(0, 0)) + q.Position
				end
			end
			if #v == 0 then
				store[u] = nil
			else
				tg_pos = tg_pos / (#v)
				v.position = (v.position or tg_pos) * 0.7 + tg_pos * 0.3
				if v.angle == nil then
					v.angle = v[1]:GetDropRNG():RandomInt(360)
				end
				v.angle = v.angle + 10
				local radius = get_group_radius(#v)
				for i = 1, #v do
					local q = v[i]
					q:GetData()[item.own_key .. "orderposition"] =
						v.position + auxi.MakeVector(i * 360 / (#v) + v.angle) * radius
				end
			end
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = nil,
Function = function(_, ent)
	if item.check_variant[ent.Variant] then
		local succ = consistance_holder.try_check_entity(ent, item.own_key)
		if succ then
			ent:GetData()[item.own_key .. "addme"] = true
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = nil,
Function = function(_, ent)
	if not item.check_variant[ent.Variant] then return end
	local d = ent:GetData()
	if d[item.own_key .. "orderposition"] then
		local dir = d[item.own_key .. "orderposition"] - ent.Position
		if dir:Length() > 0.1 then
			if ent.Price ~= 0 or (ent.Type == 20 and ent.Variant == 6) then
				ent.TargetPosition = ent.TargetPosition * 0.5 + d[item.own_key .. "orderposition"] * 0.5
			else
				ent.Velocity = dir:Normalized() * math.min(25, dir:Length() * 0.4)
			end
		end
		ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	end
	if d[item.own_key .. "addme"] then
		d[item.own_key .. "addme"] = nil
		local ndx = ent.OptionsPickupIndex
		if ndx and ndx > 0 then
			local store = effect_store()
			store[ndx] = store[ndx] or {}
			table.insert(store[ndx], #store[ndx] + 1, ent)
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_USE_CARD, params = item.entity,
Function = function(_, cardtype, player, useFlags)
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
		return
	end

	local d = player:GetData()
	local rng = auxi.rng_for_sake(player:GetCardRNG(item.entity))
	local tarot_cloth = d.tarot_cloth_used and d.tarot_cloth_used == cardtype
	local store = effect_store()

	local room_count = count_convertible_pickups()
	local new_pickups = {}
	local existing_groups = {}

	for _, ent in ipairs(Isaac.GetRoomEntities()) do
		if ent.Type == EntityType.ENTITY_PICKUP and item.check_variant[ent.Variant] then
			local p = ent:ToPickup()
			if p then
				local ndx = p.OptionsPickupIndex or 0
				if is_wheel_group(ndx) then
					existing_groups[ndx] = true
				elseif ndx <= 0 then
					table.insert(new_pickups, p)
				end
				-- ndx > 0 且非本卡命运组：跳过，不篡改
			end
		end
	end

	-- 1) 优先强化已有命运组（每 ndx 一次）
	for ndx in pairs(existing_groups) do
		if room_count >= PICKUP_HARD_CAP then
			break
		end
		local rolled = roll_add_count(rng, tarot_cloth)
		local soft_cap = get_soft_add_cap(room_count)
		local hard_budget = PICKUP_HARD_CAP - room_count
		local actual_add = math.min(rolled, soft_cap, hard_budget)
		if actual_add > 0 then
			local added = expand_existing_group(ndx, actual_add, player, rng)
			room_count = room_count + added
		end
	end

	-- 2) 再展开新的普通掉落
	for _, pickup in ipairs(new_pickups) do
		if room_count >= PICKUP_HARD_CAP then
			break
		end
		if pickup and pickup.Exists and pickup:Exists() then
			local rolled = roll_add_count(rng, tarot_cloth)
			local soft_cap = get_soft_add_cap(room_count)
			local hard_cap = 1 + PICKUP_HARD_CAP - room_count
			local actual_count = math.min(rolled, soft_cap, hard_cap)
			if actual_count >= 2 then
				local spawned = expand_new_pickup(pickup, actual_count, player, rng)
				if spawned > 0 then
					room_count = room_count - 1 + spawned
				end
			end
		end
	end
end,
})

return item
