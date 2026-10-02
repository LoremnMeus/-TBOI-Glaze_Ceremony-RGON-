-- Consistance Test Lab — Phase A：ESSM Lifetime Matrix cases。
-- 由 consistance_test_lab.lua 注入 deps（spawn / morph / observe / expect …）。

local lifetime = require("Qing_Remaster_scripts.others.Entity_lifetime_holder")

local M = {}

local function read_essm(ent, create)
	if not ent then return nil end
	if create == false then
		local info = select(1, lifetime.try_get(ent))
		return info
	end
	return select(1, lifetime.get_or_create(ent))
end

function M.build_cases(deps)
	local ITEM_A = deps.ITEM_A
	local ITEM_B = deps.ITEM_B
	local ITEM_C = deps.ITEM_C
	local spawn_collectible = deps.spawn_collectible
	local morph_pickup = deps.morph_pickup
	local empty_collectible_pedestal = deps.empty_collectible_pedestal
	local use_active = deps.use_active
	local observe = deps.observe
	local expect = deps.expect
	local summarize_case_observations = deps.summarize_case_observations
	local player0 = deps.player0
	local ptr_of = deps.ptr_of
	local game_frame = deps.game_frame

	local function essm_case(opts)
		return {
			id = opts.id,
			name = opts.name,
			kind = "essm",
			expect_observed = opts.expect_observed == true,
			setup = opts.setup,
			steps = opts.steps,
			verify = opts.verify,
			cleanup = opts.cleanup,
		}
	end

	local function snap_essm(ctx, tag, pickup)
		local p = pickup or ctx.pickup
		local info = read_essm(p, true)
		observe(ctx, tag .. "_token", info and info.token or nil)
		observe(ctx, tag .. "_is_new", info and info.is_new or nil)
		observe(ctx, tag .. "_seed", p and p.InitSeed or nil)
		observe(ctx, tag .. "_ptr", ptr_of(p))
		observe(ctx, tag .. "_subtype", p and (p.SubType or 0) or nil)
		return info
	end

	local cases = {}

	-- E1：新生成 pedestal — token 非 nil + 5 帧稳定 → PASS
	cases[#cases + 1] = essm_case({
		id = "E1",
		name = "ESSM E1 New Spawn token stable",
		expect_observed = false,
		setup = function(ctx)
			if not lifetime.is_available() then
				ctx.status = "SKIPPED"
				observe(ctx, "skip_reason", "ESSM unavailable")
				return
			end
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
			ctx.tokens = {}
		end,
		steps = {
			{ wait = 2 },
			{
				run = function(ctx)
					local info = snap_essm(ctx, "spawn", ctx.pickup)
					ctx.token0 = info and info.token
					ctx.tokens[#ctx.tokens + 1] = ctx.token0
				end,
			},
			{ wait = 1, run = function(ctx) ctx.tokens[#ctx.tokens + 1] = lifetime.get_token(ctx.pickup) end },
			{ wait = 1, run = function(ctx) ctx.tokens[#ctx.tokens + 1] = lifetime.get_token(ctx.pickup) end },
			{ wait = 1, run = function(ctx) ctx.tokens[#ctx.tokens + 1] = lifetime.get_token(ctx.pickup) end },
			{ wait = 1, run = function(ctx) ctx.tokens[#ctx.tokens + 1] = lifetime.get_token(ctx.pickup) end },
			{ wait = 1, run = function(ctx) ctx.tokens[#ctx.tokens + 1] = lifetime.get_token(ctx.pickup) end },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			local snap = lifetime.get_debug_snapshot()
			observe(ctx, "api_errors", snap.api_errors)
			expect(ctx, ctx.token0 ~= nil, "token non-nil")
			local stable = true
			for _, t in ipairs(ctx.tokens or {}) do
				if t ~= ctx.token0 then stable = false break end
			end
			observe(ctx, "token_stable_5", stable)
			expect(ctx, stable, "token stable across 5 frames")
			expect(ctx, (snap.api_errors or 0) == 0, "API errors = 0")
			-- 同帧多次 get_token 一致
			local a = lifetime.get_token(ctx.pickup)
			local b = lifetime.get_token(ctx.pickup)
			expect(ctx, a == b and a == ctx.token0, "same-frame get_token consistent")
		end,
	})

	-- E2：同房 idle 120 帧 — token 不变 → PASS
	cases[#cases + 1] = essm_case({
		id = "E2",
		name = "ESSM E2 Idle 120f token stable",
		expect_observed = false,
		setup = function(ctx)
			if not lifetime.is_available() then ctx.status = "SKIPPED" return end
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
			ctx.samples = {}
			ctx.idle_frames = 0
		end,
		steps = {
			{ wait = 2, run = function(ctx)
				ctx.token0 = lifetime.get_token(ctx.pickup)
				observe(ctx, "idle_token0", ctx.token0)
			end },
			{
				wait_until = function(ctx)
					ctx.idle_frames = (ctx.idle_frames or 0) + 1
					if (ctx.idle_frames % 10) == 0 then
						ctx.samples[#ctx.samples + 1] = {
							frame = game_frame(),
							token = lifetime.get_token(ctx.pickup),
							seed = ctx.pickup and ctx.pickup.InitSeed,
							ptr = ptr_of(ctx.pickup),
						}
					end
					return ctx.idle_frames >= 120
				end,
				timeout = 180,
			},
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			local ok = true
			for _, s in ipairs(ctx.samples or {}) do
				if s.token ~= ctx.token0 then ok = false break end
			end
			observe(ctx, "idle_samples", #(ctx.samples or {}))
			observe(ctx, "idle_stable", ok)
			expect(ctx, ctx.token0 ~= nil, "token non-nil")
			expect(ctx, ok, "token unchanged during idle")
		end,
	})

	-- E3：Cycle — OBSERVED；同显示 subtype 内抖动 → FAIL
	cases[#cases + 1] = essm_case({
		id = "E3",
		name = "ESSM E3 CollectibleCycle token observe",
		expect_observed = true,
		setup = function(ctx)
			if not lifetime.is_available() then ctx.status = "SKIPPED" return end
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
			if not (ctx.pickup and ctx.pickup.AddCollectibleCycle) then
				ctx.status = "SKIPPED"
				return
			end
			ctx.pickup:AddCollectibleCycle(ITEM_B)
			ctx.pickup:AddCollectibleCycle(ITEM_C)
			ctx.subtype_changes = 0
			ctx.tokens_seen = {}
			ctx.last_st = nil
			ctx.last_token_for_st = nil
			ctx.jitter = false
			ctx.cycle_frames = 0
			ctx.target_changes = 40
		end,
		steps = {
			{ wait = 2, run = function(ctx)
				ctx.token0 = lifetime.get_token(ctx.pickup)
				ctx.last_st = ctx.pickup.SubType
				ctx.last_token_for_st = ctx.token0
				ctx.tokens_seen[tostring(ctx.token0)] = true
			end },
			{
				wait_until = function(ctx)
					ctx.cycle_frames = (ctx.cycle_frames or 0) + 1
					local p = ctx.pickup
					if not (p and p:Exists()) then return true end
					local st = p.SubType or 0
					local tok = lifetime.get_token(p)
					if tok ~= nil then ctx.tokens_seen[tostring(tok)] = true end
					if ctx.last_st ~= nil and st ~= ctx.last_st then
						ctx.subtype_changes = (ctx.subtype_changes or 0) + 1
						ctx.last_st = st
						ctx.last_token_for_st = tok
					elseif tok ~= nil and ctx.last_token_for_st ~= nil and tok ~= ctx.last_token_for_st and st == ctx.last_st then
						ctx.jitter = true
					end
					if ctx.subtype_changes >= (ctx.target_changes or 40) then return true end
					return ctx.cycle_frames >= 280
				end,
				timeout = 300,
			},
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			local distinct = 0
			for _ in pairs(ctx.tokens_seen or {}) do distinct = distinct + 1 end
			observe(ctx, "subtype_changes", ctx.subtype_changes or 0)
			observe(ctx, "distinct_tokens", distinct)
			observe(ctx, "token0", ctx.token0)
			observe(ctx, "morph_count", ctx.counts and ctx.counts.post_morph or 0)
			expect(ctx, ctx.jitter ~= true, "token must not jitter within same subtype display")
			-- OBSERVED：distinct_tokens 记录，不强制 =1
		end,
	})

	-- E4 keepSeed=false Morph — OBSERVED
	cases[#cases + 1] = essm_case({
		id = "E4",
		name = "ESSM E4 Morph keepSeed=false",
		expect_observed = true,
		setup = function(ctx)
			if not lifetime.is_available() then ctx.status = "SKIPPED" return end
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
		end,
		steps = {
			{ wait = 2, run = function(ctx) snap_essm(ctx, "before", ctx.pickup) end },
			{ run = function(ctx) morph_pickup(ctx.pickup, ITEM_B, false) end },
			{ wait = 4, run = function(ctx) snap_essm(ctx, "after", ctx.pickup) end },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			observe(ctx, "seed_changed", ctx.observations.before_seed ~= ctx.observations.after_seed)
			observe(ctx, "token_changed", ctx.observations.before_token ~= ctx.observations.after_token)
			observe(ctx, "ptr_changed", ctx.observations.before_ptr ~= ctx.observations.after_ptr)
		end,
	})

	-- E5 keepSeed=true — OBSERVED（关键）
	cases[#cases + 1] = essm_case({
		id = "E5",
		name = "ESSM E5 Morph keepSeed=true",
		expect_observed = true,
		setup = function(ctx)
			if not lifetime.is_available() then ctx.status = "SKIPPED" return end
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
		end,
		steps = {
			{ wait = 2, run = function(ctx) snap_essm(ctx, "before", ctx.pickup) end },
			{ run = function(ctx) morph_pickup(ctx.pickup, ITEM_B, true) end },
			{ wait = 4, run = function(ctx) snap_essm(ctx, "after", ctx.pickup) end },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			observe(ctx, "seed_same", ctx.observations.before_seed == ctx.observations.after_seed)
			observe(ctx, "token_same", ctx.observations.before_token == ctx.observations.after_token)
			observe(ctx, "ptr_same", ctx.observations.before_ptr == ctx.observations.after_ptr)
		end,
	})

	-- E6 D6 — OBSERVED
	cases[#cases + 1] = essm_case({
		id = "E6",
		name = "ESSM E6 Actual D6",
		expect_observed = true,
		setup = function(ctx)
			if not lifetime.is_available() then ctx.status = "SKIPPED" return end
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
		end,
		steps = {
			{ wait = 2, run = function(ctx) snap_essm(ctx, "before", ctx.pickup) end },
			{ run = function(ctx) use_active(CollectibleType.COLLECTIBLE_D6) end },
			{ wait = 10, run = function(ctx) snap_essm(ctx, "after", ctx.pickup) end },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			observe(ctx, "seed_changed", ctx.observations.before_seed ~= ctx.observations.after_seed)
			observe(ctx, "token_changed", ctx.observations.before_token ~= ctx.observations.after_token)
		end,
	})

	-- E7 TryRemove → 空 — OBSERVED
	cases[#cases + 1] = essm_case({
		id = "E7",
		name = "ESSM E7 TryRemove empty pedestal",
		expect_observed = true,
		setup = function(ctx)
			if not lifetime.is_available() then ctx.status = "SKIPPED" return end
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
		end,
		steps = {
			{ wait = 2, run = function(ctx) snap_essm(ctx, "before", ctx.pickup) end },
			{ run = function(ctx)
				ctx._emptied = empty_collectible_pedestal(ctx.pickup)
			end },
			{ wait_until = function(ctx)
				return ctx.pickup and ctx.pickup:Exists() and (ctx.pickup.SubType or 0) == 0
			end, timeout = 60 },
			{ wait = 2, run = function(ctx) snap_essm(ctx, "empty", ctx.pickup) end },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			observe(ctx, "emptied", ctx._emptied == true)
			observe(ctx, "entity_exists", ctx.pickup and ctx.pickup:Exists())
			observe(ctx, "subtype0", ctx.pickup and (ctx.pickup.SubType or 0) == 0)
			observe(ctx, "token_same_on_empty",
				ctx.observations.before_token ~= nil
				and ctx.observations.before_token == ctx.observations.empty_token)
		end,
	})

	-- E8 空 → 恢复 A — OBSERVED
	cases[#cases + 1] = essm_case({
		id = "E8",
		name = "ESSM E8 Empty then restore A",
		expect_observed = true,
		setup = function(ctx)
			if not lifetime.is_available() then ctx.status = "SKIPPED" return end
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
		end,
		steps = {
			{ wait = 2, run = function(ctx) snap_essm(ctx, "before", ctx.pickup) end },
			{ run = function(ctx) empty_collectible_pedestal(ctx.pickup) end },
			{ wait_until = function(ctx)
				return ctx.pickup and ctx.pickup:Exists() and (ctx.pickup.SubType or 0) == 0
			end, timeout = 60 },
			{ wait = 2, run = function(ctx) snap_essm(ctx, "empty", ctx.pickup) end },
			{ run = function(ctx) morph_pickup(ctx.pickup, ITEM_A, true) end },
			{ wait = 4, run = function(ctx) snap_essm(ctx, "restored", ctx.pickup) end },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			observe(ctx, "restored_subtype", ctx.observations.restored_subtype)
			observe(ctx, "token_before_vs_empty",
				tostring(ctx.observations.before_token) .. "->" .. tostring(ctx.observations.empty_token))
			observe(ctx, "token_empty_vs_restored",
				tostring(ctx.observations.empty_token) .. "->" .. tostring(ctx.observations.restored_token))
		end,
	})

	-- E9 普通拾取 — OBSERVED
	cases[#cases + 1] = essm_case({
		id = "E9",
		name = "ESSM E9 Normal pickup",
		expect_observed = true,
		setup = function(ctx)
			if not lifetime.is_available() then ctx.status = "SKIPPED" return end
			local player = player0()
			local room = Game():GetRoom()
			local pos = (player and player.Position or room:GetCenterPos()) + Vector(0, 24)
			ctx.pickup = spawn_collectible(ctx, ITEM_A, pos)
		end,
		steps = {
			{ wait = 2, run = function(ctx) snap_essm(ctx, "before", ctx.pickup) end },
			{ run = function(ctx)
				local player = player0()
				if player and ctx.pickup and ctx.pickup:Exists() then
					player.Position = ctx.pickup.Position
				end
			end },
			{ wait_until = function(ctx)
				return (ctx.counts.pickup_success or 0) > 0 or (ctx.counts.entity_gone or 0) > 0
			end, timeout = 120 },
			{ wait = 5 },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			observe(ctx, "token_before", ctx.observations.before_token)
		end,
	})

	-- E10 Direct Remove — OBSERVED
	cases[#cases + 1] = essm_case({
		id = "E10",
		name = "ESSM E10 Direct Remove",
		expect_observed = true,
		setup = function(ctx)
			if not lifetime.is_available() then ctx.status = "SKIPPED" return end
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
		end,
		steps = {
			{ wait = 2, run = function(ctx) snap_essm(ctx, "before", ctx.pickup) end },
			{ run = function(ctx) if ctx.pickup then ctx.pickup:Remove() end end },
			{ wait = 4 },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			observe(ctx, "token_before", ctx.observations.before_token)
		end,
	})

	-- E11 Options sibling — OBSERVED
	cases[#cases + 1] = essm_case({
		id = "E11",
		name = "ESSM E11 Options sibling remove",
		expect_observed = true,
		setup = function(ctx)
			if not lifetime.is_available() then ctx.status = "SKIPPED" return end
			local room = Game():GetRoom()
			local c = room:GetCenterPos()
			ctx.pickup_a = spawn_collectible(ctx, ITEM_A, c + Vector(-40, 0))
			ctx.pickup_b = spawn_collectible(ctx, ITEM_B, c + Vector(40, 0))
			if ctx.pickup_a and ctx.pickup_b then
				local idx = ctx.pickup_a.OptionsPickupIndex
				if idx == 0 then
					idx = 1
					ctx.pickup_a.OptionsPickupIndex = idx
				end
				ctx.pickup_b.OptionsPickupIndex = idx
			end
			ctx.pickup = ctx.pickup_a
		end,
		steps = {
			{ wait = 2, run = function(ctx)
				snap_essm(ctx, "a_before", ctx.pickup_a)
				snap_essm(ctx, "b_before", ctx.pickup_b)
			end },
			{ run = function(ctx)
				local player = player0()
				if player and ctx.pickup_a and ctx.pickup_a:Exists() then
					player.Position = ctx.pickup_a.Position
				end
			end },
			{ wait_until = function(ctx)
				return (ctx.counts.pickup_success or 0) > 0
					or (ctx.pickup_b and (not ctx.pickup_b:Exists() or (ctx.pickup_b.SubType or 0) == 0))
			end, timeout = 120 },
			{ wait = 5, run = function(ctx)
				if ctx.pickup_b and ctx.pickup_b:Exists() then
					snap_essm(ctx, "b_after", ctx.pickup_b)
				else
					observe(ctx, "b_gone", true)
				end
			end },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
		end,
	})

	-- E12 Room leave/return — OBSERVED（有门才跑；否则 SKIPPED）
	cases[#cases + 1] = essm_case({
		id = "E12",
		name = "ESSM E12 Room leave/return token",
		expect_observed = true,
		setup = function(ctx)
			if not lifetime.is_available() then ctx.status = "SKIPPED" return end
			local room = Game():GetRoom()
			local door_slot, door
			for i = 0, 7 do
				local d = room:GetDoor(i)
				if d and d:IsOpen() then
					door_slot = i
					door = d
					break
				end
			end
			if not door then
				for i = 0, 7 do
					local d = room:GetDoor(i)
					if d then door_slot = i door = d break end
				end
			end
			if not door then
				ctx.status = "SKIPPED"
				observe(ctx, "skip_reason", "no door")
				return
			end
			ctx.home_index = Game():GetLevel():GetCurrentRoomIndex()
			ctx.door_slot = door_slot
			ctx.target_index = door.TargetRoomIndex
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
			ctx.phase = "home"
		end,
		steps = {
			{ wait = 2, run = function(ctx)
				local info = snap_essm(ctx, "home", ctx.pickup)
				ctx.token_home = info and info.token
				ctx.seed_home = ctx.pickup and ctx.pickup.InitSeed
			end },
			{ run = function(ctx)
				local player = player0()
				pcall(function()
					Game():StartRoomTransition(ctx.target_index, Direction.NO_DIRECTION, RoomTransitionAnim.WALK, player)
				end)
				ctx.phase = "left"
			end },
			{ wait_until = function(ctx)
				return Game():GetLevel():GetCurrentRoomIndex() ~= ctx.home_index
			end, timeout = 300 },
			{ wait = 10, run = function(ctx)
				local player = player0()
				pcall(function()
					Game():StartRoomTransition(ctx.home_index, Direction.NO_DIRECTION, RoomTransitionAnim.WALK, player)
				end)
				ctx.phase = "returning"
			end },
			{ wait_until = function(ctx)
				return Game():GetLevel():GetCurrentRoomIndex() == ctx.home_index
					and Game():GetRoom():GetFrameCount() > 0
			end, timeout = 300 },
			{ wait = 8, run = function(ctx)
				-- 按 InitSeed 找回底座
				local found
				local ok, list = pcall(function() return Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, -1, false, false) end)
				if ok and type(list) == "table" then
					for _, ent in ipairs(list) do
						if ent.InitSeed == ctx.seed_home then
							found = ent:ToPickup() or ent
							break
						end
					end
				end
				ctx.pickup = found
				if found then
					-- 可能是 restored：优先 try_get，再 get_or_create
					local info = select(1, lifetime.try_get(found)) or select(1, lifetime.get_or_create(found))
					observe(ctx, "return_token", info and info.token or nil)
					observe(ctx, "return_is_new", info and info.is_new or nil)
					observe(ctx, "return_seed", found.InitSeed)
					ctx.token_return = info and info.token
					-- ESSM 明确恢复 namespace 却丢 token → FAIL（try_get nil 且 get_or_create is_new）
					if select(1, lifetime.try_get(found)) == nil and info and info.is_new == true then
						-- 无法区分「真丢了」与「从未写入」；仅当 home token 存在且 return 分配了新 token 时记 WARN 式观察
						observe(ctx, "possible_token_loss", ctx.token_home ~= nil and info.token ~= ctx.token_home)
					end
				else
					observe(ctx, "return_pedestal_missing", true)
				end
			end },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			observe(ctx, "token_home", ctx.token_home)
			observe(ctx, "token_return", ctx.token_return)
			observe(ctx, "token_same", ctx.token_home ~= nil and ctx.token_home == ctx.token_return)
			-- 理想 T1==T2，首次仍 OBSERVED；若 namespace 恢复却 token 丢失则 FAIL
			if ctx.observations.possible_token_loss == true and ctx.token_return ~= ctx.token_home then
				expect(ctx, false, "ESSM restored namespace but lost previous token")
			end
		end,
	})

	-- E13 Save/Continue：仅 Prepare，本 suite 内 SKIPPED 说明
	cases[#cases + 1] = essm_case({
		id = "E13",
		name = "ESSM E13 Save/Continue (manual prepare)",
		expect_observed = true,
		setup = function(ctx)
			ctx.status = "SKIPPED"
			observe(ctx, "skip_reason", "use Prepare Save/Continue Test button")
		end,
		steps = {},
		verify = function(ctx) end,
	})

	return cases
end

function M.prepare_save_continue(pickup)
	if not pickup then return false, "no pickup" end
	local info = select(1, lifetime.get_or_create(pickup))
	local save = require("Qing_Remaster_scripts.core.savedata")
	save.elses = save.elses or {}
	local level = Game():GetLevel()
	local desc = level:GetCurrentRoomDesc()
	save.elses.ConsistanceLabSaveContinue = {
		room_list_index = desc and desc.ListIndex or nil,
		room_grid_index = level:GetCurrentRoomIndex(),
		init_seed = pickup.InitSeed,
		subtype = pickup.SubType,
		token = info and info.token or nil,
		frame = Game():GetFrameCount(),
	}
	return true, save.elses.ConsistanceLabSaveContinue
end

function M.check_save_continue()
	local save = require("Qing_Remaster_scripts.core.savedata")
	local expected = save.elses and save.elses.ConsistanceLabSaveContinue
	if type(expected) ~= "table" then
		return { status = "SKIPPED", reason = "no prepared expect" }
	end
	local found
	local ok, list = pcall(function()
		return Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, -1, false, false)
	end)
	if ok and type(list) == "table" then
		for _, ent in ipairs(list) do
			if ent.InitSeed == expected.init_seed then
				found = ent:ToPickup() or ent
				break
			end
		end
	end
	if not found then
		return { status = "OBSERVED", reason = "pedestal not found", expected = expected }
	end
	local info = select(1, lifetime.try_get(found)) or select(1, lifetime.get_or_create(found))
	return {
		status = "OBSERVED",
		expected_token = expected.token,
		actual_token = info and info.token,
		token_same = expected.token ~= nil and info and info.token == expected.token,
		is_new = info and info.is_new,
		seed = found.InitSeed,
		subtype = found.SubType,
	}
end

return M
