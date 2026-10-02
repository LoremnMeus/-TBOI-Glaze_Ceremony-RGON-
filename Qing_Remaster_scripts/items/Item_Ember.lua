local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Ember,
	own_key = "Item_Ember_",
	-- 心如死灰开局真实给予的余烬份数（非运行时虚拟计数）
	challenge_start_ember_count = 8,
	-- Tint 近白 + 熔炉 Colorize（ae3b00 / ff6e01 / ffea01）
	hud_furnace = Color(1, 1, 1, 0.78, 0.06, 0.02, 0, 1.85, 0.62, 0.08, 1),
}

local LAST_KEY = item.own_key.."last"
local BLOCKED_KEY = item.own_key.."blocked"
local TAG_QUEST = ItemConfig.TAG_QUEST or (1 << 15)

local FURNACE = {
	{174 / 255, 59 / 255, 0},
	{1, 110 / 255, 1 / 255},
	{1, 234 / 255, 1 / 255},
}

local COPY_BLACKLIST = {
	[CollectibleType.COLLECTIBLE_POLAROID] = true,
	[CollectibleType.COLLECTIBLE_NEGATIVE] = true,
	[CollectibleType.COLLECTIBLE_KEY_PIECE_1] = true,
	[CollectibleType.COLLECTIBLE_KEY_PIECE_2] = true,
	[CollectibleType.COLLECTIBLE_KNIFE_PIECE_1] = true,
	[CollectibleType.COLLECTIBLE_KNIFE_PIECE_2] = true,
	[CollectibleType.COLLECTIBLE_DADS_NOTE] = true,
	[CollectibleType.COLLECTIBLE_DOGMA] = true,
	[CollectibleType.COLLECTIBLE_DEATH_CERTIFICATE] = true,
	[CollectibleType.COLLECTIBLE_R_KEY] = true,
	[CollectibleType.COLLECTIBLE_GENESIS] = true,
	[CollectibleType.COLLECTIBLE_CLICKER] = true,
	[CollectibleType.COLLECTIBLE_TMTRAINER] = true,
	[CollectibleType.COLLECTIBLE_MISSING_NO] = true,
	[CollectibleType.COLLECTIBLE_GLITCHED_CROWN] = true,
	[CollectibleType.COLLECTIBLE_VOID] = true,
	[CollectibleType.COLLECTIBLE_D4] = true,
	[CollectibleType.COLLECTIBLE_D100] = true,
	[CollectibleType.COLLECTIBLE_SPINDOWN_DICE] = true,
	[CollectibleType.COLLECTIBLE_FLIP] = true,
	[CollectibleType.COLLECTIBLE_RECALL] = true,
	[CollectibleType.COLLECTIBLE_MOVING_BOX] = true,
	[CollectibleType.COLLECTIBLE_SCHOOLBAG] = true,
	[CollectibleType.COLLECTIBLE_MOMS_PURSE] = true,
}

local function player_idx(player)
	if not player then return nil end
	local d = player:GetData()
	if d and d.__Index ~= nil then return d.__Index end
	if player.GetPlayerIndex then return player:GetPlayerIndex() end
	return nil
end

local function is_ashes_challenge()
	return Game().Challenge == enums.Challenges.Feels_Like_Dead_Ashes
end

local function last_bag()
	save.elses[LAST_KEY] = save.elses[LAST_KEY] or {}
	return save.elses[LAST_KEY]
end

function item.get_last_lost(player)
	local idx = player_idx(player)
	if idx == nil then return nil end
	return tonumber(last_bag()[idx])
end

function item.set_last_lost(player, id)
	local idx = player_idx(player)
	if idx == nil then return end
	id = tonumber(id)
	if not id or id <= 0 then return end
	last_bag()[idx] = id
	Imitate_item_holder.Evaluate_Imitate_Items(player)
end

local function true_collectible_num(player, id)
	if not player or not id then return 0 end
	local ok, n = pcall(function()
		return player:GetCollectibleNum(id, true, true)
	end)
	if ok and type(n) == "number" then return n end
	return player:GetCollectibleNum(id, true)
end

function item.ember_count(player)
	return math.max(0, true_collectible_num(player, item.entity))
end

function item.is_copyable(id)
	id = tonumber(id)
	if not id or id <= 0 then return false end
	if id == item.entity then return false end
	if COPY_BLACKLIST[id] then return false end
	local cfg = Isaac.GetItemConfig():GetCollectible(id)
	if not cfg then return false end
	if cfg.Hidden then return false end
	if cfg:HasTags(TAG_QUEST) then return false end
	if cfg.Type ~= ItemType.ITEM_PASSIVE and cfg.Type ~= ItemType.ITEM_FAMILIAR then return false end
	return true
end

local function lerp3(a, b, t)
	return {
		a[1] + (b[1] - a[1]) * t,
		a[2] + (b[2] - a[2]) * t,
		a[3] + (b[3] - a[3]) * t,
	}
end

function item.furnace_hud_color()
	local t = 0.5 + 0.5 * math.sin(Game():GetFrameCount() * 0.07)
	local rgb
	if t < 0.5 then
		rgb = lerp3(FURNACE[1], FURNACE[2], t * 2)
	else
		rgb = lerp3(FURNACE[2], FURNACE[3], (t - 0.5) * 2)
	end
	-- Tint 近白，熔炉色走 Colorize
	return Color(1, 1, 1, 0.70 + 0.10 * t, 0.04, 0.01, 0, rgb[1] * 1.55, rgb[2] * 1.15, rgb[3], 1)
end

local function can_block(player)
	return player and player.BlockCollectible and player.UnblockCollectible and player.IsCollectibleBlocked
end

local function should_disable_owned(id)
	if id == item.entity then return false end
	local cfg = Isaac.GetItemConfig():GetCollectible(id)
	if not cfg then return false end
	if cfg:HasTags(TAG_QUEST) then return false end
	return cfg.Type == ItemType.ITEM_PASSIVE or cfg.Type == ItemType.ITEM_FAMILIAR
end

local function owned_disable_ids(player)
	local owned = {}
	local listed = (player.GetCollectiblesList and player:GetCollectiblesList()) or nil
	if type(listed) == "table" then
		for id, n in pairs(listed) do
			if (n or 0) > 0 and should_disable_owned(id) then
				owned[id] = true
			end
		end
		return owned
	end
	local sz = Isaac.GetItemConfig():GetCollectibles().Size
	for id = 1, sz do
		if should_disable_owned(id) and true_collectible_num(player, id) > 0 then
			owned[id] = true
		end
	end
	return owned
end

function item.sync_challenge_blocks(player)
	if not is_ashes_challenge() or not auxi.check_all_exists(player) then return end
	if not can_block(player) then return end
	local d = player:GetData()
	local tracked = d[BLOCKED_KEY]
	if type(tracked) ~= "table" then
		tracked = {}
		d[BLOCKED_KEY] = tracked
	end
	local last = item.get_last_lost(player)
	local owned = owned_disable_ids(player)
	local dirty = false
	for id in pairs(owned) do
		if id == last then
			if player:IsCollectibleBlocked(id) then
				player:UnblockCollectible(id)
				dirty = true
			end
			tracked[id] = nil
		else
			if not player:IsCollectibleBlocked(id) then
				player:BlockCollectible(id)
				dirty = true
			end
			tracked[id] = true
		end
	end
	local stale = {}
	for id in pairs(tracked) do
		if not owned[id] or id == last then
			stale[#stale + 1] = id
		end
	end
	for i = 1, #stale do
		local id = stale[i]
		if player:IsCollectibleBlocked(id) then
			player:UnblockCollectible(id)
			dirty = true
		end
		tracked[id] = nil
	end
	if dirty and player.AddCacheFlags then
		player:AddCacheFlags(CacheFlag.CACHE_ALL, true)
	end
end

function item.on_challenge_start(continue)
	if not is_ashes_challenge() then return end
	if not continue then
		save.elses[LAST_KEY] = {}
		for i = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(i)
			for _ = 1, item.challenge_start_ember_count do
				player:AddCollectible(item.entity)
			end
		end
	end
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		Imitate_item_holder.Evaluate_Imitate_Items(player)
		item.sync_challenge_blocks(player)
	end
end

table.insert(item.myToCall, {CallBack = enums.Callbacks.MC_EVALUATE_IMITATE_ITEM, params = nil,
Function = function(_, player, _, value)
	local n = item.ember_count(player)
	if n <= 0 then return end
	local lost = item.get_last_lost(player)
	if not lost or not item.is_copyable(lost) then return end
	Imitate_item_holder.add(value, lost, n, {display = true, costume = false})
end,
})

if ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_ADDED then
	table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_ADDED, params = nil,
	Function = function(_, player, colid, _, wisp_or_innate)
		if not player or wisp_or_innate then return end
		if not is_ashes_challenge() then return end
		if item._suppress_shell then return end
		if not should_disable_owned(colid) then return end
		if can_block(player) then
			item.sync_challenge_blocks(player)
		end
		-- 无 BlockCollectible 时不走 strip_owned_fallback：
		-- 挑战依赖「禁用但仍占槽」；立即 Remove 会破坏该循环。
	end,
	})
end

if ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_REMOVED then
	table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_REMOVED, params = nil,
	Function = function(_, player, colid, _, wisp_or_innate)
		if not player or wisp_or_innate then return end
		if item._suppress_shell then return end
		if not item.is_copyable(colid) then return end
		if true_collectible_num(player, colid) > 0 then return end
		item.set_last_lost(player, colid)
		item.sync_challenge_blocks(player)
	end,
	})
else
	table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_PEFFECT_UPDATE, params = nil,
	Function = function(_, player)
		local idx = player_idx(player)
		if idx == nil then return end
		item._snap = item._snap or {}
		local prev = item._snap[idx] or {}
		local now = {}
		local listed = (player.GetCollectiblesList and player:GetCollectiblesList()) or nil
		if type(listed) == "table" then
			for id, n in pairs(listed) do
				if item.is_copyable(id) then
					now[id] = n or 0
				end
			end
		else
			local sz = Isaac.GetItemConfig():GetCollectibles().Size
			for i = 1, sz do
				if item.is_copyable(i) then
					now[i] = true_collectible_num(player, i)
				end
			end
		end
		if not item._suppress_shell then
			for id, n in pairs(prev) do
				if (n or 0) > 0 and (now[id] or 0) <= 0 then
					item.set_last_lost(player, id)
				end
			end
		end
		item._snap[idx] = now
		item.sync_challenge_blocks(player)
	end,
	})
end

table.insert(item.ToCall, {CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_, player)
	if not is_ashes_challenge() then return end
	item.sync_challenge_blocks(player)
end,
})

do
	local temp_hud = require("Qing_Remaster_scripts.callbacks.temp_item_hud_holder")
	temp_hud.register_provider(function(player)
		local lost = item.get_last_lost(player)
		local n = item.ember_count(player)
		if not lost or n <= 0 then return end
		return {[lost] = n}
	end, {
		color_fn = function() return item.furnace_hud_color() end,
		exclusive = true,
		source_item = item.entity,
	})
end

return item
