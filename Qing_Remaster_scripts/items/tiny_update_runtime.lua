-- Tiny Update run ledger.
-- Stat eligibility is ItemConfig.CacheFlags / TAG_TEARS_UP, not a handwritten item list.
-- Heart containers follow AddMaxHearts. Charges follow fixed normal MaxCharges.
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local runtime = {
	STAT_STEP = 0.1,
	STAT_LIMIT = 5,
	CHARGE_LIMIT = 2,
	FLOOR_CHANCE = 0.5,
	ROOM_CHANCE = 0.15,
	POOL_SHARE = 0.2,
	SECOND_CHANCE = 35,
	STAT_BUFF_CHANCE = 55,
	WEIGHT_STEP = 0.5,
	WEIGHT_SPAN = 2.0,
	WEIGHT_FLOOR = 0.1,
}

local STATS = {
	{key = "damage", flag = CacheFlag.CACHE_DAMAGE},
	{key = "tears", flag = CacheFlag.CACHE_FIREDELAY, tag = "TAG_TEARS_UP"},
	{key = "shot_speed", flag = CacheFlag.CACHE_SHOTSPEED},
	{key = "range", flag = CacheFlag.CACHE_RANGE},
	{key = "speed", flag = CacheFlag.CACHE_SPEED},
	{key = "luck", flag = CacheFlag.CACHE_LUCK},
}

local LEGAL_POOLS = {
	ItemPoolType.POOL_TREASURE,
	ItemPoolType.POOL_SHOP,
	ItemPoolType.POOL_BOSS,
	ItemPoolType.POOL_DEVIL,
	ItemPoolType.POOL_ANGEL,
	ItemPoolType.POOL_SECRET,
	ItemPoolType.POOL_LIBRARY,
	ItemPoolType.POOL_CURSE,
	ItemPoolType.POOL_PLANETARIUM,
	ItemPoolType.POOL_GOLDEN_CHEST,
}

local POOL_NAME = {
	[ItemPoolType.POOL_TREASURE] = {zh = "宝箱房道具池", en = "Treasure Room Pool"},
	[ItemPoolType.POOL_SHOP] = {zh = "商店道具池", en = "Shop Pool"},
	[ItemPoolType.POOL_BOSS] = {zh = "Boss房道具池", en = "Boss Room Pool"},
	[ItemPoolType.POOL_DEVIL] = {zh = "恶魔房道具池", en = "Devil Room Pool"},
	[ItemPoolType.POOL_ANGEL] = {zh = "天使房道具池", en = "Angel Room Pool"},
	[ItemPoolType.POOL_SECRET] = {zh = "隐藏房道具池", en = "Secret Room Pool"},
	[ItemPoolType.POOL_LIBRARY] = {zh = "图书馆道具池", en = "Library Pool"},
	[ItemPoolType.POOL_CURSE] = {zh = "诅咒房道具池", en = "Curse Room Pool"},
	[ItemPoolType.POOL_PLANETARIUM] = {zh = "星象房道具池", en = "Planetarium Pool"},
	[ItemPoolType.POOL_GOLDEN_CHEST] = {zh = "金箱子道具池", en = "Golden Chest Pool"},
}

-- Captured before any MaxCharges write. ItemConfig resets from XML on a new Lua state.
local charge_original = {}
local eid_cache = {version = -1, lines = {}}

local function key_of(id)
	return tostring(id)
end

local function cfg_of(id)
	if not id or id <= 0 then return nil end
	local cfg = Isaac.GetItemConfig():GetCollectible(id)
	if cfg == nil then return nil end
	return cfg
end

local function is_quest(cfg)
	local tag = ItemConfig.TAG_QUEST
	if not cfg or not tag or not cfg.Tags then return false end
	return (cfg.Tags & tag) == tag
end

local function has_flag(cfg, flag)
	if not cfg or not flag or not cfg.CacheFlags then return false end
	return (cfg.CacheFlags & flag) ~= 0
end

local function has_named_tag(cfg, name)
	local tag = name and ItemConfig[name]
	if not cfg or not tag or not cfg.Tags then return false end
	return (cfg.Tags & tag) ~= 0
end

function runtime.state()
	save.elses.tiny_update = save.elses.tiny_update or {
		schema = 1,
		version = 0,
		floor_key = "",
		stats = {},
		hearts = {},
		charges = {},
		pool_added = {},
		custom = {},
		history = nil,
	}
	local st = save.elses.tiny_update
	st.stats = st.stats or {}
	st.hearts = st.hearts or {}
	st.soul_hearts = st.soul_hearts or {}
	st.black_hearts = st.black_hearts or {}
	st.charges = st.charges or {}
	st.timed_charges = st.timed_charges or {}
	st.pool_added = st.pool_added or {}
	st.custom = st.custom or {}
	st.version = st.version or 0
	st.floor_key = st.floor_key or ""
	st.floor_entry_roll_key = st.floor_entry_roll_key or ""
	st.room_update_floor_key = st.room_update_floor_key or ""
	st.item_patch_versions = st.item_patch_versions or {}
	st.charge_applied = st.charge_applied or {}
	st.charge_acquire = st.charge_acquire or {}
	if runtime.migrate_ledgers then runtime.migrate_ledgers(st) end
	if runtime.migrate_charge_adjust then runtime.migrate_charge_adjust(st) end
	if runtime.migrate_floor_marks then runtime.migrate_floor_marks(st) end
	return st
end

function runtime.legacy_floor_key()
	local level = Game():GetLevel()
	local dim = 0
	if level.GetDimension then
		dim = level:GetDimension() or 0
	end
	return tostring(level:GetStage()) .. ":" .. tostring(level:GetStageType()) .. ":" .. tostring(dim)
end

function runtime.floor_key()
	local level = Game():GetLevel()
	local dim = 0
	if level.GetDimension then
		dim = level:GetDimension() or 0
	end
	local seed = 0
	if level.GetDungeonPlacementSeed then
		seed = level:GetDungeonPlacementSeed() or 0
	end
	return tostring(seed) .. ":" .. tostring(dim) .. ":" .. tostring(level:GetStage()) .. ":" .. tostring(level:GetStageType())
end

function runtime.migrate_floor_marks(st)
	if st.floor_schema == 2 then return end
	if st.floor_key and st.floor_key ~= "" and st.floor_key == runtime.legacy_floor_key() then
		st.room_update_floor_key = runtime.floor_key()
	end
	st.floor_schema = 2
end

function runtime.floor_chance()
	if runtime.copies() <= 0 then return 0 end
	return runtime.FLOOR_CHANCE
end

function runtime.room_chance()
	if runtime.copies() <= 0 then return 0 end
	return runtime.ROOM_CHANCE
end

function runtime.copies()
	local total = 0
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Isaac.GetPlayer(i)
		if player then
			total = total + player:GetCollectibleNum(enums.Items.Tiny_Update, true)
		end
	end
	return total
end

local function charge_base(id, cfg)
	local key = key_of(id)
	if charge_original[key] == nil then
		charge_original[key] = (cfg and cfg.MaxCharges) or 0
	end
	return charge_original[key]
end

local function full_hearts(half)
	half = tonumber(half) or 0
	if half < 2 then return 0 end
	return math.floor(half / 2)
end

local function charge_type_of(cfg)
	return cfg and cfg.ChargeType or 0
end

local function charge_normal_allowed(id, cfg)
	if not cfg or cfg.Type ~= ItemType.ITEM_ACTIVE then return false end
	if charge_type_of(cfg) ~= (ItemConfig.CHARGE_NORMAL or 0) then return false end
	local base = charge_base(id, cfg)
	return base >= 1 and base <= 12
end

local function charge_timed_allowed(id, cfg)
	if not cfg or cfg.Type ~= ItemType.ITEM_ACTIVE then return false end
	if charge_type_of(cfg) ~= (ItemConfig.CHARGE_TIMED or 1) then return false end
	return charge_base(id, cfg) >= 30
end

function runtime.migrate_ledgers(st)
	st.soul_hearts = st.soul_hearts or {}
	st.black_hearts = st.black_hearts or {}
	st.timed_charges = st.timed_charges or {}
	st.heart_schema = 2
	if st.charge_schema == 3 then return end
	for item_key, steps in pairs(st.charges or {}) do
		local id = tonumber(item_key)
		local cfg = cfg_of(id)
		if not charge_normal_allowed(id, cfg) then
			st.charges[item_key] = nil
		else
			local base = charge_base(id, cfg)
			local nxt = math.floor(tonumber(steps) or 0)
			local min_steps = math.max(-runtime.CHARGE_LIMIT, 1 - base)
			local max_steps = math.min(runtime.CHARGE_LIMIT, 12 - base)
			if nxt < min_steps then nxt = min_steps end
			if nxt > max_steps then nxt = max_steps end
			if nxt == 0 then
				st.charges[item_key] = nil
			else
				st.charges[item_key] = nxt
			end
		end
	end
	st.charge_schema = 3
end

function runtime.charge_delta(id)
	local st = runtime.state()
	local cfg = cfg_of(id)
	if not cfg then return nil end
	local key = key_of(id)
	if charge_normal_allowed(id, cfg) then
		local steps = st.charges[key] or 0
		if steps == 0 then return nil end
		return steps, 1, 12
	end
	if charge_timed_allowed(id, cfg) then
		local steps = st.timed_charges[key] or 0
		if steps == 0 then return nil end
		return steps * 30, 30, nil
	end
	return nil
end

function runtime.axes(id)
	local cfg = cfg_of(id)
	if not cfg or id == enums.Items.Tiny_Update or is_quest(cfg) then return nil end
	local axes = {}
	if cfg.Type == ItemType.ITEM_ACTIVE then
		if charge_normal_allowed(id, cfg) then
			axes[#axes + 1] = {kind = "charge_normal", base = charge_base(id, cfg)}
		elseif charge_timed_allowed(id, cfg) then
			axes[#axes + 1] = {kind = "charge_timed", base = charge_base(id, cfg)}
		end
	else
		for i = 1, #STATS do
			local stat = STATS[i]
			if has_flag(cfg, stat.flag) or has_named_tag(cfg, stat.tag) then
				axes[#axes + 1] = {kind = "stat", key = stat.key}
			end
		end
		local red = full_hearts(cfg.AddMaxHearts)
		if red > 0 then
			axes[#axes + 1] = {kind = "hearts", base = red}
		end
		local soul = full_hearts(cfg.AddSoulHearts)
		if soul > 0 then
			axes[#axes + 1] = {kind = "soul_hearts", base = soul}
		end
		local black = full_hearts(cfg.AddBlackHearts)
		if black > 0 then
			axes[#axes + 1] = {kind = "black_hearts", base = black}
		end
	end
	if #axes == 0 then return nil end
	return axes
end

local function stat_steps(st, id, stat_key)
	local rec = st.stats[key_of(id)]
	return rec and rec[stat_key] or 0
end

local function can_stat(st, id, stat_key, sign)
	local nxt = stat_steps(st, id, stat_key) + sign
	return nxt <= runtime.STAT_LIMIT and nxt >= -runtime.STAT_LIMIT
end

local function heart_bucket(st, kind)
	if kind == "soul_hearts" then return st.soul_hearts end
	if kind == "black_hearts" then return st.black_hearts end
	return st.hearts
end

local function can_hearts(st, id, kind, base, sign)
	local nxt = (heart_bucket(st, kind)[key_of(id)] or 0) + sign
	local result = base + nxt
	return result >= 0 and result <= base + 1
end

local function can_charge_normal(st, id, base, sign)
	local nxt = (st.charges[key_of(id)] or 0) + sign
	if nxt > runtime.CHARGE_LIMIT or nxt < -runtime.CHARGE_LIMIT then return false end
	local result = base + nxt
	return result >= 1 and result <= 12
end

local function can_charge_timed(st, id, base, sign)
	local nxt = (st.timed_charges[key_of(id)] or 0) + sign
	if nxt > runtime.CHARGE_LIMIT or nxt < -runtime.CHARGE_LIMIT then return false end
	local result = base + nxt * 30
	return result >= 30
end

local function axis_can(st, id, axis, sign)
	if axis.kind == "stat" then return can_stat(st, id, axis.key, sign) end
	if axis.kind == "hearts" or axis.kind == "soul_hearts" or axis.kind == "black_hearts" then
		return can_hearts(st, id, axis.kind, axis.base, sign)
	end
	if axis.kind == "charge_normal" then return can_charge_normal(st, id, axis.base, sign) end
	if axis.kind == "charge_timed" then return can_charge_timed(st, id, axis.base, sign) end
	return false
end

local function apply_axis(st, id, axis, sign)
	local item_key = key_of(id)
	if axis.kind == "stat" then
		st.stats[item_key] = st.stats[item_key] or {}
		st.stats[item_key][axis.key] = stat_steps(st, id, axis.key) + sign
		return {kind = axis.key, steps = sign}
	end
	if axis.kind == "hearts" or axis.kind == "soul_hearts" or axis.kind == "black_hearts" then
		local bucket = heart_bucket(st, axis.kind)
		bucket[item_key] = (bucket[item_key] or 0) + sign
		return {kind = axis.kind, steps = sign}
	end
	if axis.kind == "charge_timed" then
		st.timed_charges[item_key] = (st.timed_charges[item_key] or 0) + sign
		return {kind = "charge_timed", steps = sign}
	end
	st.charges[item_key] = (st.charges[item_key] or 0) + sign
	return {kind = "charge_normal", steps = sign}
end

local function sign_for(rng, axis, category)
	local charge_axis = axis.kind == "charge_normal" or axis.kind == "charge_timed" or axis.kind == "charge"
	if category == "buff" then
		return charge_axis and -1 or 1
	end
	if category == "nerf" then
		return charge_axis and 1 or -1
	end
	if axis.kind == "stat" then
		return rng:RandomInt(100) < runtime.STAT_BUFF_CHANCE and 1 or -1
	end
	if charge_axis then
		return rng:RandomInt(100) < 50 and -1 or 1
	end
	return rng:RandomInt(100) < 50 and 1 or -1
end

local function pick_axis(rng, axes, used)
	local open = {}
	for i = 1, #axes do
		if not used[i] then open[#open + 1] = i end
	end
	if #open == 0 then return nil end
	return open[rng:RandomInt(#open) + 1]
end

local function custom_root()
	local root = save.elses["Itempool_h_effect"]
	if type(root) ~= "table" then return nil end
	return root
end

local function list_count(list)
	local count = 0
	for _, entry in pairs(list) do
		if entry ~= nil then count = count + 1 end
	end
	return count
end

local function find_custom(list, id)
	if type(list) ~= "table" then return nil end
	local direct = list[id] or list[key_of(id)]
	if type(direct) == "table" then return id, direct end
	for k, entry in pairs(list) do
		if type(entry) == "table" and (entry.id == id or entry.itemID == id) then
			return k, entry
		end
	end
	return nil
end

local function entry_weight(entry)
	if type(entry) ~= "table" then return 1 end
	return entry.weigh or entry.weight or 1
end

local function set_entry_weight(entry, value)
	if entry.weigh ~= nil or entry.weight == nil then
		entry.weigh = value
	else
		entry.weight = value
	end
end

local function peek_custom(st, pool_name, id)
	local bucket = st.custom[pool_name]
	return bucket and bucket[key_of(id)] or nil
end

local function store_custom(st, pool_name, id, rec)
	st.custom[pool_name] = st.custom[pool_name] or {}
	st.custom[pool_name][key_of(id)] = rec
end

local function weight_target(base, steps)
	local value = (tonumber(base) or 1) + (tonumber(steps) or 0) * runtime.WEIGHT_STEP
	if value < runtime.WEIGHT_FLOOR then value = runtime.WEIGHT_FLOOR end
	return value
end

local function migrate_custom(rec, entry)
	if not rec or rec.base_initialized then return end
	rec.base = entry and entry_weight(entry) or rec.base or 1
	rec.steps = 0
	rec.base_initialized = true
end

local function weight_can(rec, sign)
	local nxt = (rec.steps or 0) + sign
	if math.abs(nxt * runtime.WEIGHT_STEP) > runtime.WEIGHT_SPAN + 0.001 then return false end
	local now = weight_target(rec.base, rec.steps or 0)
	local after = weight_target(rec.base, nxt)
	return math.abs(after - now) > 0.001
end

local function try_custom_pool(rng, st, id)
	local root = custom_root()
	if not root then return nil end
	local names = {}
	for name, pool in pairs(root) do
		if type(pool) == "table" and type(pool.list) == "table" then
			names[#names + 1] = name
		end
	end
	if #names == 0 then return nil end
	local pool_name = names[rng:RandomInt(#names) + 1]
	local list = root[pool_name].list
	local found_key, entry = find_custom(list, id)
	local previous = peek_custom(st, pool_name, id)
	local rec = previous and {
		base = previous.base,
		steps = previous.steps,
		state = previous.state,
		base_initialized = previous.base_initialized,
	} or {base = 1, steps = 0, state = "normal", base_initialized = false}
	migrate_custom(rec, entry)
	local options = {}
	local weight_sign = 1
	if found_key and rec.state ~= "removed" then
		if list_count(list) > 1 then options[#options + 1] = "remove" end
		weight_sign = rng:RandomInt(100) < 50 and 1 or -1
		if not weight_can(rec, weight_sign) then
			weight_sign = -weight_sign
		end
		if weight_can(rec, weight_sign) then
			options[#options + 1] = "weight"
		end
	elseif not found_key then
		options[#options + 1] = "add"
	end
	if #options == 0 then return nil end
	local choice = options[rng:RandomInt(#options) + 1]
	if choice == "add" then
		list[id] = {id = id, weigh = 1}
		local _, written = find_custom(list, id)
		if not written or math.abs(entry_weight(written) - 1) > 0.001 then
			if found_key then list[found_key] = entry end
			list[id] = nil
			return nil
		end
		store_custom(st, pool_name, id, {base = 1, steps = 0, state = "added", base_initialized = true})
		return {kind = "pool_add", pool_name = pool_name, weight = 1}
	end
	if choice == "remove" then
		list[found_key] = nil
		if find_custom(list, id) then
			list[found_key] = entry
			return nil
		end
		rec.state = "removed"
		store_custom(st, pool_name, id, rec)
		return {kind = "pool_remove", pool_name = pool_name}
	end
	local before = weight_target(rec.base, rec.steps or 0)
	if not weight_can(rec, weight_sign) then return nil end
	local next_steps = (rec.steps or 0) + weight_sign
	local after = weight_target(rec.base, next_steps)
	set_entry_weight(entry, after)
	local _, checked = find_custom(list, id)
	if not checked or math.abs(entry_weight(checked) - after) > 0.001 then
		if entry then set_entry_weight(entry, before) end
		return nil
	end
	rec.steps = next_steps
	rec.state = rec.state == "added" and "added" or "normal"
	store_custom(st, pool_name, id, rec)
	return {kind = "pool_weight", pool_name = pool_name, from = before, to = after, steps = weight_sign}
end

local function query_pool_rows(pool_type)
	local item_pool = Game():GetItemPool()
	if not item_pool or not item_pool.GetCollectiblesFromPool then return nil end
	local ok, rows = pcall(function()
		return item_pool:GetCollectiblesFromPool(pool_type)
	end)
	if not ok or type(rows) ~= "table" then return nil end
	local list = {}
	for _, row in pairs(rows) do
		if type(row) == "table" then
			local item_id = row.itemID or row.ItemID or row.itemId
			if item_id then
				list[#list + 1] = {
					itemID = item_id,
					weight = row.weight or row.Weight,
					initialWeight = row.initialWeight or row.InitialWeight,
					decreaseBy = row.decreaseBy or row.DecreaseBy,
					removeOn = row.removeOn or row.RemoveOn,
					raw = row,
				}
			end
		end
	end
	return list
end

local function rows_for_item(pool_type, id)
	local rows = query_pool_rows(pool_type)
	if not rows then return nil end
	local found = {}
	for i = 1, #rows do
		if rows[i].itemID == id then found[#found + 1] = rows[i] end
	end
	return found
end

local function pool_rows(pool_type)
	local rows = query_pool_rows(pool_type) or {}
	local set = {}
	for i = 1, #rows do set[rows[i].itemID] = true end
	return set
end

local function vanilla_record(st, pool_type, id)
	local pool_key = key_of(pool_type)
	st.pool_added[pool_key] = st.pool_added[pool_key] or {}
	return st.pool_added[pool_key][key_of(id)]
end

local function try_vanilla_pool(rng, st, id, cfg)
	if is_quest(cfg) or cfg.Hidden == true then return nil end
	local item_pool = Game():GetItemPool()
	if item_pool.CanSpawnCollectible then
		local ok, allowed = pcall(function()
			return item_pool:CanSpawnCollectible(id, false)
		end)
		if ok and allowed == false then return nil end
	end
	local present = {}
	for i = 1, #LEGAL_POOLS do
		present[LEGAL_POOLS[i]] = pool_rows(LEGAL_POOLS[i])
	end
	local adds = {}
	local removes = {}
	for i = 1, #LEGAL_POOLS do
		local pool_type = LEGAL_POOLS[i]
		local existing = vanilla_record(st, pool_type, id)
		if existing then
			removes[#removes + 1] = {pool = pool_type, record = existing}
		elseif not present[pool_type][id] then
			adds[#adds + 1] = pool_type
		end
	end
	if #adds == 0 and #removes == 0 then return nil end
	local remove = #removes > 0 and (#adds == 0 or rng:RandomInt(100) < 50)
	if remove then
		local picked = removes[rng:RandomInt(#removes) + 1]
		if not item_pool.RemoveTemporaryCollectible then return nil end
		local before = rows_for_item(picked.pool, id)
		if not before then return nil end
		local ok = pcall(function()
			item_pool:RemoveTemporaryCollectible(picked.pool, picked.record)
		end)
		local after = rows_for_item(picked.pool, id)
		if not ok or not after or #after > 0 or #after >= #before then
			return nil
		end
		st.pool_added[key_of(picked.pool)][key_of(id)] = nil
		return {kind = "pool_remove", pool = picked.pool}
	end
	if #adds == 0 or not item_pool.AddTemporaryCollectible then return nil end
	local pool_type = adds[rng:RandomInt(#adds) + 1]
	local before = rows_for_item(pool_type, id)
	if not before or #before > 0 then return nil end
	local record = {itemID = id, weight = 1, decreaseBy = 1, removeOn = 0.1}
	local ok = pcall(function()
		item_pool:AddTemporaryCollectible(pool_type, record)
	end)
	local after = rows_for_item(pool_type, id)
	if not ok or not after or #after < 1 then return nil end
	st.pool_added[key_of(pool_type)] = st.pool_added[key_of(pool_type)] or {}
	st.pool_added[key_of(pool_type)][key_of(id)] = record
	return {kind = "pool_add", pool = pool_type, weight = 1}
end

local function try_pool(rng, st, id)
	local cfg = cfg_of(id)
	if not cfg then return nil end
	return try_vanilla_pool(rng, st, id, cfg)
end

local function numeric_candidates(st)
	local list = {}
	local size = Isaac.GetItemConfig():GetCollectibles().Size
	for id = 1, size do
		local axes = runtime.axes(id)
		if axes then
			local movable = false
			for i = 1, #axes do
				if axis_can(st, id, axes[i], 1) or axis_can(st, id, axes[i], -1) then
					movable = true
					break
				end
			end
			if movable then list[#list + 1] = id end
		end
	end
	return list
end

local function pool_candidates()
	local list = {}
	local size = Isaac.GetItemConfig():GetCollectibles().Size
	for id = 1, size do
		local cfg = cfg_of(id)
		if cfg and id ~= enums.Items.Tiny_Update and not is_quest(cfg) and cfg.Hidden ~= true then
			list[#list + 1] = id
		end
	end
	return list
end

local function take_unique(rng, source, count, used)
	local bag = {}
	for i = 1, #source do
		if not used[source[i]] then bag[#bag + 1] = source[i] end
	end
	local picked = {}
	while #picked < count and #bag > 0 do
		local index = rng:RandomInt(#bag) + 1
		picked[#picked + 1] = bag[index]
		used[bag[index]] = true
		table.remove(bag, index)
	end
	return picked
end

local function commit_numeric(rng, st, id, category)
	local axes = runtime.axes(id)
	if not axes then return nil end
	local used = {}
	local changes = {}
	local function once()
		local index = pick_axis(rng, axes, used)
		if not index then return false end
		used[index] = true
		local axis = axes[index]
		local sign = sign_for(rng, axis, category)
		if not axis_can(st, id, axis, sign) then
			if category == "buff" or category == "nerf" or not axis_can(st, id, axis, -sign) then
				return false
			end
			sign = -sign
		end
		changes[#changes + 1] = apply_axis(st, id, axis, sign)
		return true
	end
	if not once() then return nil end
	if #axes >= 2 and rng:RandomInt(100) < runtime.SECOND_CHANCE then
		once()
	end
	if #changes == 0 then return nil end
	return changes
end

local function shuffle_take(rng, list, count)
	local used = {}
	return take_unique(rng, list, count, used)
end

function runtime.make_rng(seed, player)
	if seed and seed > 0 then
		local rng = RNG()
		rng:SetSeed(seed, 35)
		return rng, "fixed_debug", nil
	end
	local owner = nil
	if player and player:GetCollectibleNum(enums.Items.Tiny_Update, true) > 0 then
		owner = player
	else
		for i = 0, Game():GetNumPlayers() - 1 do
			local candidate = Isaac.GetPlayer(i)
			if candidate and candidate:GetCollectibleNum(enums.Items.Tiny_Update, true) > 0 then
				owner = candidate
				break
			end
		end
	end
	if not owner then return nil, "no_holder", nil end
	return owner:GetCollectibleRNG(enums.Items.Tiny_Update), "collectible_direct", owner
end

local commit_trace = {}
local notice_receipt = nil

local function player_slot(player)
	if not player then return nil end
	local want = GetPtrHash(player)
	for i = 0, Game():GetNumPlayers() - 1 do
		local candidate = Isaac.GetPlayer(i)
		if candidate and GetPtrHash(candidate) == want then return i end
	end
	return nil
end

local function change_brief(change)
	return table.concat({
		tostring(change.kind),
		tostring(change.steps or ""),
		tostring(change.pool or ""),
	}, ":")
end

function runtime.entries_brief(entries)
	local rows = {}
	for i = 1, #(entries or {}) do
		local entry = entries[i]
		local parts = {tostring(entry.item_id)}
		for j = 1, #(entry.changes or {}) do
			parts[#parts + 1] = change_brief(entry.changes[j])
		end
		rows[#rows + 1] = table.concat(parts, ",")
	end
	return rows
end

function runtime.entries_hash(entries)
	local text = table.concat(runtime.entries_brief(entries), "|")
	local hash = 5381
	for i = 1, #text do
		hash = (hash * 33 + string.byte(text, i)) % 4294967296
	end
	return string.format("%08x", hash)
end

local function same_entries(a, b)
	if not a or not b or #a ~= #b then return false end
	for i = 1, #a do
		if a[i] ~= b[i] then return false end
	end
	return true
end

local function push_trace(row)
	commit_trace[#commit_trace + 1] = row
	while #commit_trace > 10 do table.remove(commit_trace, 1) end
end

function runtime.commit_trace()
	return commit_trace
end

function runtime.notice_receipt()
	return notice_receipt
end

function runtime.note_notice(history)
	if not history then return end
	notice_receipt = {
		version = history.version,
		entries_hash = runtime.entries_hash(history.entries),
	}
end

function runtime.clear_commit_trace()
	commit_trace = {}
	notice_receipt = nil
end

local charge_jobs = {}
local charge_log = {}

local POOL_MARKUP = {
	[ItemPoolType.POOL_TREASURE] = "{{ItemPoolTreasure}}",
	[ItemPoolType.POOL_SHOP] = "{{ItemPoolShop}}",
	[ItemPoolType.POOL_BOSS] = "{{ItemPoolBoss}}",
	[ItemPoolType.POOL_DEVIL] = "{{ItemPoolDevil}}",
	[ItemPoolType.POOL_ANGEL] = "{{ItemPoolAngel}}",
	[ItemPoolType.POOL_SECRET] = "{{ItemPoolSecret}}",
	[ItemPoolType.POOL_LIBRARY] = "{{ItemPoolLibrary}}",
	[ItemPoolType.POOL_CURSE] = "{{ItemPoolCurse}}",
	[ItemPoolType.POOL_PLANETARIUM] = "{{ItemPoolPlanetarium}}",
	[ItemPoolType.POOL_GOLDEN_CHEST] = "{{ItemPoolGoldenChest}}",
}

local STAT_ICON = {
	damage = "{{Damage}}",
	tears = "{{Tears}}",
	range = "{{Range}}",
	shot_speed = "{{Shotspeed}}",
	speed = "{{Speed}}",
	luck = "{{Luck}}",
}

local function push_charge_log(row)
	charge_log[#charge_log + 1] = row
	while #charge_log > 40 do
		table.remove(charge_log, 1)
	end
end

function runtime.charge_adjust_log()
	return charge_log
end

function runtime.clear_charge_jobs()
	charge_jobs = {}
end

function runtime.adjust_charge_once(current, old_max, new_max)
	current = math.max(0, math.floor(current or 0))
	old_max = math.max(0, math.floor(old_max or 0))
	new_max = math.max(0, math.floor(new_max or 0))
	if old_max <= 0 or new_max >= old_max then
		return current
	end
	local first = math.min(current, old_max)
	local second = math.min(math.max(current - old_max, 0), old_max)
	local extra = math.max(current - old_max * 2, 0)
	return math.min(first, new_max) + math.min(second, new_max) + extra
end

local function player_key(player)
	local data = player and player.GetData and player:GetData()
	local idx = data and data.__Index
	if idx == nil then return nil end
	return tostring(idx)
end

local function player_by_key(key)
	if key == nil then return nil end
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Isaac.GetPlayer(i)
		if player and player_key(player) == key then return player end
	end
	return nil
end

local function read_active_max(player, slot)
	if not player or not player.GetActiveMaxCharge then return nil end
	local ok, value = pcall(function()
		return player:GetActiveMaxCharge(slot)
	end)
	if ok and type(value) == "number" then return value end
	return nil
end

local function read_battery(player, slot)
	if not player or not player.GetBatteryCharge then return nil end
	local ok, value = pcall(function()
		return player:GetBatteryCharge(slot)
	end)
	if ok and type(value) == "number" then return value end
	return nil
end

local function acquisition_of(st, pkey, item_id)
	local row = st.charge_acquire and st.charge_acquire[pkey]
	local n = row and row[key_of(item_id)]
	return tonumber(n) or 0
end

local function bump_acquisition(st, pkey, item_id)
	st.charge_acquire[pkey] = st.charge_acquire[pkey] or {}
	local item_key = key_of(item_id)
	local nxt = (tonumber(st.charge_acquire[pkey][item_key]) or 0) + 1
	st.charge_acquire[pkey][item_key] = nxt
	return nxt
end

local function applied_row(st, pkey, item_id, slot)
	local by_player = st.charge_applied and st.charge_applied[pkey]
	local by_item = by_player and by_player[key_of(item_id)]
	return by_item and by_item[tostring(slot)] or nil
end

local function mark_applied(st, pkey, item_id, slot, revision, acquisition)
	st.charge_applied[pkey] = st.charge_applied[pkey] or {}
	local item_key = key_of(item_id)
	st.charge_applied[pkey][item_key] = st.charge_applied[pkey][item_key] or {}
	st.charge_applied[pkey][item_key][tostring(slot)] = {
		revision = revision,
		acquisition = acquisition or 0,
	}
end

local function already_applied(st, pkey, item_id, slot, revision, acquisition)
	local rec = applied_row(st, pkey, item_id, slot)
	if not rec then return false end
	return tonumber(rec.revision) == tonumber(revision) and tonumber(rec.acquisition) == tonumber(acquisition or 0)
end

local function has_charge_patch(st, item_id)
	local item_key = key_of(item_id)
	return (st.charges[item_key] or 0) ~= 0 or ((st.timed_charges and st.timed_charges[item_key]) or 0) ~= 0
end

function runtime.migrate_charge_adjust(st)
	if st.charge_adjust_schema == 1 then return end
	if Game():GetNumPlayers() <= 0 then return end
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Isaac.GetPlayer(i)
		local pkey = player and player_key(player)
		if pkey then
			for slot = 0, 3 do
				local id = player:GetActiveItem(slot) or 0
				if id > 0 and has_charge_patch(st, id) and not applied_row(st, pkey, id, slot) then
					local rev = (st.item_patch_versions and st.item_patch_versions[key_of(id)]) or st.version or 0
					mark_applied(st, pkey, id, slot, rev, acquisition_of(st, pkey, id))
				end
			end
		end
	end
	st.charge_adjust_schema = 1
end

local function queue_charge_job(job)
	charge_jobs[#charge_jobs + 1] = job
end

local function find_slot(player, item_id, expected_slot)
	if expected_slot ~= nil then
		if (player:GetActiveItem(expected_slot) or 0) == item_id then return expected_slot end
		return nil
	end
	local found = nil
	for slot = 0, 3 do
		if (player:GetActiveItem(slot) or 0) == item_id then
			if found ~= nil then return nil, "ambiguous" end
			found = slot
		end
	end
	return found
end

local function finish_charge_job(job, status, extra)
	local row = {
		status = status,
		reason = job.reason,
		player_key = job.player_key,
		slot = job.slot,
		item_id = job.item_id,
		revision = job.revision,
		acquisition = job.acquisition,
		old_max = job.old_max,
		new_max = job.new_max,
		charge_before = job.old_charge,
		charge_after = job.new_charge,
		battery_charge = job.battery_charge,
		deduction = job.deduction,
	}
	if extra then
		for key, value in pairs(extra) do row[key] = value end
	end
	push_charge_log(row)
end

function runtime.settle_charge_adjust()
	if #charge_jobs == 0 then return end
	local left = {}
	local st = runtime.state()
	for i = 1, #charge_jobs do
		local job = charge_jobs[i]
		if (job.delay or 0) > 0 then
			job.delay = job.delay - 1
			left[#left + 1] = job
		else
			local player = player_by_key(job.player_key)
			if not player then
				finish_charge_job(job, "cancelled_player")
			else
				local slot, slot_status = find_slot(player, job.item_id, job.slot)
				if slot_status == "ambiguous" then
					finish_charge_job(job, "skipped_ambiguous")
				elseif slot == nil then
					job.wait = (job.wait or 0) + 1
					if job.reason == "pickup" and job.wait < 30 then
						left[#left + 1] = job
					else
						finish_charge_job(job, "cancelled_replaced")
					end
				elseif already_applied(st, job.player_key, job.item_id, slot, job.revision, job.acquisition) then
					finish_charge_job(job, "already_applied", {slot = slot})
				else
					local new_max = read_active_max(player, slot)
					local battery = read_battery(player, slot)
					job.battery_charge = battery
					job.slot = slot
					if type(new_max) ~= "number" then
						finish_charge_job(job, "skipped_max_unavailable")
					else
						local old_max = job.old_max
						local current = job.old_charge
						if job.reason == "pickup" then
							local delta = runtime.charge_delta(job.item_id)
							if type(delta) ~= "number" then
								finish_charge_job(job, "skipped_no_patch")
								new_max = nil
							else
								old_max = new_max - delta
								current = player:GetActiveCharge(slot) or 0
							end
						end
						if type(new_max) == "number" then
							if type(old_max) ~= "number" then
								finish_charge_job(job, "skipped_max_unavailable")
							else
								local adjusted = runtime.adjust_charge_once(current, old_max, new_max)
								job.old_max = old_max
								job.old_charge = current
								job.new_max = new_max
								job.new_charge = adjusted
								job.deduction = math.max(0, math.floor(current or 0) - adjusted)
								if adjusted ~= math.floor(current or 0) then
									player:SetActiveCharge(adjusted, slot)
								end
								mark_applied(st, job.player_key, job.item_id, slot, job.revision, job.acquisition)
								finish_charge_job(job, "applied")
							end
						end
					end
				end
			end
		end
	end
	charge_jobs = left
end

function runtime.queue_held_charge_patches(snapshots, touched, revision)
	for i = 1, #snapshots do
		local row = snapshots[i]
		if touched[key_of(row.item_id)] then
			local st = runtime.state()
			queue_charge_job({
				reason = "patch",
				delay = 1,
				player_key = row.player_key,
				slot = row.slot,
				item_id = row.item_id,
				revision = revision,
				acquisition = acquisition_of(st, row.player_key, row.item_id),
				old_max = row.max_charge,
				old_charge = row.charge,
			})
		end
	end
end

function runtime.queue_pickup_charge(player, item_id)
	if not player or not item_id or not runtime.charge_delta(item_id) then return end
	local pkey = player_key(player)
	if not pkey then
		push_charge_log({status = "skipped_no_player_index", reason = "pickup", item_id = item_id})
		return
	end
	local st = runtime.state()
	local rev = (st.item_patch_versions and st.item_patch_versions[key_of(item_id)]) or st.version or 0
	local by_item = st.charge_applied[pkey] and st.charge_applied[pkey][key_of(item_id)]
	if by_item then
		for _, rec in pairs(by_item) do
			if tonumber(rec.revision) == tonumber(rev) then return end
		end
	end
	queue_charge_job({
		reason = "pickup",
		delay = 1,
		player_key = pkey,
		slot = nil,
		item_id = item_id,
		revision = rev,
		acquisition = bump_acquisition(st, pkey, item_id),
	})
end

local function snapshot_active_slots()
	local rows = {}
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Isaac.GetPlayer(i)
		local pkey = player and player_key(player)
		if pkey then
			for slot = 0, 3 do
				local id = player:GetActiveItem(slot) or 0
				if id > 0 then
					rows[#rows + 1] = {
						player_key = pkey,
						slot = slot,
						item_id = id,
						charge = player:GetActiveCharge(slot) or 0,
						max_charge = read_active_max(player, slot),
					}
				end
			end
		end
	end
	return rows
end

function runtime.sync_charges()
	local st = runtime.state()
	local function remember(id, cfg)
		if id and cfg then charge_base(id, cfg) end
	end
	for item_key, _ in pairs(st.charges) do
		remember(tonumber(item_key), cfg_of(tonumber(item_key)))
	end
	for item_key, _ in pairs(st.timed_charges or {}) do
		remember(tonumber(item_key), cfg_of(tonumber(item_key)))
	end
	for item_key, base in pairs(charge_original) do
		local cfg = cfg_of(tonumber(item_key))
		if cfg then cfg.MaxCharges = base end
	end
	if not (REPENTOGON and ModCallbacks.MC_PLAYER_GET_ACTIVE_MAX_CHARGE) then
		for item_key, steps in pairs(st.charges) do
			local id = tonumber(item_key)
			local cfg = cfg_of(id)
			if cfg and charge_normal_allowed(id, cfg) then
				local result = charge_base(id, cfg) + (steps or 0)
				if result < 1 then result = 1 end
				if result > 12 then result = 12 end
				cfg.MaxCharges = result
			end
		end
		for item_key, steps in pairs(st.timed_charges or {}) do
			local id = tonumber(item_key)
			local cfg = cfg_of(id)
			if cfg and charge_timed_allowed(id, cfg) then
				local result = charge_base(id, cfg) + (steps or 0) * 30
				if result < 30 then result = 30 end
				cfg.MaxCharges = result
			end
		end
	end
end

function runtime.sync_stats()
	local flags = CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_RANGE
		| CacheFlag.CACHE_SHOTSPEED | CacheFlag.CACHE_SPEED | CacheFlag.CACHE_LUCK
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Isaac.GetPlayer(i)
		if player then
			player:AddCacheFlags(flags)
			player:EvaluateItems()
		end
	end
end

function runtime.stat_total(player, stat_key)
	local st = runtime.state()
	local total = 0
	for item_key, rec in pairs(st.stats) do
		local steps = rec[stat_key] or 0
		if steps ~= 0 then
			local count = player:GetCollectibleNum(tonumber(item_key), true)
			if count > 0 then
				total = total + count * steps * runtime.STAT_STEP
			end
		end
	end
	return total
end

local function can_pick(player, method_name)
	local method = player and player[method_name]
	if type(method) ~= "function" then return true end
	local ok, allowed = pcall(function()
		return method(player)
	end)
	if not ok then return true end
	return allowed ~= false
end

function runtime.on_gain(player, id, count)
	count = tonumber(count) or 1
	if not player or not id or count <= 0 then return end
	local st = runtime.state()
	local key = key_of(id)
	local red = st.hearts[key] or 0
	if red ~= 0 and can_pick(player, "CanPickRedHearts") then
		local half = red * 2 * count
		player:AddMaxHearts(half, true)
		if half < 0 then
			player:AddHearts(-half)
		end
		local bone = 0
		if player.GetBoneHearts then bone = player:GetBoneHearts() end
		local containers = player:GetMaxHearts() + player:GetSoulHearts() + (player:GetBlackHearts() or 0) + bone * 2
		if containers <= 0 then
			player:AddMaxHearts(2, true)
		end
	end
	local soul = st.soul_hearts[key] or 0
	if soul ~= 0 and can_pick(player, "CanPickSoulHearts") then
		player:AddSoulHearts(soul * 2 * count)
	end
	local black = st.black_hearts[key] or 0
	if black ~= 0 and can_pick(player, "CanPickBlackHearts") then
		player:AddBlackHearts(black * 2 * count)
	end
	runtime.queue_pickup_charge(player, id)
end

function runtime.commit(opts)
	opts = opts or {}
	local st = runtime.state()
	local charge_snapshots = snapshot_active_slots()
	local charge_touched = {}
	local rng, rng_mode, owner = runtime.make_rng(opts.seed, opts.player)
	local seed_before = rng and rng:GetSeed() or nil
	if not rng then
		st.last_diag = {wanted = 0, filled = 0, short = false, rejected = "no_holder"}
		push_trace({
			version = st.version,
			trigger_kind = opts.kind or "unspecified",
			rng_mode = rng_mode,
			player = nil,
			seed_before = nil,
			seed_after = nil,
			requested_count = opts.count,
			filled_count = 0,
			entries_hash = runtime.entries_hash({}),
			entries = {},
			same_entries_as_previous = false,
			rejected = "no_holder",
		})
		return nil
	end
	local copies = runtime.copies()
	if copies < 1 then copies = 1 end
	local count = opts.count
	if count == nil then
		count = (rng:RandomInt(17) + 4) + 2 * (copies - 1)
	end
	if count < 1 then count = 1 end
	if count > 32 then count = 32 end
	local category = opts.category
	local pool_goal = 0
	if category == "pool" then
		pool_goal = count
	elseif category ~= "buff" and category ~= "nerf" then
		pool_goal = math.floor(count * runtime.POOL_SHARE + 0.5)
	end
	local pool_bag = pool_candidates()
	local number_bag = numeric_candidates(st)
	local function pull(bag)
		if #bag == 0 then return nil end
		local index = rng:RandomInt(#bag) + 1
		local id = bag[index]
		table.remove(bag, index)
		return id
	end
	local function apply_id(id, pool_first)
		local changes = nil
		if pool_first then
			local pool_change = try_pool(rng, st, id)
			if pool_change then changes = {pool_change} end
		end
		if not changes and category ~= "pool" then
			changes = commit_numeric(rng, st, id, category)
		elseif changes and category ~= "pool" and rng:RandomInt(100) < runtime.SECOND_CHANCE then
			local extra = commit_numeric(rng, st, id, category)
			if extra then
				for j = 1, #extra do changes[#changes + 1] = extra[j] end
			end
		end
		return changes
	end
	local entries = {}
	local changed_stats = false
	local changed_charges = false
	local pool_filled = 0
	local guard = 0
	while #entries < count and guard < 800 do
		guard = guard + 1
		local want_pool = category == "pool" or pool_filled < pool_goal
		local id = want_pool and pull(pool_bag) or nil
		local pool_first = id ~= nil
		if not id then
			if category == "pool" then break end
			id = pull(number_bag)
			pool_first = false
		end
		if not id then break end
		local changes = apply_id(id, pool_first)
		if changes and #changes > 0 then
			for j = 1, #changes do
				local kind = changes[j].kind
				if kind == "charge" or kind == "charge_normal" or kind == "charge_timed" then
					changed_charges = true
					charge_touched[key_of(id)] = true
				end
				if kind ~= "hearts" and kind ~= "soul_hearts" and kind ~= "black_hearts"
					and kind ~= "charge" and kind ~= "charge_normal" and kind ~= "charge_timed"
					and kind ~= "pool_add" and kind ~= "pool_remove" and kind ~= "pool_weight" then
					changed_stats = true
				end
			end
			local pooled = false
			for j = 1, #changes do
				local kind = changes[j].kind
				if kind == "pool_add" or kind == "pool_remove" or kind == "pool_weight" then pooled = true end
			end
			if pooled then pool_filled = pool_filled + 1 end
			entries[#entries + 1] = {item_id = id, changes = changes}
		end
	end
	st.last_diag = {
		wanted = count,
		filled = #entries,
		pool_goal = pool_goal,
		pool_filled = pool_filled,
		short = #entries < count,
		rng_mode = rng_mode,
	}
	local brief = runtime.entries_brief(entries)
	local previous = commit_trace[#commit_trace]
	local row = {
		version = #entries > 0 and ((st.version or 0) + 1) or st.version,
		trigger_kind = opts.kind or (rng_mode == "fixed_debug" and "debug" or "unspecified"),
		rng_mode = rng_mode,
		player = player_slot(owner),
		seed_before = seed_before,
		seed_after = rng:GetSeed(),
		requested_count = count,
		filled_count = #entries,
		entries_hash = runtime.entries_hash(entries),
		entries = brief,
		same_entries_as_previous = previous and same_entries(brief, previous.entries) or false,
	}
	push_trace(row)
	if #entries == 0 then return nil end
	st.version = (st.version or 0) + 1
	st.item_patch_versions = st.item_patch_versions or {}
	for i = 1, #entries do
		st.item_patch_versions[key_of(entries[i].item_id)] = st.version
	end
	if opts.kind == "room" then
		st.room_update_floor_key = runtime.floor_key()
	end
	st.history = {version = st.version, entries = entries}
	eid_cache.version = -1
	if changed_charges then
		runtime.sync_charges()
		runtime.queue_held_charge_patches(charge_snapshots, charge_touched, st.version)
	end
	if changed_stats then runtime.sync_stats() end
	return st.history
end

function runtime.pool_label(pool_type, pool_name, zh)
	local row = POOL_NAME[tonumber(pool_type)]
	if not row or pool_name then return nil end
	return zh and row.zh or row.en
end

function runtime.version_text(version)
	return "1.0." .. tostring(version or 0)
end

local function zh_lang()
	local lang = auxi.get_EID_language and auxi.get_EID_language() or "en_us"
	return lang == "zh_cn" or lang == "zh" or lang == "chinese"
end

local STAT_LABEL = {
	damage = {zh = "攻击力", en = "Damage"},
	tears = {zh = "射速", en = "Tears"},
	range = {zh = "射程", en = "Range"},
	shot_speed = {zh = "弹速", en = "Shot Speed"},
	speed = {zh = "移速", en = "Speed"},
	luck = {zh = "幸运", en = "Luck"},
}

local function signed_number(steps, scale)
	local value = steps * scale
	local text = string.format("%.1f", math.abs(value))
	if steps > 0 then return "+" .. text end
	return "-" .. text
end

local function signed_integer(value)
	return string.format("%+d", math.floor(value))
end

function runtime.eid_lines(id)
	local st = runtime.state()
	local zh = zh_lang()
	local lang = zh and "zh" or "en"
	if eid_cache.version ~= st.version or eid_cache.lang ~= lang then
		eid_cache.version = st.version
		eid_cache.lang = lang
		eid_cache.lines = {}
	end
	local item_key = key_of(id)
	if eid_cache.lines[item_key] then return eid_cache.lines[item_key] end
	local parts = {}
	local rec = st.stats[item_key]
	if rec then
		for i = 1, #STATS do
			local stat_key = STATS[i].key
			local steps = rec[stat_key] or 0
			if steps ~= 0 then
				parts[#parts + 1] = (STAT_ICON[stat_key] or "") .. signed_number(steps, runtime.STAT_STEP)
			end
		end
	end
	local hearts = st.hearts[item_key] or 0
	if hearts ~= 0 then
		parts[#parts + 1] = "{{Heart}}" .. signed_integer(hearts)
	end
	local soul = (st.soul_hearts and st.soul_hearts[item_key]) or 0
	if soul ~= 0 then
		parts[#parts + 1] = "{{SoulHeart}}" .. signed_integer(soul)
	end
	local black = (st.black_hearts and st.black_hearts[item_key]) or 0
	if black ~= 0 then
		parts[#parts + 1] = "{{BlackHeart}}" .. signed_integer(black)
	end
	local charges = st.charges[item_key] or 0
	if charges ~= 0 then
		parts[#parts + 1] = "{{Battery}}" .. signed_integer(charges)
	end
	local timed = (st.timed_charges and st.timed_charges[item_key]) or 0
	if timed ~= 0 then
		parts[#parts + 1] = "{{Timer}}" .. signed_integer(timed) .. "s"
	end
	local pool_keys = {}
	for pool_key, items in pairs(st.pool_added) do
		if items[item_key] then pool_keys[#pool_keys + 1] = pool_key end
	end
	table.sort(pool_keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	for i = 1, #pool_keys do
		local pool_type = tonumber(pool_keys[i])
		local markup = nil
		if EID and EID.ItemPoolTypeToMarkup and pool_type and EID.ItemPoolTypeToMarkup[pool_type] then
			markup = EID.ItemPoolTypeToMarkup[pool_type]
		end
		markup = markup or POOL_MARKUP[pool_type]
		if markup then
			parts[#parts + 1] = "+" .. markup
		end
	end
	local lines = {}
	if #parts > 0 then
		local version = st.item_patch_versions and st.item_patch_versions[item_key] or st.version
		local title = (zh and "微型更新 " or "Tiny Update ") .. runtime.version_text(version)
		lines[1] = "{{ColorSilver}}" .. title .. " · " .. table.concat(parts, " ")
	end
	eid_cache.lines[item_key] = lines
	return lines
end

function runtime.invalidate_eid()
	eid_cache.version = -1
end

function runtime.sync_custom_pools()
	local st = runtime.state()
	if st.custom_reverted then return end
	local root = custom_root()
	if not root then return end
	for pool_name, items in pairs(st.custom or {}) do
		local pool = root[pool_name]
		local list = pool and pool.list
		if type(list) == "table" and type(items) == "table" then
			for id_key, rec in pairs(items) do
				local id = tonumber(id_key)
				if id and type(rec) == "table" then
					local found_key, entry = find_custom(list, id)
					local applied = weight_target(rec.base or 1, rec.steps or 0)
					if rec.state == "added" then
						if found_key and entry and math.abs(entry_weight(entry) - applied) < 0.02 then
							list[found_key] = nil
						end
					elseif rec.state == "removed" then
						if not found_key then
							list[id] = {id = id, weigh = rec.base or 1}
						end
					elseif found_key and entry and rec.base_initialized and math.abs(entry_weight(entry) - applied) < 0.02 then
						set_entry_weight(entry, rec.base or 1)
					end
				end
			end
		end
	end
	st.custom = {}
	st.custom_reverted = true
	runtime.invalidate_eid()
end

local function fmt_weight(value)
	if value == nil then return "-" end
	return string.format("%.1f", value)
end

local function summarize_rows(rows)
	if not rows then return nil, nil, 0 end
	local weight, initial = nil, nil
	if rows[1] then
		weight = rows[1].weight
		initial = rows[1].initialWeight
	end
	return weight, initial, #rows
end

function runtime.probe_pool(pool_type, item_id, experiment)
	local id = tonumber(item_id) or 0
	local before = rows_for_item(pool_type, id)
	local weight, initial, count = summarize_rows(before)
	local report = {
		pool = pool_type,
		item_id = id,
		initial_weight = initial,
		weight = weight,
		target_weight = nil,
		commit = "not-run",
		requery = nil,
		status = "UNSUPPORTED",
		detail = "No public setter for an existing vanilla pool member. The query table is not treated as writable engine state.",
	}
	if not before then
		report.status = "FAIL"
		report.detail = "GetCollectiblesFromPool failed."
		runtime.probe_report = report
		return runtime.probe_text()
	end
	if not experiment then
		runtime.probe_report = report
		return runtime.probe_text()
	end
	local item_pool = Game():GetItemPool()
	if count > 0 and before[1].raw then
		local raw = before[1].raw
		local original = raw.weight
		local target = (original or 0) + runtime.WEIGHT_STEP
		report.target_weight = target
		raw.weight = target
		local mid = rows_for_item(pool_type, id)
		local mid_weight = mid and mid[1] and mid[1].weight or nil
		report.requery = mid_weight
		raw.weight = original
		local back = rows_for_item(pool_type, id)
		local restored = back and back[1] and back[1].weight or nil
		if mid_weight and original and math.abs(mid_weight - target) < 0.02 then
			if restored and math.abs(restored - original) < 0.02 then
				report.status = "PASS"
				report.commit = "rolled-back"
				report.detail = "Query-row write was visible and the original weight was restored. Official updates still do not use this path."
			else
				report.status = "FAIL"
				report.commit = "rollback-failed"
				report.detail = "Query-row write changed the live pool and rollback did not restore the original weight."
			end
		else
			report.status = "UNSUPPORTED"
			report.commit = "query-write-ignored"
			report.detail = "Writing weight on the GetCollectiblesFromPool row did not change a fresh query. Native member weight stays unsupported."
		end
	end
	local temp = {itemID = id, weight = runtime.WEIGHT_STEP, decreaseBy = 0.5, removeOn = 0.1}
	local add_ok = item_pool.AddTemporaryCollectible and pcall(function()
		item_pool:AddTemporaryCollectible(pool_type, temp)
	end)
	local added = rows_for_item(pool_type, id)
	local added_count = added and #added or -1
	local remove_ok = false
	if add_ok and item_pool.RemoveTemporaryCollectible then
		remove_ok = pcall(function()
			item_pool:RemoveTemporaryCollectible(pool_type, temp)
		end)
	end
	local restored_rows = rows_for_item(pool_type, id)
	local restored_count = restored_rows and #restored_rows or -1
	report.temp_before = count
	report.temp_after_add = added_count
	report.temp_after_remove = restored_count
	if not add_ok then
		report.detail = report.detail .. " Temporary add call failed."
	elseif restored_count ~= count then
		report.status = "FAIL"
		report.commit = "temp-rollback-failed"
		report.detail = report.detail .. " Temporary probe entry was not removed cleanly."
	else
		report.detail = report.detail .. string.format(" Temporary add/remove restored the row count (%d).", count)
	end
	if not remove_ok and add_ok then
		report.status = "FAIL"
	end
	runtime.probe_report = report
	return runtime.probe_text()
end

function runtime.probe_text()
	local report = runtime.probe_report
	if not report then return "probe: -" end
	return string.format(
		"pool:%s item:%s\ninitial:%s weight:%s target:%s\nrequery:%s commit:%s\nstatus:%s\n%s",
		tostring(report.pool),
		tostring(report.item_id),
		fmt_weight(report.initial_weight),
		fmt_weight(report.weight),
		fmt_weight(report.target_weight),
		fmt_weight(report.requery),
		tostring(report.commit),
		tostring(report.status),
		tostring(report.detail)
	)
end

function runtime.debug_status()
	local st = runtime.state()
	local count = 0
	if st.history and st.history.entries then count = #st.history.entries end
	local diag = st.last_diag
	local short = ""
	if diag then
		short = string.format(" wanted:%d filled:%d short:%s", diag.wanted or 0, diag.filled or 0, tostring(diag.short))
	end
	return string.format("v%s  items:%d%s", runtime.version_text(st.version), count, short)
end

runtime._shuffle = shuffle_take

return runtime
