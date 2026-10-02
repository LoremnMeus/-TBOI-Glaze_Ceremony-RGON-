-- Unified player loss semantics.
-- Converts existing collectible / basic / pocket / charge events into POST_PLAYER_LOSS.
-- Does NOT own Regenesis queue, weights, or restore. Consumers listen to POST_PLAYER_LOSS.
local enums = require("Qing_Remaster_scripts.core.enums")
local callback_manager = require("Qing_Remaster_scripts.core.callback_manager")
local pocket_use = require("Qing_Remaster_scripts.auxiliary.pocket_use_semantics")

local item = {
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	own_key = "Player_Loss_",
}

-- Transient only: PRE/USE active charge comparison. Cleared on POST_REWIND.
local runtime = {
	active_pre_use = {},
}

local collectible_filters = {}

local TAG_QUEST = ItemConfig.TAG_QUEST or (1 << 15)

local COLLECTIBLE_BLACKLIST = {
	[CollectibleType.COLLECTIBLE_DADS_NOTE] = true,
	[CollectibleType.COLLECTIBLE_KNIFE_PIECE_1] = true,
	[CollectibleType.COLLECTIBLE_KNIFE_PIECE_2] = true,
	[CollectibleType.COLLECTIBLE_KEY_PIECE_1] = true,
	[CollectibleType.COLLECTIBLE_KEY_PIECE_2] = true,
}

function item.register_collectible_filter(name, fn)
	if type(name) ~= "string" or type(fn) ~= "function" then return end
	collectible_filters[name] = fn
end

local function player_index(player)
	if not player or not player.GetData then return nil end
	local d = player:GetData()
	return d and d.__Index or nil
end

local function cfg_has_quest(cfg)
	if not cfg then return true end
	if cfg.HasTags then return cfg:HasTags(TAG_QUEST) end
	return (cfg.Tags or 0) & TAG_QUEST == TAG_QUEST
end

local function should_emit_collectible(player, id, amount)
	id = tonumber(id) or 0
	amount = tonumber(amount) or 0
	if id <= 0 or amount <= 0 then return false end
	if id == enums.Items.Regenesis then return false end
	if COLLECTIBLE_BLACKLIST[id] then return false end
	local cfg = Isaac.GetItemConfig():GetCollectible(id)
	if not cfg or cfg.Hidden then return false end
	if cfg_has_quest(cfg) then return false end
	for _, fn in pairs(collectible_filters) do
		if fn(player, id, amount) == false then return false end
	end
	return true
end

function item.emit_loss(player, loss)
	if not player or type(loss) ~= "table" then return end
	loss.kind = tostring(loss.kind or "")
	loss.amount = math.floor(tonumber(loss.amount) or 0)
	if loss.kind == "" or loss.amount <= 0 then return end
	callback_manager.work("POST_PLAYER_LOSS", function(funct, params)
		if params == nil or params == loss.kind then
			funct(nil, player, loss)
		end
	end)
end

local function counter_of(tbl, name)
	if type(tbl) ~= "table" then return 0 end
	local entry = tbl[name]
	if type(entry) == "table" then
		return tonumber(entry.counter) or 0
	end
	return tonumber(entry) or 0
end

--- Normalize HP loss from POST_CHANGE_ALL_BASIC snapshots.
--- Avoids double-counting Black Hearts against SoulHearts.
function item.normalize_health_loss(old_tbl, new_tbl)
	local out = {}
	local function drop(name)
		return math.max(0, counter_of(old_tbl, name) - counter_of(new_tbl, name))
	end

	local red = drop("rd_heart")
	if red > 0 then
		out[#out + 1] = {kind = "red_heart", amount = red, source = "basic_holder"}
	end

	local soul_loss = drop("sl_heart")
	local black_loss = drop("bl_heart")
	-- One black heart occupies two SoulHeart units in Isaac.
	local soul_for_black = black_loss * 2
	if soul_for_black > soul_loss then
		soul_for_black = soul_loss
	end
	soul_loss = soul_loss - soul_for_black
	if black_loss > 0 then
		out[#out + 1] = {kind = "black_heart", amount = black_loss, source = "basic_holder"}
	end
	if soul_loss > 0 then
		out[#out + 1] = {kind = "soul_heart", amount = soul_loss, source = "basic_holder"}
	end

	local eternal = drop("et_heart")
	if eternal > 0 then
		out[#out + 1] = {kind = "eternal_heart", amount = eternal, source = "basic_holder"}
	end
	local bone = drop("bn_heart")
	if bone > 0 then
		out[#out + 1] = {kind = "bone_heart", amount = bone, source = "basic_holder"}
	end
	return out
end

local function total_charge(player, slot)
	slot = slot or ActiveSlot.SLOT_PRIMARY
	local main = player.GetActiveCharge and player:GetActiveCharge(slot) or 0
	local bat = player.GetBatteryCharge and player:GetBatteryCharge(slot) or 0
	return (tonumber(main) or 0) + (tonumber(bat) or 0), tonumber(main) or 0, tonumber(bat) or 0
end

-- Collectible loss
table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_LOSE_COLLECTIBLE,
	params = nil,
	Function = function(_, player, collid, count_lost, _old_count)
		if not should_emit_collectible(player, collid, count_lost) then return end
		item.emit_loss(player, {
			kind = "collectible",
			collectible_id = collid,
			amount = count_lost,
			source = "collectible_holder",
		})
	end,
})

-- Coin / Bomb / Key
table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_CHANGE_BASIC,
	params = nil,
	Function = function(_, player, name, delta)
		if name ~= "coin" and name ~= "bomb" and name ~= "key" then return end
		delta = tonumber(delta) or 0
		if delta >= 0 then return end
		item.emit_loss(player, {
			kind = name,
			amount = -delta,
			source = "basic_holder",
		})
	end,
})

-- Hearts (normalized)
table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_CHANGE_ALL_BASIC,
	params = nil,
	Function = function(_, player, new_tbl, old_tbl)
		local losses = item.normalize_health_loss(old_tbl, new_tbl)
		for _, loss in ipairs(losses) do
			item.emit_loss(player, loss)
		end
	end,
})

-- Real card use
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_USE_CARD,
	params = nil,
	Function = function(_, card, player, use_flags)
		if not pocket_use.is_real_owned_use(use_flags) then return end
		card = tonumber(card) or 0
		if card <= 0 then return end
		item.emit_loss(player, {
			kind = "card",
			subtype = card,
			amount = 1,
			source = "use_card",
		})
	end,
})

-- Real pill use (PillColor from RGON)
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_USE_PILL,
	params = nil,
	Function = function(_, _effect, player, use_flags, pill_color)
		if not pocket_use.is_real_owned_use(use_flags) then return end
		pill_color = tonumber(pill_color) or 0
		if pill_color == 0 then return end
		item.emit_loss(player, {
			kind = "pill",
			subtype = pill_color,
			amount = 1,
			source = "use_pill",
		})
	end,
})

-- Active charge: PRE snapshot
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_USE_ITEM,
	params = nil,
	Function = function(_, item_id, _rng, player, use_flags, slot, _custom)
		if not pocket_use.is_real_owned_use(use_flags) then return end
		local idx = player_index(player)
		if idx == nil then return end
		slot = slot or ActiveSlot.SLOT_PRIMARY
		local total, main, bat = total_charge(player, slot)
		runtime.active_pre_use[idx] = runtime.active_pre_use[idx] or {}
		runtime.active_pre_use[idx][slot] = {
			item_id = item_id,
			main = main,
			battery = bat,
			total = total,
		}
	end,
})

-- Active charge: POST spend
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_USE_ITEM,
	params = nil,
	Function = function(_, item_id, _rng, player, use_flags, slot, _custom)
		local idx = player_index(player)
		if idx == nil then return end
		slot = slot or ActiveSlot.SLOT_PRIMARY
		local bag = runtime.active_pre_use[idx]
		local pre = bag and bag[slot] or nil
		if bag then bag[slot] = nil end
		if not pre then return end
		if not pocket_use.is_real_owned_use(use_flags) then return end
		local after_total = total_charge(player, slot)
		local spent = (pre.total or 0) - after_total
		if spent > 0 then
			item.emit_loss(player, {
				kind = "charge",
				amount = spent,
				source = "active_use",
				active_slot = slot,
				active_item = item_id,
			})
		end
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_REWIND,
	params = nil,
	Function = function(_)
		-- Only clear transient charge transaction cache.
		-- Authoritative loss queues live in consumer save.elses and already rewind.
		runtime.active_pre_use = {}
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	params = nil,
	Function = function(_)
		runtime.active_pre_use = {}
	end,
})

return item
