local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")
local common = require("Qing_Remaster_scripts.cards.oblivion_common")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Cards.Oblivion_r,
	own_key = "Thoth_cd00r_Obl_",
}

local STATE_KEY = item.own_key .. "state"

local function ensure_state()
	save.elses[STATE_KEY] = save.elses[STATE_KEY] or {}
	return save.elses[STATE_KEY]
end

local function player_state(player)
	local idx = common.player_index(player)
	if idx == nil then return nil, nil end
	local bag = ensure_state()
	bag[idx] = bag[idx] or {
		pending = 0,
		spawnTimer = 0,
		active = {},
		rng_seed = 0,
	}
	local st = bag[idx]
	st.pending = tonumber(st.pending) or 0
	st.spawnTimer = tonumber(st.spawnTimer) or 0
	st.active = st.active or {}
	st.rng_seed = tonumber(st.rng_seed) or 0
	return st, idx
end

local function ensure_rng(st, player)
	if (st.rng_seed or 0) == 0 then
		local base = auxi.rng_for_sake(player:GetCardRNG(item.entity))
		st.rng_seed = base:GetSeed()
		if st.rng_seed == 0 then
			st.rng_seed = 1
		end
	end
	local rng = RNG()
	rng:SetSeed(st.rng_seed, 35)
	return rng
end

local function store_rng(st, rng)
	st.rng_seed = rng:GetSeed()
	if st.rng_seed == 0 then
		st.rng_seed = 1
	end
end

local function active_id_set(st)
	local set = {}
	for _, entry in ipairs(st.active or {}) do
		if entry.id then
			set[entry.id] = true
		end
	end
	return set
end

local function is_running(st)
	return (st.pending or 0) > 0 or #(st.active or {}) > 0
end

local function reevaluate(player)
	Imitate_item_holder.Evaluate_Imitate_Items(player)
end

function item.enqueue_pending(player, amount)
	local st = player_state(player)
	if not st then return end
	amount = amount or common.PENDING_PER_USE
	local was_idle = not is_running(st)
	st.pending = (st.pending or 0) + amount
	if was_idle then
		st.spawnTimer = 0
		ensure_rng(st, player)
	end
end

function item.spawn_one(player, st)
	local rng = ensure_rng(st, player)
	local id = common.pick_temp_collectible(rng, active_id_set(st))
	store_rng(st, rng)
	if not id then return false end
	table.insert(st.active, {
		id = id,
		remaining = common.TEMP_DURATION,
	})
	return true
end

function item.tick_player(player)
	if not auxi.check_all_exists(player) then return end
	if common.is_paused() then return end
	local st = player_state(player)
	if not st or not is_running(st) then return end

	local changed = false

	-- Age active temps.
	local i = 1
	while i <= #st.active do
		local entry = st.active[i]
		entry.remaining = (entry.remaining or 0) - 1
		if entry.remaining <= 0 then
			table.remove(st.active, i)
			changed = true
		else
			i = i + 1
		end
	end

	-- Spawn cadence: one per second while pending remains.
	if (st.pending or 0) > 0 then
		st.spawnTimer = (st.spawnTimer or 0) + 1
		if st.spawnTimer >= common.SPAWN_INTERVAL then
			st.spawnTimer = 0
			if item.spawn_one(player, st) then
				st.pending = st.pending - 1
				changed = true
			else
				-- Cannot spawn anything valid; drop remaining queue to avoid softlock.
				st.pending = 0
			end
		end
	end

	if changed then
		reevaluate(player)
	end
end

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	params = nil,
	Function = function(_, continue)
		if not continue then
			save.elses[STATE_KEY] = {}
		end
		ensure_state()
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.MC_EVALUATE_IMITATE_ITEM,
	params = nil,
	Function = function(_, player, _, value)
		local st = player_state(player)
		if not st then return end
		for _, entry in ipairs(st.active or {}) do
			if entry.id then
				Imitate_item_holder.add(value, entry.id, 1, {
					display = true,
				})
			end
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_USE_CARD,
	params = item.entity,
	Function = function(_, cardtype, player, useFlags)
		-- Every successful use (including Tarot Cloth / Blank Card) only extends pending.
		-- pending alone does not change active; evaluate when spawn/expire mutates active.
		item.enqueue_pending(player, common.PENDING_PER_USE)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PEFFECT_UPDATE,
	params = nil,
	Function = function(_, player)
		item.tick_player(player)
	end,
})

do
	local temp_hud = require("Qing_Remaster_scripts.callbacks.temp_item_hud_holder")
	item.temp_hud_color = Color(1, 1, 1, 0.62, 0, 0, 0, 1.6, 1.2, 2.2, 1)
	temp_hud.register_provider(function(player)
		local st = player_state(player)
		if not st or not st.active or #st.active == 0 then return end
		local out = {}
		for _, entry in ipairs(st.active) do
			if entry.id then
				out[entry.id] = (out[entry.id] or 0) + 1
			end
		end
		return out
	end, {
		color = item.temp_hud_color,
		exclusive = true,
		source_card = item.entity,
	})
end

return item
