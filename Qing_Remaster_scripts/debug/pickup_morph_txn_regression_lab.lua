-- Pickup Morph Transaction pairing regression (M1–M7).
-- ImGui → Debug → Tests → Morph Transaction Regression
-- Pure pairing tests do not require live Morph; M2 optional live D6.

local morph_txn = require("Qing_Remaster_scripts.others.Pickup_Morph_Transaction_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")

local lab = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "pickup_morph_txn_regression_lab_",
}

local state = {
	status = "Idle",
	results = {},
	last_report = "",
}

local function pass_fail(ok, detail)
	return {status = ok and "PASS" or "FAIL", detail = detail, ok = ok == true}
end

local function set_result(id, row)
	state.results[id] = row
end

local function fake_pickup(fields)
	return {
		Type = fields.type or EntityType.ENTITY_PICKUP,
		Variant = fields.variant or PickupVariant.PICKUP_COLLECTIBLE,
		SubType = fields.subtype or 0,
		InitSeed = fields.init_seed or 1,
	}
end

local function reset_lab_consumer()
	morph_txn.unregister("MorphTxnLab")
	morph_txn.clear_runtime()
	morph_txn.debug_reset_counters()
end

local function push_lab_pre(opts)
	opts = opts or {}
	local frame = Game():GetFrameCount()
	return morph_txn.debug_push_pre({
		owner = opts.owner or "MorphTxnLab",
		frame = opts.frame or frame,
		previous_type = opts.previous_type or EntityType.ENTITY_PICKUP,
		previous_variant = opts.previous_variant or PickupVariant.PICKUP_COLLECTIBLE,
		previous_subtype = opts.previous_subtype or 100,
		previous_init_seed = opts.previous_init_seed or 111,
		target_type = opts.target_type or EntityType.ENTITY_PICKUP,
		target_variant = opts.target_variant or PickupVariant.PICKUP_COLLECTIBLE,
		target_subtype = opts.target_subtype or 200,
		keep_price = opts.keep_price == true,
		keep_seed = opts.keep_seed ~= false,
		ignore_modifiers = opts.ignore_modifiers == true,
		source_snapshot = opts.source_snapshot or {tag = "lab"},
		policy = opts.policy or {zero_subtype_is_transient = true},
	})
end

--- M1 keepSeed=true → STATE_SWITCH pairing
local function run_m1()
	reset_lab_consumer()
	local seed = 424242
	push_lab_pre({
		previous_subtype = 100,
		previous_init_seed = seed,
		target_subtype = 200,
		keep_seed = true,
	})
	local pickup = fake_pickup({subtype = 200, init_seed = seed})
	local pre, mismatch = morph_txn.take_pre(
		"MorphTxnLab",
		pickup,
		EntityType.ENTITY_PICKUP,
		PickupVariant.PICKUP_COLLECTIBLE,
		100,
		false,
		true,
		false
	)
	local kind = consistance_holder.classify_morph(
		{init_seed = seed, type = 5, variant = 100, subtype = 100},
		{init_seed = seed, type = 5, variant = 100, subtype = 200},
		{zero_subtype_is_transient = true}
	)
	local ok = pre ~= nil
		and mismatch ~= true
		and kind == "STATE_SWITCH"
		and pre.previous_init_seed == seed
		and pre.target_subtype == 200
	set_result("M1", pass_fail(ok, string.format(
		"pre=%s mismatch=%s kind=%s",
		tostring(pre ~= nil),
		tostring(mismatch),
		tostring(kind)
	)))
end

--- M2 keepSeed=false / different InitSeed → SUPERSEDE
local function run_m2()
	reset_lab_consumer()
	push_lab_pre({
		previous_subtype = 100,
		previous_init_seed = 111,
		target_subtype = 200,
		keep_seed = false,
	})
	local pickup = fake_pickup({subtype = 200, init_seed = 999})
	local pre, mismatch = morph_txn.take_pre(
		"MorphTxnLab",
		pickup,
		EntityType.ENTITY_PICKUP,
		PickupVariant.PICKUP_COLLECTIBLE,
		100,
		false,
		false,
		false
	)
	local kind = consistance_holder.classify_morph(
		{init_seed = 111, type = 5, variant = 100, subtype = 100},
		{init_seed = 999, type = 5, variant = 100, subtype = 200},
		{zero_subtype_is_transient = true}
	)
	local ok = pre ~= nil and mismatch ~= true and kind == "SUPERSEDE"
	set_result("M2", pass_fail(ok, string.format(
		"pre=%s kind=%s after_seed=%s",
		tostring(pre ~= nil),
		tostring(kind),
		tostring(pickup.InitSeed)
	)))
end

--- M3 two pedestals same frame: no cross-pair
local function run_m3()
	reset_lab_consumer()
	push_lab_pre({
		previous_subtype = 10,
		previous_init_seed = 1,
		target_subtype = 11,
		keep_seed = true,
		source_snapshot = {id = "A"},
	})
	push_lab_pre({
		previous_subtype = 20,
		previous_init_seed = 2,
		target_subtype = 21,
		keep_seed = true,
		source_snapshot = {id = "B"},
	})
	local b = fake_pickup({subtype = 21, init_seed = 2})
	local a = fake_pickup({subtype = 11, init_seed = 1})
	local pre_b = morph_txn.take_pre(
		"MorphTxnLab", b,
		EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, 20,
		false, true, false
	)
	local pre_a = morph_txn.take_pre(
		"MorphTxnLab", a,
		EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, 10,
		false, true, false
	)
	local ok = pre_a and pre_b
		and pre_a.source_snapshot and pre_a.source_snapshot.id == "A"
		and pre_b.source_snapshot and pre_b.source_snapshot.id == "B"
	set_result("M3", pass_fail(ok, string.format(
		"A=%s B=%s",
		tostring(pre_a and pre_a.source_snapshot and pre_a.source_snapshot.id),
		tostring(pre_b and pre_b.source_snapshot and pre_b.source_snapshot.id)
	)))
end

--- M4 POST subtype ≠ requested → fallback pair + target_mismatch
local function run_m4()
	reset_lab_consumer()
	push_lab_pre({
		previous_subtype = 100,
		previous_init_seed = 55,
		target_subtype = 200,
		keep_seed = true,
	})
	local pickup = fake_pickup({subtype = 999, init_seed = 55})
	local pre, mismatch = morph_txn.take_pre(
		"MorphTxnLab",
		pickup,
		EntityType.ENTITY_PICKUP,
		PickupVariant.PICKUP_COLLECTIBLE,
		100,
		false,
		true,
		false
	)
	local ok = pre ~= nil and mismatch == true
	set_result("M4", pass_fail(ok, string.format(
		"pre=%s mismatch=%s requested=%s got=%s",
		tostring(pre ~= nil),
		tostring(mismatch),
		tostring(pre and pre.target_subtype),
		tostring(pickup.SubType)
	)))
end

--- M5 unregistered consumer → zero stack side effects from register path
local function run_m5()
	reset_lab_consumer()
	morph_txn.unregister("NeverRegistered")
	local before = morph_txn.get_debug_snapshot()
	local depth0 = before.stack_depth or 0
	-- No consumer: PRE callback would no-op; stack stays empty after clear.
	local ok = depth0 == 0 and #(morph_txn._consumers or {}) == 0
		or (before.consumer_count == 0 and depth0 == 0)
	set_result("M5", pass_fail(ok, string.format(
		"consumers=%s stack=%s",
		tostring(before.consumer_count),
		tostring(depth0)
	)))
end

--- M6 capture=nil → no PRE stack entry
local function run_m6()
	reset_lab_consumer()
	local captures = 0
	morph_txn.register("MorphTxnLab", {
		priority = 0,
		match_pre = function()
			return true
		end,
		capture = function()
			captures = captures + 1
			return nil
		end,
	})
	-- Simulate PRE path manually: match + capture nil must not push.
	local snap = nil
	local consumer = nil
	for _, c in ipairs(morph_txn._consumers) do
		if c.owner == "MorphTxnLab" then
			consumer = c
			break
		end
	end
	if consumer and consumer.capture then
		snap = consumer.capture(fake_pickup({subtype = 1}))
	end
	local depth = morph_txn.get_debug_snapshot().stack_depth
	local ok = snap == nil and depth == 0 and captures == 1
	morph_txn.unregister("MorphTxnLab")
	set_result("M6", pass_fail(ok, string.format(
		"snap_nil=%s depth=%s captures=%d",
		tostring(snap == nil),
		tostring(depth),
		captures
	)))
end

--- M7 nested Morph: LIFO full-match order
local function run_m7()
	reset_lab_consumer()
	push_lab_pre({
		previous_subtype = 1,
		previous_init_seed = 10,
		target_subtype = 2,
		source_snapshot = {step = 1},
	})
	push_lab_pre({
		previous_subtype = 2,
		previous_init_seed = 10,
		target_subtype = 3,
		source_snapshot = {step = 2},
	})
	local inner = fake_pickup({subtype = 3, init_seed = 10})
	local outer = fake_pickup({subtype = 2, init_seed = 10})
	local pre_inner = morph_txn.take_pre(
		"MorphTxnLab", inner,
		EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, 2,
		false, true, false
	)
	local pre_outer = morph_txn.take_pre(
		"MorphTxnLab", outer,
		EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, 1,
		false, true, false
	)
	local ok = pre_inner and pre_outer
		and pre_inner.source_snapshot.step == 2
		and pre_outer.source_snapshot.step == 1
	set_result("M7", pass_fail(ok, string.format(
		"inner_step=%s outer_step=%s",
		tostring(pre_inner and pre_inner.source_snapshot and pre_inner.source_snapshot.step),
		tostring(pre_outer and pre_outer.source_snapshot and pre_outer.source_snapshot.step)
	)))
end

--- M8 non-collectible same-category Morph (heart → heart, SUPERSEDE)
local function run_m8()
	reset_lab_consumer()
	local heart = PickupVariant.PICKUP_HEART
	push_lab_pre({
		previous_variant = heart,
		previous_subtype = 1,
		previous_init_seed = 111,
		target_variant = heart,
		target_subtype = 2,
		keep_seed = false,
		source_snapshot = {kind = "heart"},
	})
	local pickup = fake_pickup({
		variant = heart,
		subtype = 2,
		init_seed = 222,
	})
	local pre, mismatch = morph_txn.take_pre(
		"MorphTxnLab",
		pickup,
		EntityType.ENTITY_PICKUP,
		heart,
		1,
		false,
		false,
		false
	)
	local kind = consistance_holder.classify_morph(
		{init_seed = 111, type = 5, variant = heart, subtype = 1},
		{init_seed = 222, type = 5, variant = heart, subtype = 2},
		{zero_subtype_is_transient = true}
	)
	local ok = pre ~= nil
		and mismatch ~= true
		and kind == "SUPERSEDE"
		and pre.previous_variant == heart
		and pre.target_variant == heart
		and pickup.InitSeed == 222
	set_result("M8", pass_fail(ok, string.format(
		"pre=%s mismatch=%s kind=%s prev_v=%s tgt_v=%s",
		tostring(pre ~= nil),
		tostring(mismatch),
		tostring(kind),
		tostring(pre and pre.previous_variant),
		tostring(pre and pre.target_variant)
	)))
end

--- M9 D20-style cross-variant Morph (heart → bomb)
local function run_m9()
	reset_lab_consumer()
	local heart = PickupVariant.PICKUP_HEART
	local bomb = PickupVariant.PICKUP_BOMB
	push_lab_pre({
		previous_variant = heart,
		previous_subtype = 1,
		previous_init_seed = 333,
		target_variant = bomb,
		target_subtype = 1,
		keep_seed = false,
		source_snapshot = {kind = "d20"},
	})
	local pickup = fake_pickup({
		variant = bomb,
		subtype = 1,
		init_seed = 444,
	})
	local pre, mismatch = morph_txn.take_pre(
		"MorphTxnLab",
		pickup,
		EntityType.ENTITY_PICKUP,
		heart,
		1,
		false,
		false,
		false
	)
	local ok = pre ~= nil
		and mismatch ~= true
		and pre.previous_variant == heart
		and pre.target_variant == bomb
		and pre.previous_variant ~= pre.target_variant
	set_result("M9", pass_fail(ok, string.format(
		"pre=%s mismatch=%s prev_v=%s tgt_v=%s",
		tostring(pre ~= nil),
		tostring(mismatch),
		tostring(pre and pre.previous_variant),
		tostring(pre and pre.target_variant)
	)))
end

function lab.run_all()
	state.status = "Running"
	run_m1()
	run_m2()
	run_m3()
	run_m4()
	run_m5()
	run_m6()
	run_m7()
	run_m8()
	run_m9()
	reset_lab_consumer()
	local pass, fail = 0, 0
	for _, row in pairs(state.results) do
		if row.ok then
			pass = pass + 1
		else
			fail = fail + 1
		end
	end
	state.status = string.format("Done PASS=%d FAIL=%d", pass, fail)
	state.last_report = lab.get_status_text()
	return fail == 0
end

function lab.run_m1() run_m1() end
function lab.run_m2() run_m2() end
function lab.run_m3() run_m3() end
function lab.run_m4() run_m4() end
function lab.run_m5() run_m5() end
function lab.run_m6() run_m6() end
function lab.run_m7() run_m7() end
function lab.run_m8() run_m8() end
function lab.run_m9() run_m9() end

function lab.reset_tests()
	reset_lab_consumer()
	state.results = {}
	state.status = "Idle"
	state.last_report = ""
end

function lab.get_status_text()
	local lines = {
		"Morph Transaction Regression",
		"status=" .. tostring(state.status),
	}
	local order = {"M1", "M2", "M3", "M4", "M5", "M6", "M7", "M8", "M9"}
	for _, id in ipairs(order) do
		local row = state.results[id]
		if row then
			lines[#lines + 1] = string.format(
				"%s %s — %s",
				id,
				row.status,
				tostring(row.detail or "")
			)
		else
			lines[#lines + 1] = id .. " —"
		end
	end
	return table.concat(lines, "\n")
end

function lab.copy_report()
	local text = lab.get_status_text()
	if Isaac and Isaac.SetClipboard then
		Isaac.SetClipboard(text)
	end
	return text
end

return lab
