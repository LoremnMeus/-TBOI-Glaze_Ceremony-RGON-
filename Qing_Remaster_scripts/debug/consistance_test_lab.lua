-- Consistance Test Lab：按帧 Runner + Morph Semantic Probe + Family Regression。
-- ImGui → Debug → Consistance Test Lab
-- Semantic Probe 结果一律 OBSERVED；Regression 才 PASS/FAIL。

local enums = require("Qing_Remaster_scripts.core.enums")
local consistance = require("Qing_Remaster_scripts.others.Consistance_holder")
local lifetime = require("Qing_Remaster_scripts.others.Entity_lifetime_holder")
local essm_suite = require("Qing_Remaster_scripts.debug.consistance_test_lab_essm")
local unique_suite = require("Qing_Remaster_scripts.debug.consistance_test_lab_unique")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder")

local lab = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	own_key = "consistance_test_lab_",
}

local MARK = "_ConsistanceTestLab"
local OWNER_PREFIX = "_ConsistanceLab_"
local FAMILY_PROBE = "_ConsistanceFamilyProbe_"

-- 无特殊副作用的 vanilla passive，用于拾取/底座测试
local ITEM_A = CollectibleType.COLLECTIBLE_BREAKFAST
local ITEM_B = CollectibleType.COLLECTIBLE_LUNCH
local ITEM_C = CollectibleType.COLLECTIBLE_DINNER
local ITEM_D = CollectibleType.COLLECTIBLE_DESSERT

local USE_FLAGS = UseFlag.USE_NOANIM

local runner = {
	running = false,
	suite_name = nil,
	suite = nil,
	case_index = 0,
	step_index = 0,
	wait = 0,
	wait_until = nil,
	wait_timeout = 0,
	context = nil,
	results = {},
	trace = {},
	semantic_probe_active = false,
	run_id = 0,
	status = "Idle",
	last_error = nil,
	last_export_path = nil,
	last_export_error = nil,
	last_export_note = nil,
	exported_result_count = 0,
	suite_session = 0,
}

local function game_frame()
	local f = 0
	pcall(function() f = Game():GetFrameCount() end)
	return f
end

local function player0()
	return Isaac.GetPlayer(0)
end

local function essm_token(ent)
	if not ent then return nil end
	if not lifetime.is_available() then return nil end
	local ok, tok = pcall(function() return lifetime.get_token(ent) end)
	if ok then return tok end
	return nil
end

local function ptr_of(ent)
	if not ent then return nil end
	local ok, v = pcall(GetPtrHash, ent)
	if ok then return tostring(v) end
	return nil
end

local function identity_of(ent)
	if not ent then return nil end
	return {
		seed = ent.InitSeed,
		type = ent.Type,
		variant = ent.Variant,
		subtype = ent.SubType or ent.Subtype or 0,
		ptr = ptr_of(ent),
		essm_token = essm_token(ent),
	}
end

local function is_lab_entity(ent)
	if not ent then return false end
	local ok, data = pcall(function() return ent:GetData() end)
	if not ok or type(data) ~= "table" then return false end
	local mark = data[MARK]
	return type(mark) == "table"
end

-- Morph 可能清掉 GetData 标记；用 ptr 注册表保证 PRE/POST 都能计入当前 case。
local function register_lab_ptr(ent, ctx)
	local ptr = ptr_of(ent)
	if not ptr then return end
	runner.lab_ptrs = runner.lab_ptrs or {}
	runner.lab_ptrs[ptr] = true
	if ctx then
		ctx.lab_ptrs = ctx.lab_ptrs or {}
		ctx.lab_ptrs[ptr] = true
	end
end

local function is_lab_ptr(ent)
	if is_lab_entity(ent) then return true end
	local ptr = ptr_of(ent)
	if not ptr then return false end
	if runner.lab_ptrs and runner.lab_ptrs[ptr] then return true end
	local ctx = runner.context
	if ctx and ctx.lab_ptrs and ctx.lab_ptrs[ptr] then return true end
	-- Morph 后 InitSeed/实体可能换 wrapper：若当前 case 正在跑且实体在 tracked 列表，也算 Lab
	if ctx and ctx.tracked then
		for _, row in ipairs(ctx.tracked) do
			if row.alive and row.ent then
				local ok, same = pcall(function()
					return GetPtrHash(row.ent) == GetPtrHash(ent)
				end)
				if ok and same then return true end
			end
		end
	end
	return false
end

local function push_trace(event, fields)
	fields = fields or {}
	local row = {
		event = tostring(event),
		frame = game_frame(),
		ptr = fields.ptr,
		seed = fields.seed,
		subtype = fields.subtype,
		before = fields.before,
		after = fields.after,
		requested = fields.requested,
		previous = fields.previous,
		keep_seed = fields.keep_seed,
		kept_seed = fields.kept_seed,
		keep_price = fields.keep_price,
		kept_price = fields.kept_price,
		ignore_modifiers = fields.ignore_modifiers,
		ignored_modifiers = fields.ignored_modifiers,
		essm_token = fields.essm_token,
		extra = fields.extra,
	}
	local buf = runner.trace
	buf[#buf + 1] = row
	if runner.context then
		runner.context.trace = runner.context.trace or {}
		runner.context.trace[#runner.context.trace + 1] = row
		local c = runner.context.counts
		if c then
			if event == "PRE_MORPH" then c.pre_morph = (c.pre_morph or 0) + 1 end
			if event == "POST_MORPH" then c.post_morph = (c.post_morph or 0) + 1 end
			if event == "PICKUP_INIT" then c.pickup_init = (c.pickup_init or 0) + 1 end
			if event == "POST_PICKUP_COLLECTIBLE" then c.pickup_success = (c.pickup_success or 0) + 1 end
			if event == "ENTITY_GONE" then c.entity_gone = (c.entity_gone or 0) + 1 end
			if event == "SUBTYPE_CHANGE" then c.subtype_change = (c.subtype_change or 0) + 1 end
			if event == "SEED_CHANGE" then c.seed_change = (c.seed_change or 0) + 1 end
		end
	end
	while #buf > 400 do table.remove(buf, 1) end
end

local function observe(ctx, key, value)
	ctx.observations = ctx.observations or {}
	ctx.observations[key] = value
end

local function expect(ctx, ok, message)
	ctx.assertions = ctx.assertions or {}
	ctx.assertions[#ctx.assertions + 1] = { ok = ok == true, text = tostring(message) }
	if not ok then
		ctx.failures = ctx.failures or {}
		ctx.failures[#ctx.failures + 1] = tostring(message)
	end
end

local function mark_entity(ent, ctx, tag)
	if not ent then return end
	local data = ent:GetData()
	data[MARK] = {
		test_id = ctx.test_id,
		case_id = ctx.case_id,
		run_id = ctx.run_id,
		tag = tag or "pedestal",
	}
	register_lab_ptr(ent, ctx)
	ctx.spawned = ctx.spawned or {}
	ctx.spawned[#ctx.spawned + 1] = ent
	ctx.tracked = ctx.tracked or {}
	ctx.tracked[#ctx.tracked + 1] = {
		ent = ent,
		alive = true,
		last = identity_of(ent),
	}
end

local function spawn_collectible(ctx, subtype, pos)
	local player = player0()
	local room = Game():GetRoom()
	local center = room and room:GetCenterPos() or Vector(320, 280)
	pos = pos or (center + Vector((#((ctx and ctx.spawned) or {}) % 3 - 1) * 40, 0))
	local ent = Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, subtype, pos, Vector.Zero, nil)
	local pickup = ent and ent:ToPickup() or nil
	if pickup then
		pickup.Wait = 0
		pcall(function() pickup.Price = 0 end)
		mark_entity(pickup, ctx, "pedestal")
	end
	return pickup
end

local function morph_pickup(pickup, subtype, keep_seed)
	if not pickup then return end
	-- Morph(Type, Variant, SubType, KeepPrice, KeepSeed, IgnoreModifiers)
	pickup:Morph(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, subtype, true, keep_seed == true, true)
end

--- 空底座：Morph(SubType=0) 实测会 reroll 成随机道具，不能当 empty。
--- 对齐 Reserved Judgment / Book of Voice：优先 TryRemoveCollectible。
local function empty_collectible_pedestal(pickup)
	if not pickup then return false end
	local ok, removed = pcall(function()
		if pickup.TryRemoveCollectible then
			return pickup:TryRemoveCollectible()
		end
		return false
	end)
	if ok and removed == true and (pickup.SubType or 0) == 0 then
		return true
	end
	return (pickup:Exists() and (pickup.SubType or 0) == 0) == true
end

--- 普通拾取留空底座（引擎路径；不走 Morph）。
local function pickup_leave_empty(ctx)
	local player = player0()
	local p = ctx.pickup
	if not (player and p and p:Exists()) then return false end
	player.Position = p.Position
	return true
end

local function family_owners_summary(identity)
	local states = consistance.get_family_states(identity) or {}
	local parts = {}
	for st, row in pairs(states) do
		local owners = row.owners or {}
		parts[#parts + 1] = tostring(st) .. "=[" .. table.concat(owners, ",") .. "]"
	end
	table.sort(parts)
	return table.concat(parts, "; ")
end

local function use_active(collectible)
	local player = player0()
	if not player then return false end
	player:UseActiveItem(collectible, USE_FLAGS)
	return true
end

local function owner_name(ctx)
	return OWNER_PREFIX .. tostring(ctx.run_id) .. "_" .. tostring(ctx.case_id)
end

local function hold_probe(ctx, pickup, payload)
	if not pickup then return end
	local data = pickup:GetData()
	data._Data = data._Data or {}
	local owner = ctx.owner or owner_name(ctx)
	ctx.owner = owner
	data._Data[owner] = payload or data._Data[owner] or {}
	consistance.try_hold_entity(pickup, owner, { consistance = true })
end

local function family_identity(pickup)
	if not pickup then return nil end
	return { init_seed = pickup.InitSeed, type = pickup.Type, variant = pickup.Variant }
end

local function family_state_count(identity)
	if not identity then return 0 end
	local states = consistance.get_family_states(identity) or {}
	local n = 0
	for _ in pairs(states) do n = n + 1 end
	return n
end

local function remove_collectible_to_count(player, id, target)
	if not player then return end
	local guard = 0
	while player:GetCollectibleNum(id) > target and guard < 32 do
		player:RemoveCollectible(id)
		guard = guard + 1
	end
end

local function cleanup_context(ctx)
	if not ctx then return end
	for _, ent in ipairs(ctx.spawned or {}) do
		pcall(function()
			if ent and ent.Exists and ent:Exists() then ent:Remove() end
		end)
	end
	local player = player0()
	if player and ctx.before and ctx.before.collectible_counts then
		for id, n in pairs(ctx.before.collectible_counts) do
			remove_collectible_to_count(player, id, n)
		end
	end
	if ctx.owner then
		consistance.purge_owners_by_prefix(ctx.owner)
	end
	consistance.purge_owners_by_prefix(OWNER_PREFIX)
	consistance.purge_owners_by_prefix(FAMILY_PROBE)
	if player and ctx.before and ctx.before.player_pos then
		pcall(function() player.Position = ctx.before.player_pos end)
	end
end

local function finish_case(ctx, status)
	ctx.status = status or ctx.status or "OBSERVED"
	if ctx.kind == "regression" then
		local fails = ctx.failures or {}
		if ctx.status == "TIMEOUT" then
			-- keep
		elseif #fails == 0 then
			ctx.status = "PASS"
		else
			ctx.status = "FAIL"
		end
	elseif ctx.kind == "essm" then
		local fails = ctx.failures or {}
		if ctx.status == "TIMEOUT" or ctx.status == "SKIPPED" then
			-- keep
		elseif #fails > 0 then
			ctx.status = "FAIL"
		elseif ctx.expect_observed == true then
			ctx.status = "OBSERVED"
		else
			ctx.status = "PASS"
		end
	elseif ctx.kind == "unique_shadow" then
		local fails = ctx.failures or {}
		if ctx.status == "TIMEOUT" or ctx.status == "SKIPPED" then
			-- keep
		elseif #fails > 0 then
			ctx.status = "FAIL"
		elseif ctx.expect_observed == true then
			ctx.status = "OBSERVED"
		elseif ctx.expect_warn == true and ctx._warn_noise == true then
			ctx.status = "WARN"
		else
			ctx.status = "PASS"
		end
	elseif ctx.kind == "engine" then
		local fails = ctx.failures or {}
		if ctx.status == "TIMEOUT" or ctx.status == "SKIPPED" then
			-- keep
		elseif ctx.engine_semantics_changed or #fails > 0 then
			ctx.status = "ENGINE_SEMANTICS_CHANGED"
		else
			ctx.status = "PASS"
		end
	elseif ctx.kind == "semantic" then
		if ctx.status ~= "TIMEOUT" and ctx.status ~= "SKIPPED" then
			ctx.status = "OBSERVED"
		end
	end
	runner.results[#runner.results + 1] = {
		name = ctx.name,
		kind = ctx.kind,
		status = ctx.status,
		suite = ctx.suite_name or runner.suite_name,
		session = ctx.suite_session or runner.suite_session,
		frame = game_frame(),
		observations = ctx.observations,
		assertions = ctx.assertions,
		failures = ctx.failures,
		trace = ctx.trace,
	}
	pcall(function()
		if ctx.cleanup then ctx.cleanup(ctx) end
	end)
	cleanup_context(ctx)
end

local function begin_case(case_def)
	runner.run_id = runner.run_id + 1
	local player = player0()
	local ctx = {
		name = case_def.name,
		kind = case_def.kind or "semantic",
		case_id = case_def.id or runner.case_index,
		run_id = runner.run_id,
		suite_name = runner.suite_name,
		suite_session = runner.suite_session,
		test_id = "lab_" .. tostring(runner.run_id),
		owner = OWNER_PREFIX .. tostring(runner.run_id) .. "_" .. tostring(case_def.id or runner.case_index),
		spawned = {},
		tracked = {},
		trace = {},
		counts = {
			pre_morph = 0,
			post_morph = 0,
			pickup_init = 0,
			pickup_success = 0,
			entity_gone = 0,
			subtype_change = 0,
			seed_change = 0,
		},
		observations = {},
		assertions = {},
		failures = {},
		status = "RUNNING",
		before = {
			player_pos = player and Vector(player.Position.X, player.Position.Y) or nil,
			collectible_counts = {},
			snapshot = consistance.get_debug_snapshot(),
		},
		setup = case_def.setup,
		cleanup = case_def.cleanup,
		verify = case_def.verify,
		expect_observed = case_def.expect_observed == true,
		expect_warn = case_def.expect_warn == true,
	}
	for _, id in ipairs({ ITEM_A, ITEM_B, ITEM_C, ITEM_D }) do
		ctx.before.collectible_counts[id] = player and player:GetCollectibleNum(id) or 0
	end
	local snap0 = consistance.get_debug_snapshot()
	ctx.before_policy = snap0.morph_policy or {}
	ctx.before_family_supersedes = snap0.family_supersedes or 0
	ctx.before_empty_gc = snap0.empty_collectible_families_cleaned or 0
	runner.context = ctx
	runner.trace = {}
	runner.lab_ptrs = {}
	local ok, err = pcall(function()
		if case_def.setup then case_def.setup(ctx) end
	end)
	if not ok then
		ctx.last_error = tostring(err)
		runner.last_error = tostring(err)
		finish_case(ctx, "FAIL")
		return false
	end
	return true
end

local function watch_identities(ctx)
	if not ctx or not ctx.tracked then return end
	for _, row in ipairs(ctx.tracked) do
		local ent = row.ent
		local alive = false
		pcall(function() alive = ent and ent:Exists() == true end)
		if row.alive and not alive then
			row.alive = false
			push_trace("ENTITY_GONE", {
				ptr = row.last and row.last.ptr,
				seed = row.last and row.last.seed,
				subtype = row.last and row.last.subtype,
				essm_token = row.last and row.last.essm_token,
			})
		elseif alive then
			local now = identity_of(ent)
			local last = row.last
			if last then
				if now.subtype ~= last.subtype then
					push_trace("SUBTYPE_CHANGE", {
						ptr = now.ptr,
						seed = now.seed,
						subtype = now.subtype,
						before = last,
						after = now,
						essm_token = now.essm_token,
					})
				end
				if now.seed ~= last.seed then
					push_trace("SEED_CHANGE", {
						ptr = now.ptr,
						seed = now.seed,
						subtype = now.subtype,
						before = last,
						after = now,
						essm_token = now.essm_token,
					})
				end
			end
			row.last = now
		end
	end
end

local function summarize_case_observations(ctx)
	observe(ctx, "pre_morph", ctx.counts.pre_morph or 0)
	observe(ctx, "post_morph", ctx.counts.post_morph or 0)
	observe(ctx, "pickup_init", ctx.counts.pickup_init or 0)
	observe(ctx, "pickup_success", ctx.counts.pickup_success or 0)
	observe(ctx, "entity_gone", (ctx.counts.entity_gone or 0) > 0)
	observe(ctx, "entity_gone_count", ctx.counts.entity_gone or 0)
	observe(ctx, "subtype_change", ctx.counts.subtype_change or 0)
	observe(ctx, "seed_change", ctx.counts.seed_change or 0)
	local pickup = ctx.pickup
	local exists = pickup and pickup.Exists and pickup:Exists()
	if exists then
		observe(ctx, "final_seed", pickup.InitSeed)
		observe(ctx, "final_subtype", pickup.SubType)
		observe(ctx, "final_ptr", ptr_of(pickup))
		observe(ctx, "entity_exists", true)
		observe(ctx, "subtype_zero", (pickup.SubType or 0) == 0)
		if ctx.start_seed ~= nil then
			observe(ctx, "seed_changed", ctx.start_seed ~= pickup.InitSeed)
		end
		if ctx.start_ptr ~= nil then
			observe(ctx, "ptr_same", ctx.start_ptr == ptr_of(pickup))
		end
	else
		observe(ctx, "entity_exists", false)
		-- gone 后 seedΔ 无意义（避免 sibling/新实体噪声）
		observe(ctx, "seed_changed", "N/A")
		observe(ctx, "final_seed", nil)
		observe(ctx, "final_ptr", nil)
	end
	-- Consistance policy counters delta（本 case）
	local snap = consistance.get_debug_snapshot()
	local pol = snap.morph_policy or {}
	local before_pol = ctx.before_policy or {}
	observe(ctx, "policy_supersede_delta", (pol.supersede or 0) - (before_pol.supersede or 0))
	observe(ctx, "policy_state_switch_delta", (pol.state_switch or 0) - (before_pol.state_switch or 0))
	observe(ctx, "policy_empty_delta", (pol.empty_pending or 0) - (before_pol.empty_pending or 0))
	observe(ctx, "policy_same_delta", (pol.same_lifetime or 0) - (before_pol.same_lifetime or 0))
	observe(ctx, "family_supersede_delta", (snap.family_supersedes or 0) - (ctx.before_family_supersedes or 0))
end

---------------------------------------------------------------------------
-- Cases
---------------------------------------------------------------------------

local function case_direct_morph(name, id, keep_seed)
	return {
		id = id,
		name = name,
		kind = "semantic",
		setup = function(ctx)
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
			ctx.start_seed = ctx.pickup and ctx.pickup.InitSeed
			ctx.start_ptr = ptr_of(ctx.pickup)
			observe(ctx, "keep_seed", keep_seed == true)
			observe(ctx, "start_seed", ctx.start_seed)
			observe(ctx, "start_ptr", ctx.start_ptr)
		end,
		steps = {
			{ wait = 2 },
			{
				run = function(ctx)
					morph_pickup(ctx.pickup, ITEM_B, keep_seed)
				end,
			},
			{ wait = 4 },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
		end,
	}
end

local function case_morph_to_zero()
	return {
		id = "S3",
		name = "Direct Morph -> SubType 0 (keepSeed F then T)",
		kind = "semantic",
		setup = function(ctx)
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
			ctx.start_seed = ctx.pickup and ctx.pickup.InitSeed
			ctx.start_ptr = ptr_of(ctx.pickup)
			ctx.phase = 1
		end,
		steps = {
			{ wait = 2 },
			{
				run = function(ctx)
					ctx.counts_phase_f = {
						pre = ctx.counts.pre_morph,
						post = ctx.counts.post_morph,
					}
					morph_pickup(ctx.pickup, 0, false)
				end,
			},
			{ wait = 4 },
			{
				run = function(ctx)
					observe(ctx, "phase_f_pre_delta", (ctx.counts.pre_morph or 0) - (ctx.counts_phase_f.pre or 0))
					observe(ctx, "phase_f_post_delta", (ctx.counts.post_morph or 0) - (ctx.counts_phase_f.post or 0))
					observe(ctx, "phase_f_subtype", ctx.pickup and ctx.pickup:Exists() and ctx.pickup.SubType or "gone")
					observe(ctx, "phase_f_seed", ctx.pickup and ctx.pickup:Exists() and ctx.pickup.InitSeed or nil)
					-- 重建再测 keepSeed=true
					if not (ctx.pickup and ctx.pickup:Exists()) then
						ctx.pickup = spawn_collectible(ctx, ITEM_A)
					else
						morph_pickup(ctx.pickup, ITEM_A, true)
					end
				end,
			},
			{ wait = 3 },
			{
				run = function(ctx)
					ctx.counts_phase_t = {
						pre = ctx.counts.pre_morph,
						post = ctx.counts.post_morph,
					}
					morph_pickup(ctx.pickup, 0, true)
				end,
			},
			{ wait = 4 },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			observe(ctx, "phase_t_pre_delta", (ctx.counts.pre_morph or 0) - (ctx.counts_phase_t and ctx.counts_phase_t.pre or 0))
			observe(ctx, "phase_t_post_delta", (ctx.counts.post_morph or 0) - (ctx.counts_phase_t and ctx.counts_phase_t.post or 0))
			observe(ctx, "phase_t_subtype", ctx.pickup and ctx.pickup:Exists() and ctx.pickup.SubType or "gone")
		end,
	}
end

local function case_cycle()
	return {
		id = "S5",
		name = "CollectibleCycle A/B/C observe",
		kind = "semantic",
		setup = function(ctx)
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
			ctx.start_seed = ctx.pickup and ctx.pickup.InitSeed
			ctx.start_ptr = ptr_of(ctx.pickup)
			if ctx.pickup and ctx.pickup.AddCollectibleCycle then
				ctx.pickup:AddCollectibleCycle(ITEM_B)
				ctx.pickup:AddCollectibleCycle(ITEM_C)
			else
				ctx.status = "SKIPPED"
				observe(ctx, "skip_reason", "AddCollectibleCycle unavailable")
			end
		end,
		steps = {
			{ wait = 2 },
			-- ~6 秒观察自然轮换（30Hz）
			{ wait = 180 },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
		end,
	}
end

local function case_d6()
	return {
		id = "S6",
		name = "Actual D6",
		kind = "semantic",
		setup = function(ctx)
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
			ctx.start_seed = ctx.pickup and ctx.pickup.InitSeed
			ctx.start_ptr = ptr_of(ctx.pickup)
		end,
		steps = {
			{ wait = 2 },
			{
				run = function(ctx)
					use_active(CollectibleType.COLLECTIBLE_D6)
				end,
			},
			{ wait = 10 },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
		end,
	}
end

local function case_eternal_d6()
	return {
		id = "S7",
		name = "Actual Eternal D6 until empty/remove",
		kind = "semantic",
		setup = function(ctx)
			ctx.attempt = 0
			ctx.max_attempts = 30
			ctx.reroll = 0
			ctx.empty = 0
			ctx.removed = 0
			ctx.found_empty = false
		end,
		steps = {
			{
				run = function(ctx)
					ctx.attempt = (ctx.attempt or 0) + 1
					-- 清旧底座
					if ctx.pickup and ctx.pickup.Exists and ctx.pickup:Exists() then
						pcall(function() ctx.pickup:Remove() end)
					end
					ctx.pickup = spawn_collectible(ctx, ITEM_A)
					ctx.start_seed = ctx.pickup and ctx.pickup.InitSeed
					ctx.pre_before = ctx.counts.pre_morph
					ctx.post_before = ctx.counts.post_morph
				end,
			},
			{ wait = 2 },
			{
				run = function(ctx)
					use_active(CollectibleType.COLLECTIBLE_ETERNAL_D6)
				end,
			},
			{ wait = 8 },
			{
				run = function(ctx)
					local exists = ctx.pickup and ctx.pickup.Exists and ctx.pickup:Exists()
					local st = exists and (ctx.pickup.SubType or 0) or nil
					local pre_d = (ctx.counts.pre_morph or 0) - (ctx.pre_before or 0)
					local post_d = (ctx.counts.post_morph or 0) - (ctx.post_before or 0)
					if not exists then
						ctx.removed = ctx.removed + 1
						ctx.found_empty = true
						observe(ctx, "empty_sample_morph_pre", pre_d)
						observe(ctx, "empty_sample_morph_post", post_d)
						observe(ctx, "empty_sample_gone", true)
					elseif st == 0 then
						ctx.empty = ctx.empty + 1
						ctx.found_empty = true
						observe(ctx, "empty_sample_morph_pre", pre_d)
						observe(ctx, "empty_sample_morph_post", post_d)
						observe(ctx, "empty_sample_subtype0", true)
					else
						ctx.reroll = ctx.reroll + 1
						observe(ctx, "last_reroll_morph_pre", pre_d)
						observe(ctx, "last_reroll_morph_post", post_d)
					end
					observe(ctx, "attempts", ctx.attempt)
					observe(ctx, "reroll_outcomes", ctx.reroll)
					observe(ctx, "empty_outcomes", ctx.empty)
					observe(ctx, "remove_outcomes", ctx.removed)
					if ctx.found_empty or ctx.attempt >= ctx.max_attempts then
						ctx._stop_repeat = true
					else
						-- 通过 wait_until 重复：把 step_index 回退到开头由 runner 处理
						ctx._repeat_attempt = true
					end
				end,
			},
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			observe(ctx, "found_empty_or_remove", ctx.found_empty == true)
		end,
	}
end

local function case_normal_pickup()
	return {
		id = "S8",
		name = "Normal pickup",
		kind = "semantic",
		setup = function(ctx)
			local player = player0()
			local room = Game():GetRoom()
			local pos = (player and player.Position or room:GetCenterPos()) + Vector(0, 24)
			ctx.pickup = spawn_collectible(ctx, ITEM_A, pos)
			ctx.start_seed = ctx.pickup and ctx.pickup.InitSeed
			ctx.start_ptr = ptr_of(ctx.pickup)
			ctx.target_item = ITEM_A
		end,
		steps = {
			{ wait = 2 },
			{
				run = function(ctx)
					local player = player0()
					if player and ctx.pickup and ctx.pickup:Exists() then
						player.Position = ctx.pickup.Position
					end
				end,
			},
			{
				wait_until = function(ctx)
					return (ctx.counts.pickup_success or 0) > 0 or (ctx.counts.entity_gone or 0) > 0
				end,
				timeout = 120,
			},
			{ wait = 5 },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			local player = player0()
			observe(ctx, "player_gained", player and (player:GetCollectibleNum(ITEM_A) > (ctx.before.collectible_counts[ITEM_A] or 0)))
		end,
	}
end

local function case_direct_remove()
	return {
		id = "S9",
		name = "Direct Remove",
		kind = "semantic",
		setup = function(ctx)
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
			ctx.start_seed = ctx.pickup and ctx.pickup.InitSeed
			ctx.start_ptr = ptr_of(ctx.pickup)
		end,
		steps = {
			{ wait = 2 },
			{
				run = function(ctx)
					if ctx.pickup then ctx.pickup:Remove() end
				end,
			},
			{ wait = 4 },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
		end,
	}
end

local function case_options_sibling()
	return {
		id = "S10",
		name = "Options sibling remove",
		kind = "semantic",
		setup = function(ctx)
			local room = Game():GetRoom()
			local c = room:GetCenterPos()
			ctx.pickup_a = spawn_collectible(ctx, ITEM_A, c + Vector(-40, 0))
			ctx.pickup_b = spawn_collectible(ctx, ITEM_B, c + Vector(40, 0))
			local idx = 77
			pcall(function()
				ctx.pickup_a.OptionsPickupIndex = idx
				ctx.pickup_b.OptionsPickupIndex = idx
			end)
			ctx.pickup = ctx.pickup_a
			ctx.start_seed = ctx.pickup_b and ctx.pickup_b.InitSeed
			ctx.start_ptr = ptr_of(ctx.pickup_b)
			observe(ctx, "options_index", idx)
		end,
		steps = {
			{ wait = 2 },
			{
				run = function(ctx)
					local player = player0()
					if player and ctx.pickup_a and ctx.pickup_a:Exists() then
						player.Position = ctx.pickup_a.Position
					end
				end,
			},
			{
				wait_until = function(ctx)
					return (ctx.counts.pickup_success or 0) > 0
						or (ctx.pickup_a and ctx.pickup_a.Exists and not ctx.pickup_a:Exists())
				end,
				timeout = 120,
			},
			{ wait = 8 },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			local b = ctx.pickup_b
			local exists = b and b.Exists and b:Exists()
			observe(ctx, "sibling_exists", exists == true)
			observe(ctx, "sibling_subtype", exists and b.SubType or nil)
			observe(ctx, "sibling_gone", exists ~= true)
		end,
	}
end

local function case_family_regression()
	return {
		id = "R1",
		name = "Family subtype switch + D6 cleanup",
		kind = "regression",
		setup = function(ctx)
			-- regression 需要真实 Consistance Morph cleanup
			consistance.debug.semantic_probe_bypass = false
			runner.semantic_probe_active = false
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
			if ctx.pickup and ctx.pickup.AddCollectibleCycle then
				ctx.pickup:AddCollectibleCycle(ITEM_B)
				ctx.pickup:AddCollectibleCycle(ITEM_C)
			end
			ctx.owner = FAMILY_PROBE
			ctx.nonces = {}
			ctx.visits = {}
			ctx.old_family = family_identity(ctx.pickup)
			ctx.before_records = select(1, consistance.count_owner_records(FAMILY_PROBE))
			-- 建立当前 subtype probe
			local st = ctx.pickup.SubType
			local nonce = tostring(ctx.run_id) .. ":" .. tostring(st) .. ":" .. tostring(game_frame())
			ctx.nonces[st] = nonce
			ctx.visits[st] = 1
			ctx._last_probe_st = st
			hold_probe(ctx, ctx.pickup, { expected_subtype = st, nonce = nonce })
			observe(ctx, "start_family", string.format("%s:%s:%s", tostring(ctx.old_family.init_seed), tostring(ctx.old_family.type), tostring(ctx.old_family.variant)))
		end,
		steps = {
			{ wait = 2 },
			-- 观察轮换，主动 rematch probe
			{
				wait = 1,
				run = function(ctx)
					ctx.cycle_frames = 0
					ctx.need_second_visits = true
				end,
			},
			{
				wait_until = function(ctx)
					ctx.cycle_frames = (ctx.cycle_frames or 0) + 1
					local p = ctx.pickup
					if not (p and p:Exists()) then return true end
					local st = p.SubType or 0
					if st == 0 then return false end
					if ctx._last_probe_st == st then
						local a = ctx.visits[ITEM_A] or 0
						local b = ctx.visits[ITEM_B] or 0
						local c = ctx.visits[ITEM_C] or 0
						if a >= 2 and b >= 2 and c >= 2 then return true end
						return ctx.cycle_frames >= 300
					end
					ctx._last_probe_st = st
					local data = p:GetData()
					data._Data = data._Data or {}
					local hit = consistance.try_check_entity(p, FAMILY_PROBE, false, {})
					if hit then
						local payload = data._Data[FAMILY_PROBE] or {}
						if ctx.nonces[st] then
							if payload.nonce ~= ctx.nonces[st] then
								ctx._nonce_mismatch = true
							end
							ctx.visits[st] = (ctx.visits[st] or 0) + 1
						else
							ctx.nonces[st] = payload.nonce or (tostring(ctx.run_id) .. ":" .. tostring(st))
							ctx.visits[st] = 1
						end
					else
						local nonce = tostring(ctx.run_id) .. ":" .. tostring(st) .. ":" .. tostring(game_frame())
						ctx.nonces[st] = nonce
						ctx.visits[st] = (ctx.visits[st] or 0) + 1
						hold_probe(ctx, p, { expected_subtype = st, nonce = nonce })
					end
					local a = ctx.visits[ITEM_A] or 0
					local b = ctx.visits[ITEM_B] or 0
					local c = ctx.visits[ITEM_C] or 0
					if a >= 2 and b >= 2 and c >= 2 then return true end
					return ctx.cycle_frames >= 300
				end,
				timeout = 360,
			},
			{
				run = function(ctx)
					local n, by = consistance.count_owner_records(FAMILY_PROBE)
					ctx.after_cycle_records = n
					ctx.after_cycle_by = by
					observe(ctx, "probe_records_after_cycle", n)
					observe(ctx, "visits_A", ctx.visits[ITEM_A] or 0)
					observe(ctx, "visits_B", ctx.visits[ITEM_B] or 0)
					observe(ctx, "visits_C", ctx.visits[ITEM_C] or 0)
					ctx.old_family = family_identity(ctx.pickup) or ctx.old_family
					ctx.family_states_before_d6 = family_state_count(ctx.old_family)
				end,
			},
			{
				run = function(ctx)
					use_active(CollectibleType.COLLECTIBLE_D6)
				end,
			},
			{ wait = 10 },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			local n = select(1, consistance.count_owner_records(FAMILY_PROBE))
			expect(ctx, n <= 3, "probe owner records <= 3 after cycle (got " .. tostring(n) .. ")")
			expect(ctx, not ctx._nonce_mismatch, "subtype rematch kept distinct nonces")
			local distinct = 0
			for _ in pairs(ctx.nonces or {}) do distinct = distinct + 1 end
			expect(ctx, distinct <= 3, "at most 3 subtype nonces")
			if (ctx.visits[ITEM_A] or 0) >= 2 and (ctx.visits[ITEM_B] or 0) >= 2 and (ctx.visits[ITEM_C] or 0) >= 2 then
				expect(ctx, true, "each subtype visited >=2")
			else
				expect(ctx, false, "failed to visit A/B/C twice within timeout")
			end
			-- Cycle 期间不应 supersede；D6 后应有 supersede
			local o = ctx.observations
			expect(ctx, (o.policy_state_switch_delta or 0) >= 1, "cycle produced STATE_SWITCH")
			local left = family_state_count(ctx.old_family)
			expect(ctx, left == 0, "old family states empty after D6 (left=" .. tostring(left) .. ")")
			expect(ctx, (o.family_supersede_delta or 0) >= 1, "D6 family_supersede +>=1")
			local report = consistance.run_integrity_audit()
			expect(ctx, report and report.ok == true, "integrity audit OK")
		end,
	}
end

local function case_r4_keepseed_generic()
	return {
		id = "R4",
		name = "keepSeed=true Generic Morph keeps family",
		kind = "regression",
		setup = function(ctx)
			consistance.debug.semantic_probe_bypass = false
			runner.semantic_probe_active = false
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
			ctx.owner = FAMILY_PROBE
			ctx.old_family = family_identity(ctx.pickup)
			hold_probe(ctx, ctx.pickup, { expected_subtype = ITEM_A, nonce = "A" })
			ctx.start_seed = ctx.pickup.InitSeed
		end,
		steps = {
			{ wait = 2 },
			{
				run = function(ctx)
					morph_pickup(ctx.pickup, ITEM_B, true)
				end,
			},
			{ wait = 4 },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			expect(ctx, (ctx.observations.family_supersede_delta or 0) == 0, "keepSeed=true must not supersede")
			expect(ctx, family_state_count(ctx.old_family) >= 1, "old family still has states")
			expect(ctx, ctx.observations.seed_changed == false, "seed unchanged")
			expect(ctx, (ctx.observations.policy_state_switch_delta or 0) >= 1
				or (ctx.observations.policy_same_delta or 0) >= 1
				or (ctx.observations.policy_supersede_delta or 0) == 0,
				"policy not SUPERSEDE")
		end,
	}
end

local function case_r5_keepseed_explicit_supersede()
	return {
		id = "R5",
		name = "keepSeed=true + explicit supersede_family",
		kind = "regression",
		setup = function(ctx)
			consistance.debug.semantic_probe_bypass = false
			consistance.debug.family_probe_enabled = false
			runner.semantic_probe_active = false
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
			ctx.owner = FAMILY_PROBE
			ctx.old_family = family_identity(ctx.pickup)
			hold_probe(ctx, ctx.pickup, { expected_subtype = ITEM_A, nonce = "A" })
		end,
		steps = {
			{ wait = 2 },
			{
				run = function(ctx)
					local snap = consistance.supersede_family(ctx.old_family)
					observe(ctx, "explicit_supersede_entries", #((snap and snap.entries) or {}))
					consistance.invalidate_entity_binding(ctx.pickup)
					observe(ctx, "family_after_explicit", family_state_count(ctx.old_family))
					observe(ctx, "probe_after_explicit", select(1, consistance.count_owner_records(FAMILY_PROBE)))
				end,
			},
			{ wait = 1 },
			{
				run = function(ctx)
					-- Generic probe owner 必须已空；其它业务 owner（如 Unique_holder）允许存在噪声
					if (select(1, consistance.count_owner_records(FAMILY_PROBE)) or 0) ~= 0 then
						ctx._explicit_clear_failed = true
						return
					end
					morph_pickup(ctx.pickup, ITEM_B, true)
				end,
			},
			{ wait = 4 },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			local probe_n = select(1, consistance.count_owner_records(FAMILY_PROBE)) or 0
			observe(ctx, "probe_after_morph", probe_n)
			observe(ctx, "family_owners_after_morph", family_owners_summary(ctx.old_family))
			expect(ctx, not ctx._explicit_clear_failed, "explicit supersede cleared probe before Morph")
			expect(ctx, (ctx.observations.probe_after_explicit or 0) == 0, "FAMILY_PROBE empty right after explicit supersede")
			-- Generic 不得自动重建 FAMILY_PROBE；Morph INIT 上 Unique_holder 等可另建 subtype-sensitive record
			expect(ctx, probe_n == 0, "FAMILY_PROBE still empty after keepSeed Morph (no Generic auto-hold)")
			-- Morph 分类不得 SUPERSEDE（family_supersede_delta 含本 case 显式 supersede，通常 =1）
			expect(ctx, (ctx.observations.policy_supersede_delta or 0) == 0, "keepSeed Morph must not classify SUPERSEDE")
			expect(ctx, (ctx.observations.policy_state_switch_delta or 0) >= 1
				or (ctx.observations.policy_same_delta or 0) >= 1,
				"keepSeed Morph is STATE_SWITCH/SAME")
		end,
	}
end

local function case_r6_morph_to_zero()
	return {
		id = "R6",
		name = "Empty pedestal keeps family (no Morph->0)",
		kind = "regression",
		setup = function(ctx)
			consistance.debug.semantic_probe_bypass = false
			consistance.debug.family_probe_enabled = false
			runner.semantic_probe_active = false
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
			ctx.owner = FAMILY_PROBE
			ctx.old_family = family_identity(ctx.pickup)
			ctx.start_seed = ctx.pickup and ctx.pickup.InitSeed
			hold_probe(ctx, ctx.pickup, { expected_subtype = ITEM_A, nonce = "A" })
		end,
		steps = {
			{ wait = 2 },
			{
				run = function(ctx)
					-- Morph(0) 会 reroll；用 TryRemoveCollectible（Judgment 路径）
					ctx._emptied = empty_collectible_pedestal(ctx.pickup)
					observe(ctx, "empty_via_try_remove", ctx._emptied == true)
					if not ctx._emptied then
						-- 回退：玩家拾取留空（引擎 Normal pickup 路径，无 Morph）
						ctx._empty_via_pickup = pickup_leave_empty(ctx)
					end
				end,
			},
			{
				wait_until = function(ctx)
					local p = ctx.pickup
					if not (p and p:Exists()) then return false end
					if (p.SubType or 0) == 0 then return true end
					if ctx._empty_via_pickup and (ctx.counts.pickup_success or 0) > 0 then
						return (p.SubType or 0) == 0
					end
					return false
				end,
				timeout = 120,
			},
			{ wait = 2 },
			{
				run = function(ctx)
					local st = ctx.pickup and ctx.pickup:Exists() and (ctx.pickup.SubType or -1) or -1
					observe(ctx, "subtype_after_empty", st)
					if st ~= 0 then ctx._empty_failed = true end
					observe(ctx, "family_while_empty", family_state_count(ctx.old_family))
					observe(ctx, "probe_while_empty", select(1, consistance.count_owner_records(FAMILY_PROBE)))
				end,
			},
			{ wait = 2 },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			expect(ctx, not ctx._empty_failed,
				"empty pedestal SubType=0 (got " .. tostring(ctx.observations.subtype_after_empty) .. ")")
			-- 空底座不得走 SUPERSEDE（历史 A 保留，供 rematch / 离房 GC）
			expect(ctx, (ctx.observations.family_supersede_delta or 0) == 0, "empty must not supersede family")
			expect(ctx, family_state_count(ctx.old_family) >= 1
				or (select(1, consistance.count_owner_records(FAMILY_PROBE)) or 0) >= 1,
				"family/probe remains while empty")
			-- Morph(0) 不可达：EMPTY_PENDING 可能为 0（TryRemove/拾取常无 Morph）
			observe(ctx, "note_empty_pending_optional", (ctx.observations.policy_empty_delta or 0))
		end,
	}
end

local function case_r7_empty_gc()
	return {
		id = "R7",
		name = "Empty pedestal debug room-exit GC",
		kind = "regression",
		setup = function(ctx)
			consistance.debug.semantic_probe_bypass = false
			consistance.debug.family_probe_enabled = false
			runner.semantic_probe_active = false
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
			ctx.owner = FAMILY_PROBE
			ctx.old_family = family_identity(ctx.pickup)
			hold_probe(ctx, ctx.pickup, { expected_subtype = ITEM_A, nonce = "A" })
		end,
		steps = {
			{ wait = 2 },
			{
				run = function(ctx)
					ctx._emptied = empty_collectible_pedestal(ctx.pickup)
					observe(ctx, "empty_via_try_remove", ctx._emptied == true)
					if not ctx._emptied then
						ctx._empty_via_pickup = pickup_leave_empty(ctx)
					end
				end,
			},
			{
				wait_until = function(ctx)
					local p = ctx.pickup
					if not (p and p:Exists()) then return false end
					return (p.SubType or 0) == 0
				end,
				timeout = 120,
			},
			{ wait = 2 },
			{
				run = function(ctx)
					local st = ctx.pickup and ctx.pickup:Exists() and (ctx.pickup.SubType or -1) or -1
					observe(ctx, "subtype_after_empty", st)
					if st ~= 0 then ctx._empty_failed = true end
					observe(ctx, "family_before_gc", family_state_count(ctx.old_family))
				end,
			},
			{ wait = 1 },
			{
				run = function(ctx)
					if ctx._empty_failed then return end
					consistance.debug_cleanup_empty_collectibles()
				end,
			},
			{ wait = 2 },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			expect(ctx, not ctx._empty_failed,
				"empty pedestal SubType=0 (got " .. tostring(ctx.observations.subtype_after_empty) .. ")")
			local snap = consistance.get_debug_snapshot()
			local gc_delta = (snap.empty_collectible_families_cleaned or 0) - (ctx.before_empty_gc or 0)
			expect(ctx, family_state_count(ctx.old_family) == 0, "family empty after GC")
			expect(ctx, gc_delta >= 1, "empty_gc +1")
		end,
	}
end

--- Engine semantics 锁定（RGON 行为变化 → ENGINE SEMANTICS CHANGED）
local function case_engine_lock(name, id, setup_fn, steps, checks)
	return {
		id = id,
		name = name,
		kind = "engine",
		setup = setup_fn,
		steps = steps,
		verify = function(ctx)
			summarize_case_observations(ctx)
			local o = ctx.observations
			for _, chk in ipairs(checks) do
				local ok = chk.fn(o, ctx)
				expect(ctx, ok, chk.msg)
				if not ok then
					ctx.engine_semantics_changed = true
				end
			end
			if ctx.engine_semantics_changed then
				ctx.status = "ENGINE_SEMANTICS_CHANGED"
			end
		end,
	}
end

local function engine_cases()
	return {
		case_engine_lock("Engine: Morph keepSeed=F", "E1", function(ctx)
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
			ctx.start_seed = ctx.pickup.InitSeed
			ctx.start_ptr = ptr_of(ctx.pickup)
		end, {
			{ wait = 2 },
			{ run = function(ctx) morph_pickup(ctx.pickup, ITEM_B, false) end },
			{ wait = 4 },
		}, {
			{ fn = function(o) return (o.pre_morph or 0) >= 1 and (o.post_morph or 0) >= 1 end, msg = "Morph yes" },
			{ fn = function(o) return o.seed_changed == true end, msg = "seed changed yes" },
		}),
		case_engine_lock("Engine: Morph keepSeed=T", "E2", function(ctx)
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
			ctx.start_seed = ctx.pickup.InitSeed
		end, {
			{ wait = 2 },
			{ run = function(ctx) morph_pickup(ctx.pickup, ITEM_B, true) end },
			{ wait = 4 },
		}, {
			{ fn = function(o) return (o.pre_morph or 0) >= 1 and (o.post_morph or 0) >= 1 end, msg = "Morph yes" },
			{ fn = function(o) return o.seed_changed == false end, msg = "seed changed no" },
		}),
		case_engine_lock("Engine: Cycle Morph+same seed", "E3", function(ctx)
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
			ctx.start_seed = ctx.pickup.InitSeed
			if ctx.pickup.AddCollectibleCycle then
				ctx.pickup:AddCollectibleCycle(ITEM_B)
				ctx.pickup:AddCollectibleCycle(ITEM_C)
			else
				ctx.status = "SKIPPED"
			end
		end, {
			{ wait = 2 },
			{ wait = 120 },
		}, {
			{ fn = function(o) return (o.post_morph or 0) >= 1 end, msg = "Cycle Morph yes" },
			{ fn = function(o) return o.seed_changed == false end, msg = "Cycle seed unchanged" },
			{ fn = function(o) return (o.subtype_change or 0) >= 1 end, msg = "Cycle subtype changes" },
		}),
		case_engine_lock("Engine: D6 Morph+seed change", "E4", function(ctx)
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
			ctx.start_seed = ctx.pickup.InitSeed
		end, {
			{ wait = 2 },
			{ run = function(ctx) use_active(CollectibleType.COLLECTIBLE_D6) end },
			{ wait = 10 },
		}, {
			{ fn = function(o) return (o.post_morph or 0) >= 1 end, msg = "D6 Morph yes" },
			{ fn = function(o) return o.seed_changed == true end, msg = "D6 seed changed yes" },
		}),
		case_engine_lock("Engine: Normal pickup no Morph", "E5", function(ctx)
			local player = player0()
			local room = Game():GetRoom()
			local pos = (player and player.Position or room:GetCenterPos()) + Vector(0, 24)
			ctx.pickup = spawn_collectible(ctx, ITEM_A, pos)
			ctx.start_seed = ctx.pickup.InitSeed
		end, {
			{ wait = 2 },
			{ run = function(ctx)
				local player = player0()
				if player and ctx.pickup and ctx.pickup:Exists() then player.Position = ctx.pickup.Position end
			end },
			{ wait_until = function(ctx) return (ctx.counts.pickup_success or 0) > 0 end, timeout = 120 },
			{ wait = 5 },
		}, {
			{ fn = function(o) return (o.pre_morph or 0) == 0 and (o.post_morph or 0) == 0 end, msg = "pickup Morph no" },
			{ fn = function(o) return (o.pickup_success or 0) >= 1 end, msg = "pickup yes" },
		}),
		case_engine_lock("Engine: Direct Remove no Morph", "E6", function(ctx)
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
		end, {
			{ wait = 2 },
			{ run = function(ctx) if ctx.pickup then ctx.pickup:Remove() end end },
			{ wait = 4 },
		}, {
			{ fn = function(o) return (o.post_morph or 0) == 0 end, msg = "Remove Morph no" },
			{ fn = function(o) return o.entity_gone == true end, msg = "gone yes" },
		}),
	}
end

local function build_essm_cases()
	return essm_suite.build_cases({
		ITEM_A = ITEM_A,
		ITEM_B = ITEM_B,
		ITEM_C = ITEM_C,
		spawn_collectible = spawn_collectible,
		morph_pickup = morph_pickup,
		empty_collectible_pedestal = empty_collectible_pedestal,
		use_active = use_active,
		observe = observe,
		expect = expect,
		summarize_case_observations = summarize_case_observations,
		player0 = player0,
		ptr_of = ptr_of,
		game_frame = game_frame,
	})
end

local function build_unique_cases()
	return unique_suite.build_cases({
		ITEM_A = ITEM_A,
		ITEM_B = ITEM_B,
		ITEM_C = ITEM_C,
		spawn_collectible = spawn_collectible,
		morph_pickup = morph_pickup,
		empty_collectible_pedestal = empty_collectible_pedestal,
		use_active = use_active,
		observe = observe,
		expect = expect,
		summarize_case_observations = summarize_case_observations,
		player0 = player0,
		ptr_of = ptr_of,
		game_frame = game_frame,
	})
end

local function family_regression_cases()
	return {
		case_family_regression(),
		case_r4_keepseed_generic(),
		case_r5_keepseed_explicit_supersede(),
		case_r6_morph_to_zero(),
		case_r7_empty_gc(),
	}
end

local SUITES = {
	semantics = {
		name = "Morph Semantics Matrix",
		semantic = true,
		cases = {
			case_direct_morph("Direct Morph keepSeed=false", "S1", false),
			case_direct_morph("Direct Morph keepSeed=true", "S2", true),
			case_morph_to_zero(),
			case_cycle(),
			case_d6(),
			case_eternal_d6(),
			case_normal_pickup(),
			case_direct_remove(),
			case_options_sibling(),
		},
	},
	engine = {
		name = "Morph Semantics Regression",
		semantic = true,
		cases = engine_cases(),
	},
	family = {
		name = "Family Regression",
		semantic = false,
		cases = family_regression_cases(),
	},
	morph_regression = {
		name = "Morph / Family Regression",
		semantic = false,
		cases = family_regression_cases(),
	},
	essm = {
		name = "ESSM Lifetime Matrix",
		semantic = false,
		bypass = false,
		cases = build_essm_cases(),
	},
	unique_shadow = {
		name = "Unique Shadow Compare",
		semantic = false,
		cases = build_unique_cases(),
	},
	safe_all = {
		name = "All Safe Tests",
		semantic = true,
		cases = (function()
			local list = {
				case_direct_morph("Direct Morph keepSeed=false", "S1", false),
				case_direct_morph("Direct Morph keepSeed=true", "S2", true),
				case_morph_to_zero(),
				case_cycle(),
				case_d6(),
				case_eternal_d6(),
				case_normal_pickup(),
				case_direct_remove(),
				case_options_sibling(),
			}
			for _, c in ipairs(family_regression_cases()) do list[#list + 1] = c end
			for _, c in ipairs(build_essm_cases()) do
				if c.id ~= "E12" and c.id ~= "E13" then
					list[#list + 1] = c
				end
			end
			for _, c in ipairs(build_unique_cases()) do
				if c.id ~= "U3" then
					list[#list + 1] = c
				end
			end
			return list
		end)(),
	},
}

---------------------------------------------------------------------------
-- Runner
---------------------------------------------------------------------------

local function set_bypass(on)
	runner.semantic_probe_active = on == true
	consistance.debug.semantic_probe_bypass = on == true
end

local function start_suite(suite_key)
	if runner.running then return false, "already running" end
	local suite = SUITES[suite_key]
	if not suite then return false, "unknown suite" end
	-- Lab 运行期间关闭手动 Family Probe，避免 tick 干扰 regression
	consistance.debug.family_probe_enabled = false
	-- 不清空 runner.results：跨 suite 追加；需要时用 Clear Report History
	runner.trace = {}
	runner.suite = suite
	runner.suite_name = suite.name
	runner.suite_session = (runner.suite_session or 0) + 1
	runner.suite_start_index = #runner.results + 1
	runner.results[#runner.results + 1] = {
		name = string.format("=== %s ===", suite.name),
		kind = "session",
		status = "SESSION",
		suite = suite.name,
		session = runner.suite_session,
		frame = game_frame(),
	}
	runner.case_index = 1
	runner.step_index = 0
	runner.wait = 0
	runner.wait_until = nil
	runner.wait_timeout = 0
	runner.last_error = nil
	runner.running = true
	runner.status = string.format("Running %s (history=%d)", suite.name, #runner.results)
	if suite_key == "family" or suite_key == "morph_regression" or suite_key == "essm" or suite_key == "unique_shadow" then
		set_bypass(false)
	else
		set_bypass(suite.semantic == true)
	end
	return true
end

function lab.is_semantic_probe_active()
	return runner.semantic_probe_active == true
end

function lab.start_semantics()
	return start_suite("semantics")
end

function lab.start_engine_regression()
	return start_suite("engine")
end

function lab.start_family_regression()
	return start_suite("family")
end

function lab.start_morph_regression()
	return start_suite("morph_regression")
end

function lab.start_essm_matrix()
	return start_suite("essm")
end

function lab.start_unique_shadow()
	unique_holder.set_shadow_enabled(true)
	unique_holder.reset_shadow_stats()
	return start_suite("unique_shadow")
end

function lab.start_native_guard()
	runner.status = "Phase E Native Guard — not implemented yet"
	return false, "phase_e"
end

function lab.start_integration()
	runner.status = "Phase F Integration — not implemented yet"
	return false, "phase_f"
end

function lab.start_cross_room()
	runner.status = "Phase G Cross-room — not implemented yet"
	return false, "phase_g"
end

function lab.start_cross_floor()
	runner.status = "Phase G Cross-floor — not implemented yet"
	return false, "phase_g"
end

function lab.prepare_save_continue()
	local nearest
	local player = player0()
	local best_d = 1e9
	local ok, list = pcall(function()
		return Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, -1, false, false)
	end)
	if ok and type(list) == "table" then
		for _, ent in ipairs(list) do
			local p = ent:ToPickup() or ent
			if p and (p.SubType or 0) ~= 0 then
				local d = player and player.Position:Distance(p.Position) or 0
				if d < best_d then
					best_d = d
					nearest = p
				end
			end
		end
	end
	if not nearest then
		runner.status = "Prepare Save/Continue: no nearby collectible"
		return false, "no_pickup"
	end
	local ok2, payload = essm_suite.prepare_save_continue(nearest)
	if ok2 then
		runner.status = string.format("Save/Continue prepared token=%s seed=%s — exit & Continue",
			tostring(payload.token), tostring(payload.init_seed))
		return true, payload
	end
	runner.status = "Prepare Save/Continue failed: " .. tostring(payload)
	return false, payload
end

function lab.check_save_continue()
	local result = essm_suite.check_save_continue()
	runner.last_save_continue = result
	runner.status = string.format("Save/Continue check: %s token %s->%s",
		tostring(result.status), tostring(result.expected_token), tostring(result.actual_token))
	return result
end

function lab.start_all_safe()
	return start_suite("safe_all")
end

	function lab.emergency_cleanup()
	if runner.context then cleanup_context(runner.context) end
	runner.running = false
	runner.context = nil
	runner.suite = nil
	runner.wait_until = nil
	set_bypass(false)
	unique_holder.set_shadow_enabled(false)
	consistance.purge_owners_by_prefix(OWNER_PREFIX)
	consistance.purge_owners_by_prefix(FAMILY_PROBE)
	local ok, list = pcall(function() return Isaac.GetRoomEntities() end)
	if ok and type(list) == "table" then
		for _, ent in ipairs(list) do
			if is_lab_entity(ent) then
				pcall(function() ent:Remove() end)
			end
		end
	end
	runner.status = "Emergency cleaned"
	return true
end

function lab.get_status_text()
	local lines = {}
	lines[#lines + 1] = "Status: " .. tostring(runner.status)
	lines[#lines + 1] = string.format("History: %d entries (Clear Report 才会清空)", #runner.results)
	if runner.last_error then
		lines[#lines + 1] = "Error: " .. tostring(runner.last_error)
	end
	local by_suite = {}
	local pass, fail, observed, timeout, skipped, engine_chg, warn = 0, 0, 0, 0, 0, 0, 0
	for _, r in ipairs(runner.results) do
		if r.kind == "session" then
			-- skip
		else
			local sn = tostring(r.suite or "?")
			by_suite[sn] = by_suite[sn] or { pass = 0, fail = 0, obs = 0, skip = 0, timeout = 0, warn = 0 }
			local b = by_suite[sn]
			if r.status == "PASS" then pass = pass + 1 b.pass = b.pass + 1
			elseif r.status == "FAIL" then fail = fail + 1 b.fail = b.fail + 1
			elseif r.status == "TIMEOUT" then timeout = timeout + 1 b.timeout = b.timeout + 1
			elseif r.status == "SKIPPED" then skipped = skipped + 1 b.skip = b.skip + 1
			elseif r.status == "ENGINE_SEMANTICS_CHANGED" then engine_chg = engine_chg + 1
			elseif r.status == "WARN" then warn = warn + 1 b.warn = b.warn + 1
			else observed = observed + 1 b.obs = b.obs + 1 end
		end
	end
	lines[#lines + 1] = string.format("Results: PASS=%d FAIL=%d OBSERVED=%d WARN=%d ENGINEΔ=%d TIMEOUT=%d SKIPPED=%d",
		pass, fail, observed, warn, engine_chg, timeout, skipped)
	local order = {
		"Morph / Family Regression", "Family Regression", "Morph Semantics Matrix", "Morph Semantics Regression",
		"ESSM Lifetime Matrix", "Unique Shadow Compare", "All Safe Tests",
	}
	local seen = {}
	for _, name in ipairs(order) do
		local b = by_suite[name]
		if b then
			seen[name] = true
			lines[#lines + 1] = string.format("%-28s PASS %d / FAIL %d / OBS %d / WARN %d / SKIP %d",
				name, b.pass, b.fail, b.obs, b.warn, b.skip)
		end
	end
	for name, b in pairs(by_suite) do
		if not seen[name] then
			lines[#lines + 1] = string.format("%-28s PASS %d / FAIL %d / OBS %d / WARN %d / SKIP %d",
				name, b.pass, b.fail, b.obs, b.warn, b.skip)
		end
	end
	if not by_suite["Unique Shadow Compare"] then
		lines[#lines + 1] = "Unique Shadow               Not Run"
	end
	lines[#lines + 1] = "Native Guard                Not Run (Phase E)"
	lines[#lines + 1] = "Integration                 Not Run (Phase F)"
	lines[#lines + 1] = "Cross-room / Cross-floor    Not Run (Phase G)"
	local us = unique_holder.get_shadow_snapshot()
	lines[#lines + 1] = string.format("UniqueShadow: match_new=%d match_old=%d leg_new/essm_old=%d leg_old/essm_new=%d noise=%d err=%d",
		us.match_new or 0, us.match_old or 0, us.legacy_new_essm_old or 0, us.legacy_old_essm_new or 0,
		us.known_legacy_noise or 0, us.essm_error or 0)
	local lt = lifetime.get_debug_snapshot()
	lines[#lines + 1] = string.format("ESSM: available=%s errors=%d creates=%d hits=%d next=%s",
		tostring(lt.available), tostring(lt.api_errors), tostring(lt.creates), tostring(lt.hits), tostring(lt.next_token))
	local snap = consistance.get_debug_snapshot()
	local pol = snap.morph_policy or {}
	lines[#lines + 1] = string.format("Morph Policy: SUPERSEDE=%d STATE_SWITCH=%d EMPTY=%d SAME=%d UNK=%d",
		pol.supersede or 0, pol.state_switch or 0, pol.empty_pending or 0, pol.same_lifetime or 0, pol.unknown or 0)
	lines[#lines + 1] = "bypass=" .. tostring(consistance.debug.semantic_probe_bypass == true)
	if runner.context then
		lines[#lines + 1] = "Current: " .. tostring(runner.context.name)
		local c = runner.context.counts or {}
		lines[#lines + 1] = string.format("counts PRE=%d POST=%d SUB=%d SEED=%d GONE=%d PICK=%d",
			c.pre_morph or 0, c.post_morph or 0, c.subtype_change or 0, c.seed_change or 0, c.entity_gone or 0, c.pickup_success or 0)
	end
	lines[#lines + 1] = "---"
	for _, r in ipairs(runner.results) do
		if r.kind == "session" then
			lines[#lines + 1] = string.format("%s  (session=%s frame=%s)", tostring(r.name), tostring(r.session), tostring(r.frame))
		else
			local mark = r.status == "PASS" and "P" or (r.status == "FAIL" and "F" or (r.status == "OBSERVED" and "O" or (r.status == "WARN" and "W" or "?")))
			local o = r.observations or {}
			local suite_tag = r.suite and ("{" .. tostring(r.suite) .. "} ") or ""
			if r.kind == "essm" then
				lines[#lines + 1] = string.format("%s %s%s [%s] token %s->%s seedΔ=%s",
					mark, suite_tag, tostring(r.name), tostring(r.status),
					tostring(o.before_token or o.spawn_token or o.idle_token0 or o.token0 or o.home_token or "?"),
					tostring(o.after_token or o.empty_token or o.return_token or o.restored_token or "-"),
					tostring(o.seed_changed or o.seed_same))
			elseif r.kind == "unique_shadow" then
				lines[#lines + 1] = string.format("%s %s%s [%s] class=%s leg=%s essm_new=%s",
					mark, suite_tag, tostring(r.name), tostring(r.status),
					tostring(o.class or o.return_class or o.idle_class or "-"),
					tostring(o.legacy_new or o.return_legacy_new),
					tostring(o.essm_new or o.return_essm_new or o.idle_essm_new))
			else
				lines[#lines + 1] = string.format("%s %s%s [%s] PRE=%s POST=%s seedΔ=%s subΔ=%s gone=%s pick=%s",
					mark, suite_tag, tostring(r.name), tostring(r.status),
					tostring(o.pre_morph), tostring(o.post_morph),
					tostring(o.seed_changed), tostring(o.subtype_change),
					tostring(o.entity_gone), tostring(o.pickup_success))
			end
			if r.failures and #r.failures > 0 then
				for i = 1, math.min(3, #r.failures) do
					lines[#lines + 1] = "    ! " .. r.failures[i]
				end
			end
		end
	end
	return table.concat(lines, "\n")
end

local function iter_results(from_index)
	from_index = from_index or 1
	local list = {}
	for i = from_index, #runner.results do
		list[#list + 1] = runner.results[i]
	end
	return list
end

function lab.get_semantics_report_text(from_index)
	local rows = iter_results(from_index)
	local lines = { "=== Pickup Morph Semantics ===", "" }
	lines[#lines + 1] = "Matrix:"
	lines[#lines + 1] = "Case | suite | PRE | POST | seedΔ | subΔ | gone | pick | status"
	for _, r in ipairs(rows) do
		if r.kind == "session" then
			lines[#lines + 1] = tostring(r.name)
		else
			local o = r.observations or {}
			lines[#lines + 1] = string.format("%s | %s | %s | %s | %s | %s | %s | %s | %s",
				tostring(r.name), tostring(r.suite or "-"),
				tostring(o.pre_morph), tostring(o.post_morph),
				tostring(o.seed_changed), tostring(o.subtype_change),
				tostring(o.entity_gone), tostring(o.pickup_success),
				tostring(r.status))
		end
	end
	lines[#lines + 1] = ""
	for _, r in ipairs(rows) do
		if r.kind == "semantic" or r.status == "OBSERVED" or r.status == "SKIPPED" or r.status == "TIMEOUT" then
			local o = r.observations or {}
			lines[#lines + 1] = tostring(r.name)
			lines[#lines + 1] = string.format("PRE=%s POST=%s", tostring(o.pre_morph), tostring(o.post_morph))
			if o.start_seed ~= nil or o.final_seed ~= nil then
				lines[#lines + 1] = string.format("Seed: %s -> %s (changed=%s)", tostring(o.start_seed or "?"), tostring(o.final_seed or "?"), tostring(o.seed_changed))
			end
			if o.ptr_same ~= nil then
				lines[#lines + 1] = "Ptr same: " .. tostring(o.ptr_same)
			end
			lines[#lines + 1] = string.format("Subtype changes=%s Seed changes=%s", tostring(o.subtype_change), tostring(o.seed_change))
			lines[#lines + 1] = string.format("Entity exists=%s subtype0=%s gone=%s pickup=%s",
				tostring(o.entity_exists), tostring(o.subtype_zero), tostring(o.entity_gone), tostring(o.pickup_success))
			if o.attempts then
				lines[#lines + 1] = string.format("Eternal attempts=%s reroll=%s empty=%s remove=%s",
					tostring(o.attempts), tostring(o.reroll_outcomes), tostring(o.empty_outcomes), tostring(o.remove_outcomes))
			end
			if o.sibling_exists ~= nil then
				lines[#lines + 1] = string.format("Sibling exists=%s subtype=%s", tostring(o.sibling_exists), tostring(o.sibling_subtype))
			end
			lines[#lines + 1] = "Status: " .. tostring(r.status)
			lines[#lines + 1] = ""
		end
	end
	return table.concat(lines, "\n")
end

function lab.get_export_text(from_index)
	local rows = iter_results(from_index)
	local parts = {}
	parts[#parts + 1] = string.format("=== Test Summary ===")
	parts[#parts + 1] = string.format("Export @ frame %d (entries %d..%d of %d)",
		game_frame(), from_index or 1, #runner.results, #runner.results)
	parts[#parts + 1] = ""

	local function section_header(title)
		parts[#parts + 1] = ""
		parts[#parts + 1] = "=== " .. title .. " ==="
		parts[#parts + 1] = ""
	end

	section_header("Morph / Family Regression")
	for _, r in ipairs(rows) do
		if r.kind == "regression" or r.kind == "engine"
			or (r.suite and (tostring(r.suite):find("Family") or tostring(r.suite):find("Morph"))) then
			if r.kind ~= "session" and r.kind ~= "essm" and r.kind ~= "semantic" then
				parts[#parts + 1] = string.format("%s [%s]", tostring(r.name), tostring(r.status))
				for _, a in ipairs(r.assertions or {}) do
					parts[#parts + 1] = string.format("  %s %s", a.ok and "OK" or "FAIL", tostring(a.text))
				end
			end
		end
	end

	section_header("ESSM Lifetime Matrix")
	for _, r in ipairs(rows) do
		if r.kind == "essm" or (r.suite and tostring(r.suite):find("ESSM")) then
			local o = r.observations or {}
			parts[#parts + 1] = string.format("%s", tostring(r.name))
			if o.spawn_token or o.idle_token0 or o.token0 then
				parts[#parts + 1] = string.format("  token=%s stable=%s",
					tostring(o.spawn_token or o.idle_token0 or o.token0),
					tostring(o.token_stable_5 or o.idle_stable or "-"))
			end
			if o.before_token or o.after_token then
				parts[#parts + 1] = string.format("  before token=%s seed=%s -> after token=%s seed=%s",
					tostring(o.before_token), tostring(o.before_seed),
					tostring(o.after_token), tostring(o.after_seed))
			end
			if o.subtype_changes then
				parts[#parts + 1] = string.format("  subtype_changes=%s distinct_tokens=%s morph=%s",
					tostring(o.subtype_changes), tostring(o.distinct_tokens), tostring(o.morph_count))
			end
			if o.token_home or o.return_token then
				parts[#parts + 1] = string.format("  room token %s -> %s same=%s",
					tostring(o.token_home), tostring(o.return_token), tostring(o.token_same))
			end
			parts[#parts + 1] = "  status=" .. tostring(r.status)
			if r.failures and #r.failures > 0 then
				for _, f in ipairs(r.failures) do
					parts[#parts + 1] = "  ! " .. tostring(f)
				end
			end
		end
	end

	section_header("Unique Shadow Compare")
	local any_u = false
	for _, r in ipairs(rows) do
		if r.kind == "unique_shadow" or (r.suite and tostring(r.suite):find("Unique Shadow")) then
			any_u = true
			local o = r.observations or {}
			parts[#parts + 1] = string.format("%s [%s]", tostring(r.name), tostring(r.status))
			parts[#parts + 1] = string.format("  class=%s legacy_new=%s essm_new=%s token=%s",
				tostring(o.class or o.return_class or o.idle_class or "-"),
				tostring(o.legacy_new or o.return_legacy_new or "-"),
				tostring(o.essm_new or o.return_essm_new or o.idle_essm_new or "-"),
				tostring(o.token or o.return_token or o.token0 or "-"))
			if o.warn then parts[#parts + 1] = "  WARN: " .. tostring(o.warn) end
			if o.noise_delta then
				parts[#parts + 1] = string.format("  appear2_noise_delta=%s morph_reinit_delta=%s",
					tostring(o.noise_delta), tostring(o.morph_reinit_delta))
			end
			for _, a in ipairs(r.assertions or {}) do
				parts[#parts + 1] = string.format("  %s %s", a.ok and "OK" or "FAIL", tostring(a.text))
			end
		end
	end
	if not any_u then parts[#parts + 1] = "(not run)" end
	local us = unique_holder.get_shadow_snapshot()
	parts[#parts + 1] = string.format("Counters: match_new=%d match_old=%d Lnew/Eold=%d Lold/Enew=%d noise=%d err=%d",
		us.match_new or 0, us.match_old or 0, us.legacy_new_essm_old or 0, us.legacy_old_essm_new or 0,
		us.known_legacy_noise or 0, us.essm_error or 0)

	section_header("Consistance Native Guard")
	parts[#parts + 1] = "(Phase E — not run)"

	section_header("Integration Regression")
	parts[#parts + 1] = "(Phase F — not run)"

	section_header("Advanced Cross-room / Cross-floor")
	parts[#parts + 1] = "(Phase G — not run)"

	section_header("Morph Policy Classification")
	local snap = consistance.get_debug_snapshot()
	local pol = snap.morph_policy or {}
	parts[#parts + 1] = string.format("Totals(now): SUPERSEDE=%d STATE_SWITCH=%d EMPTY_PENDING=%d SAME_LIFETIME=%d UNKNOWN=%d",
		pol.supersede or 0, pol.state_switch or 0, pol.empty_pending or 0, pol.same_lifetime or 0, pol.unknown or 0)
	local lt = lifetime.get_debug_snapshot()
	parts[#parts + 1] = string.format("ESSM: available=%s api_errors=%d creates=%d hits=%d",
		tostring(lt.available), tostring(lt.api_errors), tostring(lt.creates), tostring(lt.hits))

	section_header("Failures")
	local any_fail = false
	for _, r in ipairs(rows) do
		if r.status == "FAIL" or r.status == "TIMEOUT" or r.status == "ENGINE_SEMANTICS_CHANGED" then
			any_fail = true
			parts[#parts + 1] = string.format("%s [%s]", tostring(r.name), tostring(r.status))
			for _, f in ipairs(r.failures or {}) do
				parts[#parts + 1] = "  ! " .. tostring(f)
			end
		end
	end
	if not any_fail then parts[#parts + 1] = "(none)" end

	section_header("Event Trace")
	parts[#parts + 1] = lab.get_status_text()
	return table.concat(parts, "\n")
end

local function export_paths()
	return {
		"mods/Qing_remaster/codex_work/logs/consistance_test_lab_report.txt",
		"../mods/Qing_remaster/codex_work/logs/consistance_test_lab_report.txt",
	}
end

function lab.copy_report_to_clipboard()
	-- 剪贴板放完整历史，方便一次贴出
	local text = lab.get_export_text(1)
	runner.last_export_error = nil
	if not Isaac.SetClipboard then
		runner.last_export_error = "Isaac.SetClipboard unavailable"
		runner.last_export_note = runner.last_export_error
		return false, runner.last_export_error
	end
	local ok = Isaac.SetClipboard(text)
	if ok then
		runner.last_export_path = "clipboard"
		runner.last_export_note = "copied full history to clipboard (" .. tostring(#text) .. " chars, entries=" .. tostring(#runner.results) .. ")"
		return true, "clipboard"
	end
	runner.last_export_error = "SetClipboard returned false"
	runner.last_export_note = runner.last_export_error
	return false, runner.last_export_error
end

function lab.export_report_to_file()
	-- 文件默认 append：只写入尚未导出的新 entries
	local from = (runner.exported_result_count or 0) + 1
	if from > #runner.results then
		runner.last_export_note = "nothing new to append (history=" .. tostring(#runner.results) .. ")"
		runner.last_export_error = nil
		return false, "nothing_new"
	end
	local text = lab.get_export_text(from)
	if text:sub(-1) ~= "\n" then text = text .. "\n" end
	text = "\n" .. text .. "\n"
	runner.last_export_error = nil
	runner.last_export_path = nil
	for _, path in ipairs(export_paths()) do
		local ok_open, f = pcall(io.open, path, "a")
		if ok_open and f then
			f:write(text)
			f:close()
			runner.exported_result_count = #runner.results
			runner.last_export_path = path
			runner.last_export_note = string.format("appended entries %d..%d -> %s", from, #runner.results, path)
			return true, path
		end
	end
	runner.last_export_error = "append failed (check codex_work/logs exists)"
	runner.last_export_note = runner.last_export_error
	return false, runner.last_export_error
end

function lab.clear_report_history(also_truncate_file)
	runner.results = {}
	runner.exported_result_count = 0
	runner.suite_session = 0
	runner.suite_start_index = nil
	runner.last_export_error = nil
	if also_truncate_file ~= false then
		for _, path in ipairs(export_paths()) do
			local ok_open, f = pcall(io.open, path, "w")
			if ok_open and f then
				f:write("")
				f:close()
				runner.last_export_path = path
				runner.last_export_note = "cleared history + truncated " .. path
				return true
			end
		end
		runner.last_export_note = "cleared memory history (file truncate failed)"
		return true
	end
	runner.last_export_note = "cleared memory history"
	return true
end

function lab.get_export_status_text()
	local note = runner.last_export_note or "尚未导出"
	local err = runner.last_export_error
	local extra = string.format(" | history=%d exported_through=%d", #runner.results, runner.exported_result_count or 0)
	if err then
		return note .. extra .. "\nerror: " .. tostring(err)
	end
	return note .. extra
end

function lab.get_results()
	return runner.results
end

local function advance_runner()
	if not runner.running or not runner.suite then return end
	local suite = runner.suite
	if runner.case_index > #suite.cases then
		runner.running = false
		runner.context = nil
		set_bypass(false)
		runner.status = "Complete"
		return
	end

	-- 开始新 case
	if runner.step_index == 0 then
		local case_def = suite.cases[runner.case_index]
		-- safe_all：semantic case 开 bypass，regression 关
		if suite.name == "All Safe Tests" then
			set_bypass((case_def.kind or "semantic") == "semantic")
		end
		runner.status = string.format("Running %d/%d: %s", runner.case_index, #suite.cases, case_def.name)
		if not begin_case(case_def) then
			runner.case_index = runner.case_index + 1
			runner.step_index = 0
			return
		end
		if runner.context.status == "SKIPPED" then
			finish_case(runner.context, "SKIPPED")
			runner.case_index = runner.case_index + 1
			runner.step_index = 0
			runner.context = nil
			return
		end
		runner.step_index = 1
		runner.wait = 0
		runner.wait_until = nil
		return
	end

	local case_def = suite.cases[runner.case_index]
	local steps = case_def.steps or {}
	local ctx = runner.context
	if not ctx then
		runner.case_index = runner.case_index + 1
		runner.step_index = 0
		return
	end

	watch_identities(ctx)

	if runner.wait > 0 then
		runner.wait = runner.wait - 1
		return
	end

	if runner.wait_until then
		runner.wait_timeout = runner.wait_timeout - 1
		local ok, ready = pcall(runner.wait_until, ctx)
		if ok and ready then
			runner.wait_until = nil
			runner.step_index = runner.step_index + 1
		elseif runner.wait_timeout <= 0 then
			runner.wait_until = nil
			finish_case(ctx, "TIMEOUT")
			runner.case_index = runner.case_index + 1
			runner.step_index = 0
			runner.context = nil
		end
		return
	end

	if runner.step_index > #steps then
		local ok, err = pcall(function()
			if case_def.verify then case_def.verify(ctx) end
		end)
		if not ok then
			expect(ctx, false, "verify error: " .. tostring(err))
		end
		finish_case(ctx)
		runner.case_index = runner.case_index + 1
		runner.step_index = 0
		runner.context = nil
		return
	end

	local step = steps[runner.step_index]
	if step.wait then
		runner.wait = step.wait
		if step.run then
			local ok, err = pcall(step.run, ctx)
			if not ok then
				runner.last_error = tostring(err)
				expect(ctx, false, "step error: " .. tostring(err))
				finish_case(ctx, "FAIL")
				runner.case_index = runner.case_index + 1
				runner.step_index = 0
				runner.context = nil
				return
			end
		end
		runner.step_index = runner.step_index + 1
		return
	end

	if step.wait_until then
		runner.wait_until = step.wait_until
		runner.wait_timeout = step.timeout or 120
		if step.run then pcall(step.run, ctx) end
		return
	end

	if step.run then
		local ok, err = pcall(step.run, ctx)
		if not ok then
			runner.last_error = tostring(err)
			expect(ctx, false, "step error: " .. tostring(err))
			finish_case(ctx, "FAIL")
			runner.case_index = runner.case_index + 1
			runner.step_index = 0
			runner.context = nil
			return
		end
		-- Eternal D6 重试：回到 setup 后第一 step
		if ctx._repeat_attempt then
			ctx._repeat_attempt = nil
			runner.step_index = 1
			return
		end
	end
	runner.step_index = runner.step_index + 1
end

---------------------------------------------------------------------------
-- Callbacks
---------------------------------------------------------------------------

table.insert(lab.pre_ToCall, {
	CallBack = ModCallbacks.MC_PRE_PICKUP_MORPH,
	params = nil,
	priority = -300,
	Function = function(_, pickup, entityType, variant, subtype, keepPrice, keepSeed, ignoreModifiers)
		if not is_lab_ptr(pickup) then return end
		register_lab_ptr(pickup, runner.context)
		-- Morph 可能清 GetData：PRE 时重新盖章
		pcall(function()
			local data = pickup:GetData()
			if type(data) == "table" and runner.context then
				data[MARK] = data[MARK] or {
					test_id = runner.context.test_id,
					case_id = runner.context.case_id,
					run_id = runner.context.run_id,
					tag = "pedestal",
				}
			end
		end)
		push_trace("PRE_MORPH", {
			ptr = ptr_of(pickup),
			before = identity_of(pickup),
			requested = { type = entityType, variant = variant, subtype = subtype },
			keep_price = keepPrice == true,
			keep_seed = keepSeed == true,
			ignore_modifiers = ignoreModifiers == true,
			essm_token = essm_token(pickup),
		})
	end,
})

table.insert(lab.pre_ToCall, {
	CallBack = ModCallbacks.MC_POST_PICKUP_MORPH,
	params = nil,
	priority = -300,
	Function = function(_, pickup, previousType, previousVariant, previousSubtype, keptPrice, keptSeed, ignoredModifiers)
		if not is_lab_ptr(pickup) then return end
		register_lab_ptr(pickup, runner.context)
		pcall(function()
			local data = pickup:GetData()
			if type(data) == "table" and runner.context then
				data[MARK] = data[MARK] or {
					test_id = runner.context.test_id,
					case_id = runner.context.case_id,
					run_id = runner.context.run_id,
					tag = "pedestal",
				}
			end
		end)
		push_trace("POST_MORPH", {
			ptr = ptr_of(pickup),
			after = identity_of(pickup),
			previous = { type = previousType, variant = previousVariant, subtype = previousSubtype },
			kept_price = keptPrice == true,
			kept_seed = keptSeed == true,
			ignored_modifiers = ignoredModifiers == true,
			essm_token = essm_token(pickup),
		})
	end,
})

table.insert(lab.ToCall, {
	CallBack = ModCallbacks.MC_POST_PICKUP_INIT,
	params = PickupVariant.PICKUP_COLLECTIBLE,
	Function = function(_, pickup)
		if not is_lab_ptr(pickup) then return end
		push_trace("PICKUP_INIT", {
			ptr = ptr_of(pickup),
			seed = pickup.InitSeed,
			subtype = pickup.SubType,
			essm_token = essm_token(pickup),
		})
	end,
})

table.insert(lab.myToCall, {
	CallBack = enums.Callbacks.POST_PICKUP_COLLECTIBLE,
	params = nil,
	Function = function(_, player, id, touched, pickup)
		if not is_lab_ptr(pickup) then return end
		push_trace("POST_PICKUP_COLLECTIBLE", {
			ptr = ptr_of(pickup),
			seed = pickup and pickup.InitSeed,
			subtype = pickup and (pickup.SubType or id),
			extra = { player = player and player.Index, id = id, touched = touched },
			essm_token = essm_token(pickup),
		})
	end,
})

table.insert(lab.ToCall, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		if runner.running then
			advance_runner()
		end
	end,
})

return lab
