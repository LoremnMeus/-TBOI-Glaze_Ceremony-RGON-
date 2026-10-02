-- Pickup Morph PRE→POST pairing bridge.
-- Consistance owns lifecycle classify; consumers own what to do with txn.target.
-- Pairing algorithm extracted from Item_Perhaps_Chosen (no GetPtrHash across Morph).

local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	own_key = "Pickup_Morph_Transaction_holder_",
	_consumers = {},
	_stack = {},
	debug = {
		pre_captured = 0,
		post_paired = 0,
		pair_mismatch = 0,
		pair_miss = 0,
		dispatched = 0,
		capture_nil = 0,
		last_kind = nil,
		last_owner = nil,
		last_target_mismatch = false,
	},
}

local DEFAULT_POLICY = {zero_subtype_is_transient = true}

local function game_frame()
	return Game():GetFrameCount()
end

local function as_pickup(ent)
	if not ent then
		return nil
	end
	local p = ent.ToPickup and ent:ToPickup() or ent
	if not p or p.Type ~= EntityType.ENTITY_PICKUP then
		return nil
	end
	-- All pickup variants (heart/bomb/chest/collectible/…). Consumers filter via match_pre.
	return p
end

local function sort_consumers()
	table.sort(item._consumers, function(a, b)
		local pa = tonumber(a.priority) or 0
		local pb = tonumber(b.priority) or 0
		if pa ~= pb then
			return pa < pb
		end
		return tostring(a.owner) < tostring(b.owner)
	end)
end

local function find_consumer(owner)
	for _, c in ipairs(item._consumers) do
		if c.owner == owner then
			return c
		end
	end
	return nil
end

function item.pre_fields_match(pre, prevType, prevVariant, prevSubtype, keepPrice, keepSeed, ignoreModifiers)
	if not pre then
		return false
	end
	if pre.previous_type ~= prevType then
		return false
	end
	if pre.previous_variant ~= prevVariant then
		return false
	end
	if pre.previous_subtype ~= prevSubtype then
		return false
	end
	if pre.keep_price ~= (keepPrice == true) then
		return false
	end
	if pre.keep_seed ~= (keepSeed == true) then
		return false
	end
	if pre.ignore_modifiers ~= (ignoreModifiers == true) then
		return false
	end
	return true
end

function item.target_fields_match(pre, pickup)
	if not pre or not pickup then
		return false
	end
	return pre.target_type == pickup.Type
		and pre.target_variant == pickup.Variant
		and pre.target_subtype == pickup.SubType
end

local function prune_stale_stack()
	local stack = item._stack
	if not stack or #stack == 0 then
		return
	end
	local frame = game_frame()
	local keep = {}
	for _, pre in ipairs(stack) do
		if pre and type(pre.frame) == "number" and (frame - pre.frame) <= 1 then
			keep[#keep + 1] = pre
		end
	end
	item._stack = keep
end

--- Take PRE for one owner. Prefer full previous+keep+target match; fallback stack-top previous+keep.
--- Returns pre, target_mismatch (bool).
function item.take_pre(owner, pickup, prevType, prevVariant, prevSubtype, keepPrice, keepSeed, ignoreModifiers)
	local stack = item._stack
	if not stack or #stack == 0 then
		return nil, false
	end
	local frame = game_frame()

	for i = #stack, 1, -1 do
		local pre = stack[i]
		if pre
			and pre.owner == owner
			and pre.frame == frame
			and item.pre_fields_match(pre, prevType, prevVariant, prevSubtype, keepPrice, keepSeed, ignoreModifiers)
			and item.target_fields_match(pre, pickup)
		then
			table.remove(stack, i)
			item.debug.post_paired = (item.debug.post_paired or 0) + 1
			item.debug.last_target_mismatch = false
			return pre, false
		end
	end

	for i = #stack, 1, -1 do
		local pre = stack[i]
		if pre
			and pre.owner == owner
			and pre.frame == frame
			and item.pre_fields_match(pre, prevType, prevVariant, prevSubtype, keepPrice, keepSeed, ignoreModifiers)
		then
			table.remove(stack, i)
			local mismatch = not item.target_fields_match(pre, pickup)
			if mismatch then
				item.debug.pair_mismatch = (item.debug.pair_mismatch or 0) + 1
				item.debug.last_target_mismatch = true
			else
				item.debug.post_paired = (item.debug.post_paired or 0) + 1
				item.debug.last_target_mismatch = false
			end
			return pre, mismatch
		end
	end

	item.debug.pair_miss = (item.debug.pair_miss or 0) + 1
	item.debug.last_target_mismatch = false
	return nil, false
end

local function push_pre(pre)
	item._stack = item._stack or {}
	item._stack[#item._stack + 1] = pre
	item.debug.pre_captured = (item.debug.pre_captured or 0) + 1
end

local function dispatch_consumer(consumer, txn)
	if not consumer or not txn then
		return
	end
	item.debug.dispatched = (item.debug.dispatched or 0) + 1
	item.debug.last_kind = txn.kind
	item.debug.last_owner = consumer.owner

	if type(consumer.on_post) == "function" then
		pcall(consumer.on_post, txn)
	end

	local kind = txn.kind
	if kind == "SUPERSEDE" and type(consumer.on_supersede) == "function" then
		pcall(consumer.on_supersede, txn)
	elseif kind == "STATE_SWITCH" and type(consumer.on_state_switch) == "function" then
		pcall(consumer.on_state_switch, txn)
	elseif kind == "EMPTY_PENDING" and type(consumer.on_empty_pending) == "function" then
		pcall(consumer.on_empty_pending, txn)
	elseif kind == "SAME_LIFETIME" and type(consumer.on_same_lifetime) == "function" then
		pcall(consumer.on_same_lifetime, txn)
	end
end

local function build_txn(pre, pickup, kind, target_mismatch)
	return {
		owner = pre.owner,
		before = {
			init_seed = pre.previous_init_seed,
			type = pre.previous_type,
			variant = pre.previous_variant,
			subtype = pre.previous_subtype,
		},
		requested = {
			type = pre.target_type,
			variant = pre.target_variant,
			subtype = pre.target_subtype,
			keep_price = pre.keep_price,
			keep_seed = pre.keep_seed,
			ignore_modifiers = pre.ignore_modifiers,
		},
		after = {
			init_seed = pickup.InitSeed,
			type = pickup.Type,
			variant = pickup.Variant,
			subtype = pickup.SubType or 0,
		},
		kind = kind,
		source_snapshot = pre.source_snapshot,
		target = pickup,
		target_mismatch = target_mismatch == true,
		frame = pre.frame,
	}
end

--- Register a Morph consumer. capture may return nil to skip this Morph.
function item.register(owner, handlers)
	if owner == nil or type(handlers) ~= "table" then
		return false
	end
	item.unregister(owner)
	item._consumers[#item._consumers + 1] = {
		owner = owner,
		priority = tonumber(handlers.priority) or 0,
		match_pre = handlers.match_pre,
		capture = handlers.capture,
		policy = handlers.policy,
		on_post = handlers.on_post,
		on_state_switch = handlers.on_state_switch,
		on_supersede = handlers.on_supersede,
		on_empty_pending = handlers.on_empty_pending,
		on_same_lifetime = handlers.on_same_lifetime,
	}
	sort_consumers()
	return true
end

function item.unregister(owner)
	if owner == nil then
		return false
	end
	local kept = {}
	local removed = false
	for _, c in ipairs(item._consumers) do
		if c.owner == owner then
			removed = true
		else
			kept[#kept + 1] = c
		end
	end
	item._consumers = kept
	local stack = item._stack
	if stack then
		local keep = {}
		for _, pre in ipairs(stack) do
			if not pre or pre.owner ~= owner then
				keep[#keep + 1] = pre
			end
		end
		item._stack = keep
	end
	return removed
end

function item.clear_runtime()
	item._stack = {}
end

function item.get_debug_snapshot()
	return {
		consumer_count = #item._consumers,
		stack_depth = #(item._stack or {}),
		debug = {
			pre_captured = item.debug.pre_captured,
			post_paired = item.debug.post_paired,
			pair_mismatch = item.debug.pair_mismatch,
			pair_miss = item.debug.pair_miss,
			dispatched = item.debug.dispatched,
			capture_nil = item.debug.capture_nil,
			last_kind = item.debug.last_kind,
			last_owner = item.debug.last_owner,
			last_target_mismatch = item.debug.last_target_mismatch,
		},
	}
end

--- True if any open PRE on this frame requests this pickup's Type/Variant/SubType.
function item.has_open_pre_targeting(pickup)
	local p = as_pickup(pickup)
	if not p then
		return false
	end
	local stack = item._stack
	if not stack or #stack == 0 then
		return false
	end
	local frame = game_frame()
	for _, pre in ipairs(stack) do
		if pre
			and pre.frame == frame
			and pre.target_type == p.Type
			and pre.target_variant == p.Variant
			and pre.target_subtype == p.SubType
		then
			return true
		end
	end
	return false
end

-- DEBUG / regression: inject a PRE entry without going through callbacks.
function item.debug_push_pre(pre)
	if type(pre) ~= "table" or pre.owner == nil then
		return false
	end
	pre.frame = pre.frame or game_frame()
	pre.keep_price = pre.keep_price == true
	pre.keep_seed = pre.keep_seed == true
	pre.ignore_modifiers = pre.ignore_modifiers == true
	push_pre(pre)
	return true
end

function item.debug_reset_counters()
	item.debug.pre_captured = 0
	item.debug.post_paired = 0
	item.debug.pair_mismatch = 0
	item.debug.pair_miss = 0
	item.debug.dispatched = 0
	item.debug.capture_nil = 0
	item.debug.last_kind = nil
	item.debug.last_owner = nil
	item.debug.last_target_mismatch = false
end

-- PRE: after Consistance remember (-200), before late business. Capture only.
if ModCallbacks.MC_PRE_PICKUP_MORPH then
	table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
		CallBack = ModCallbacks.MC_PRE_PICKUP_MORPH,
		params = nil,
		priority = -80,
		Function = function(_, pickup, newType, newVariant, newSubtype, keepPrice, keepSeed, ignoreModifiers)
			local p = as_pickup(pickup)
			if not p then
				return
			end
			prune_stale_stack()
			local frame = game_frame()
			for _, consumer in ipairs(item._consumers) do
				local matched = true
				if type(consumer.match_pre) == "function" then
					local ok, ret = pcall(consumer.match_pre, p)
					matched = ok and ret == true
				end
				if matched then
					local snap = nil
					if type(consumer.capture) == "function" then
						local ok, ret = pcall(consumer.capture, p)
						if ok then
							snap = ret
						end
					else
						snap = {}
					end
					if snap == nil then
						item.debug.capture_nil = (item.debug.capture_nil or 0) + 1
					else
						push_pre({
							owner = consumer.owner,
							frame = frame,
							previous_type = p.Type,
							previous_variant = p.Variant,
							previous_subtype = p.SubType,
							previous_init_seed = p.InitSeed,
							target_type = newType,
							target_variant = newVariant,
							target_subtype = newSubtype,
							keep_price = keepPrice == true,
							keep_seed = keepSeed == true,
							ignore_modifiers = ignoreModifiers == true,
							source_snapshot = snap,
							policy = consumer.policy,
						})
					end
				end
			end
		end,
	})
end

-- POST: after Consistance morph policy; pair + classify + dispatch. No Consistance mutation here.
if ModCallbacks.MC_POST_PICKUP_MORPH then
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_PICKUP_MORPH,
		params = nil,
		priority = 40,
		Function = function(_, pickup, prevType, prevVariant, prevSubtype, keepPrice, keepSeed, ignoreModifiers)
			local p = as_pickup(pickup)
			if not p then
				return
			end
			prune_stale_stack()
			for _, consumer in ipairs(item._consumers) do
				local pre, target_mismatch = item.take_pre(
					consumer.owner,
					p,
					prevType,
					prevVariant,
					prevSubtype,
					keepPrice,
					keepSeed,
					ignoreModifiers
				)
				if pre then
					local before = {
						init_seed = pre.previous_init_seed,
						type = pre.previous_type,
						variant = pre.previous_variant,
						subtype = pre.previous_subtype,
					}
					local after = {
						init_seed = p.InitSeed,
						type = p.Type,
						variant = p.Variant,
						subtype = p.SubType or 0,
					}
					local policy = pre.policy or consumer.policy or DEFAULT_POLICY
					local kind = consistance_holder.classify_morph(before, after, policy)
					local txn = build_txn(pre, p, kind, target_mismatch)
					dispatch_consumer(consumer, txn)
				end
			end
		end,
	})
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	priority = 0,
	Function = function()
		prune_stale_stack()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		item.clear_runtime()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	params = nil,
	Function = function()
		item.clear_runtime()
		item.debug_reset_counters()
	end,
})

return item
