-- Consistance Test Lab — Phase 1：Unique dual-axis Shadow Matrix。
-- Native ESSM lifetime ≠ Unique business generation。禁止重写 production class。

local unique = require("Qing_Remaster_scripts.others.Unique_holder")
local lifetime = require("Qing_Remaster_scripts.others.Entity_lifetime_holder")

local M = {}

local function shadow_snap()
	return unique.get_shadow_snapshot()
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

	--- 只读 production 结果，禁止改写 class。
	local function snap_row(ctx, tag, pickup, token_before)
		local p = pickup or ctx.pickup
		local d = p and p:GetData() or {}
		local gen = d._QingUniqueGeneration
		local row = unique.shadow_compare_pickup(p)
		local native = unique.get_native_identity(p)
		local prefix = tag and (tag .. "_") or ""
		observe(ctx, prefix .. "class", row and row.class)
		observe(ctx, prefix .. "gen_kind", (gen and gen.kind) or (row and row.generation_kind))
		observe(ctx, prefix .. "gen_source", (gen and gen.source) or (row and row.generation_source))
		observe(ctx, prefix .. "gen_id", gen and gen.id)
		observe(ctx, prefix .. "native_kind", native and native.kind)
		observe(ctx, prefix .. "native_token", native and native.token)
		observe(ctx, prefix .. "token_before", token_before)
		observe(ctx, prefix .. "token_after", native and native.token)
		observe(ctx, prefix .. "token_same", token_before ~= nil and native and native.token == token_before)
		observe(ctx, prefix .. "registry_hit", native and native.registry_hit)
		observe(ctx, prefix .. "live_tryget_hit", native and native.live_tryget_hit)
		observe(ctx, prefix .. "room_frame", row and row.room_frame or Game():GetRoom():GetFrameCount())
		observe(ctx, prefix .. "flag_new", d.first_appear == true)
		observe(ctx, prefix .. "flag_new2", d.first_appear2 == true)
		observe(ctx, prefix .. "seed", p and p.InitSeed)
		observe(ctx, prefix .. "subtype", p and (p.SubType or 0))
		return row, gen, native
	end

	local function u_case(opts)
		return {
			id = opts.id,
			name = opts.name,
			kind = "unique_shadow",
			expect_observed = opts.expect_observed == true,
			expect_warn = opts.expect_warn == true,
			setup = opts.setup,
			steps = opts.steps,
			verify = opts.verify,
			cleanup = opts.cleanup,
		}
	end

	local function enable_shadow(ctx)
		unique.set_force_legacy_backend(false)
		unique.set_shadow_enabled(true)
		unique.reset_shadow_stats()
		ctx._shadow_was_on = true
		observe(ctx, "backend", unique.get_backend_name())
	end

	local function disable_shadow(ctx)
		if ctx and ctx._shadow_was_on then
			unique.set_shadow_enabled(false)
		end
	end

	local function gen_is_new(k)
		return k == "GEN_NEW"
	end
	local function gen_is_same(k)
		return k == "GEN_SAME"
	end
	local function gen_is_restored(k)
		return k == "GEN_RESTORED"
	end
	local function gen_is_empty(k)
		return k == "GEN_EMPTY"
	end

	local cases = {}

	-- U1：Mid-room Spawn → GEN_NEW
	cases[#cases + 1] = u_case({
		id = "U1",
		name = "Unique Shadow U1 Mid-room Spawn NEW",
		setup = function(ctx)
			if not lifetime.is_available() then ctx.status = "SKIPPED" return end
			enable_shadow(ctx)
		end,
		steps = {
			{ wait = 2, run = function(ctx)
				expect(ctx, Game():GetRoom():GetFrameCount() >= 0, "mid-room")
				ctx.pickup = spawn_collectible(ctx, ITEM_A)
				lifetime.ensure_token(ctx.pickup)
			end },
			{ wait = 2, run = function(ctx)
				snap_row(ctx, nil, ctx.pickup, nil)
			end },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			expect(ctx, unique.get_backend_name() == "essm", "ESSM backend")
			expect(ctx, gen_is_new(ctx.observations.gen_kind), "GEN_NEW")
			expect(ctx, ctx.observations.flag_new == true, "first_appear true")
			expect(ctx, ctx.observations.class == "MATCH", "production class MATCH")
			expect(
				ctx,
				ctx.observations.gen_source == "midroom_new" or ctx.observations.gen_source == "morph_replacement",
				"source midroom_new"
			)
		end,
		cleanup = disable_shadow,
	})

	-- U2：First-Visit Natural Spawn（尽力；无未访房则 SKIPPED）
	cases[#cases + 1] = u_case({
		id = "U2",
		name = "Unique Shadow U2 First-Visit Natural Spawn NEW",
		expect_observed = true,
		setup = function(ctx)
			if not lifetime.is_available() then ctx.status = "SKIPPED" return end
			enable_shadow(ctx)
			local level = Game():GetLevel()
			local rooms = level:GetRooms()
			local target
			local n = 0
			pcall(function() n = rooms.Size end)
			for i = 0, math.max(0, n - 1) do
				local desc
				pcall(function() desc = rooms:Get(i) end)
				if desc and desc.VisitedCount == 0 and desc.Data and desc.Data.Type == RoomType.ROOM_TREASURE then
					target = desc
					break
				end
			end
			if not target then
				for i = 0, math.max(0, n - 1) do
					local desc
					pcall(function() desc = rooms:Get(i) end)
					if desc and desc.VisitedCount == 0 and desc.SafeGridIndex then
						target = desc
						break
					end
				end
			end
			if not target then
				ctx.status = "SKIPPED"
				observe(ctx, "skip_reason", "no unvisited room")
				return
			end
			ctx.home_index = level:GetCurrentRoomIndex()
			ctx.target_list = target.ListIndex
			ctx.target_grid = target.SafeGridIndex
		end,
		steps = {
			{ wait = 1, run = function(ctx)
				local player = player0()
				pcall(function()
					Game():StartRoomTransition(ctx.target_grid, Direction.NO_DIRECTION, RoomTransitionAnim.WALK, player)
				end)
			end },
			{ wait_until = function(ctx)
				local level = Game():GetLevel()
				local desc = level:GetCurrentRoomDesc()
				return desc and desc.ListIndex == ctx.target_list and Game():GetRoom():GetFrameCount() > 0
			end, timeout = 300 },
			{ wait = 8, run = function(ctx)
				local found
				local ok, list = pcall(function()
					return Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, -1, false, false)
				end)
				if ok and type(list) == "table" then
					for _, ent in ipairs(list) do
						if (ent.SubType or 0) ~= 0 then
							found = ent:ToPickup() or ent
							break
						end
					end
				end
				ctx.pickup = found
				if found then
					snap_row(ctx, nil, found, nil)
					observe(ctx, "first_visit", Game():GetRoom():IsFirstVisit())
				else
					observe(ctx, "no_pedestal", true)
				end
			end },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			if ctx.observations.no_pedestal or ctx.status == "SKIPPED" then
				ctx.status = "OBSERVED"
				return
			end
			-- 进房后采样已过 FrameCount>0；仍要求 GEN_NEW + first_appear（自然首访）
			expect(ctx, gen_is_new(ctx.observations.gen_kind), "GEN_NEW natural")
			expect(ctx, ctx.observations.flag_new == true, "first_appear")
			expect(ctx, ctx.observations.registry_hit ~= true, "registry miss")
			ctx.status = "OBSERVED"
		end,
		cleanup = disable_shadow,
	})

	-- U3：Room Restore → GEN_RESTORED
	cases[#cases + 1] = u_case({
		id = "U3",
		name = "Unique Shadow U3 Room Restore RESTORED",
		setup = function(ctx)
			if not lifetime.is_available() then ctx.status = "SKIPPED" return end
			local room = Game():GetRoom()
			local door
			for i = 0, 7 do
				local d = room:GetDoor(i)
				if d and d:IsOpen() then door = d break end
			end
			if not door then
				for i = 0, 7 do
					local d = room:GetDoor(i)
					if d then door = d break end
				end
			end
			if not door then
				ctx.status = "SKIPPED"
				observe(ctx, "skip_reason", "no door")
				return
			end
			enable_shadow(ctx)
			ctx.home_index = Game():GetLevel():GetCurrentRoomIndex()
			ctx.target_index = door.TargetRoomIndex
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
			ctx.seed = ctx.pickup.InitSeed
			lifetime.ensure_token(ctx.pickup)
			ctx.token0 = lifetime.get_token(ctx.pickup)
			ctx.gen_id0 = ctx.pickup:GetData()._QingUniqueGeneration and ctx.pickup:GetData()._QingUniqueGeneration.id
		end,
		steps = {
			{ wait = 3 },
			{ run = function(ctx)
				local player = player0()
				pcall(function()
					Game():StartRoomTransition(ctx.target_index, Direction.NO_DIRECTION, RoomTransitionAnim.WALK, player)
				end)
			end },
			{ wait_until = function(ctx)
				return Game():GetLevel():GetCurrentRoomIndex() ~= ctx.home_index
			end, timeout = 300 },
			{ wait = 8, run = function(ctx)
				local player = player0()
				pcall(function()
					Game():StartRoomTransition(ctx.home_index, Direction.NO_DIRECTION, RoomTransitionAnim.WALK, player)
				end)
			end },
			{ wait_until = function(ctx)
				return Game():GetLevel():GetCurrentRoomIndex() == ctx.home_index
					and Game():GetRoom():GetFrameCount() > 0
			end, timeout = 300 },
			{ wait = 10, run = function(ctx)
				local found
				local ok, list = pcall(function()
					return Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, -1, false, false)
				end)
				if ok and type(list) == "table" then
					for _, ent in ipairs(list) do
						if ent.InitSeed == ctx.seed then
							found = ent:ToPickup() or ent
							break
						end
					end
				end
				ctx.pickup = found
				if found then
					snap_row(ctx, "return", found, ctx.token0)
				else
					observe(ctx, "return_missing", true)
				end
			end },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			expect(ctx, ctx.observations.return_missing ~= true, "restored found")
			local k = ctx.observations.return_gen_kind
			expect(ctx, gen_is_restored(k) or gen_is_same(k), "GEN_RESTORED (or SAME after settle)")
			expect(ctx, ctx.observations.return_flag_new ~= true, "first_appear false")
			if gen_is_restored(k) then
				expect(ctx, ctx.observations.return_registry_hit == true, "registry hit")
			end
		end,
		cleanup = disable_shadow,
	})

	-- U4：Cycle → GEN_SAME，generation id 不变
	cases[#cases + 1] = u_case({
		id = "U4",
		name = "Unique Shadow U4 Cycle SAME_GENERATION",
		expect_warn = true,
		setup = function(ctx)
			if not lifetime.is_available() then ctx.status = "SKIPPED" return end
			enable_shadow(ctx)
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
			if not (ctx.pickup and ctx.pickup.AddCollectibleCycle) then
				ctx.status = "SKIPPED"
				return
			end
			lifetime.ensure_token(ctx.pickup)
			ctx.token0 = lifetime.get_token(ctx.pickup)
			ctx.gen_id0 = ctx.pickup:GetData()._QingUniqueGeneration and ctx.pickup:GetData()._QingUniqueGeneration.id
			ctx.pickup:AddCollectibleCycle(ITEM_B)
			ctx.pickup:AddCollectibleCycle(ITEM_C)
			ctx.subtype_changes = 0
			ctx.last_st = nil
			ctx.frames = 0
		end,
		steps = {
			{ wait = 2, run = function(ctx) ctx.last_st = ctx.pickup.SubType end },
			{
				wait_until = function(ctx)
					ctx.frames = (ctx.frames or 0) + 1
					local p = ctx.pickup
					if not (p and p:Exists()) then return true end
					local st = p.SubType or 0
					if ctx.last_st ~= nil and st ~= ctx.last_st then
						ctx.subtype_changes = (ctx.subtype_changes or 0) + 1
						ctx.last_st = st
					end
					return (ctx.subtype_changes or 0) >= 12 or ctx.frames >= 200
				end,
				timeout = 240,
			},
			{ wait = 2, run = function(ctx)
				snap_row(ctx, nil, ctx.pickup, ctx.token0)
				observe(ctx, "gen_id_unchanged", ctx.gen_id0 ~= nil and ctx.observations.gen_id == ctx.gen_id0)
			end },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			expect(ctx, gen_is_same(ctx.observations.gen_kind), "GEN_SAME")
			expect(ctx, ctx.observations.flag_new ~= true, "first_appear false")
			expect(ctx, ctx.observations.token_same == true, "native token same")
			expect(ctx, ctx.observations.gen_id_unchanged == true, "generation id unchanged")
		end,
		cleanup = disable_shadow,
	})

	-- U5：keepSeed=true → GEN_SAME
	cases[#cases + 1] = u_case({
		id = "U5",
		name = "Unique Shadow U5 keepSeed=true SAME_GENERATION",
		setup = function(ctx)
			if not lifetime.is_available() then ctx.status = "SKIPPED" return end
			enable_shadow(ctx)
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
		end,
		steps = {
			{ wait = 3, run = function(ctx)
				lifetime.ensure_token(ctx.pickup)
				ctx.token0 = lifetime.get_token(ctx.pickup)
				ctx.gen_id0 = ctx.pickup:GetData()._QingUniqueGeneration and ctx.pickup:GetData()._QingUniqueGeneration.id
				ctx.seed0 = ctx.pickup.InitSeed
			end },
			{ run = function(ctx)
				unique.reset_shadow_stats()
				morph_pickup(ctx.pickup, ITEM_B, true)
			end },
			{ wait = 4, run = function(ctx)
				snap_row(ctx, nil, ctx.pickup, ctx.token0)
				observe(ctx, "seed_changed", ctx.pickup.InitSeed ~= ctx.seed0)
				observe(ctx, "gen_id_unchanged", ctx.gen_id0 ~= nil and ctx.observations.gen_id == ctx.gen_id0)
			end },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			expect(ctx, gen_is_same(ctx.observations.gen_kind), "GEN_SAME")
			expect(ctx, ctx.observations.flag_new ~= true, "first_appear false")
			expect(ctx, ctx.observations.token_same == true, "native token same (OBSERVED axis ok)")
			expect(ctx, ctx.observations.seed_changed ~= true, "seed unchanged")
			expect(ctx, ctx.observations.gen_id_unchanged == true, "generation id unchanged")
		end,
		cleanup = disable_shadow,
	})

	-- U6：keepSeed=false → GEN_NEW；token OBSERVED
	cases[#cases + 1] = u_case({
		id = "U6",
		name = "Unique Shadow U6 keepSeed=false NEW_GENERATION",
		setup = function(ctx)
			if not lifetime.is_available() then ctx.status = "SKIPPED" return end
			enable_shadow(ctx)
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
		end,
		steps = {
			{ wait = 3, run = function(ctx)
				lifetime.ensure_token(ctx.pickup)
				ctx.token0 = lifetime.get_token(ctx.pickup)
				ctx.seed0 = ctx.pickup.InitSeed
				ctx.gen_id0 = ctx.pickup:GetData()._QingUniqueGeneration and ctx.pickup:GetData()._QingUniqueGeneration.id
			end },
			{ run = function(ctx)
				unique.reset_shadow_stats()
				morph_pickup(ctx.pickup, ITEM_B, false)
			end },
			{ wait = 4, run = function(ctx)
				snap_row(ctx, nil, ctx.pickup, ctx.token0)
				observe(ctx, "seed_changed", ctx.pickup.InitSeed ~= ctx.seed0)
				observe(ctx, "gen_id_changed", ctx.gen_id0 ~= nil and ctx.observations.gen_id ~= ctx.gen_id0)
			end },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			expect(ctx, ctx.observations.seed_changed == true, "seed_changed")
			expect(ctx, gen_is_new(ctx.observations.gen_kind), "GEN_NEW")
			expect(ctx, ctx.observations.flag_new == true, "first_appear true")
			observe(ctx, "native_token_observed", ctx.observations.token_same)
			-- token 是否同轴仅 OBSERVED，不参与 PASS/FAIL
		end,
		cleanup = disable_shadow,
	})

	-- U7：D6 → GEN_NEW；ESSM token OBSERVED
	cases[#cases + 1] = u_case({
		id = "U7",
		name = "Unique Shadow U7 D6 NEW_GENERATION",
		setup = function(ctx)
			if not lifetime.is_available() then ctx.status = "SKIPPED" return end
			enable_shadow(ctx)
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
		end,
		steps = {
			{ wait = 3, run = function(ctx)
				lifetime.ensure_token(ctx.pickup)
				ctx.token0 = lifetime.get_token(ctx.pickup)
				ctx.seed0 = ctx.pickup.InitSeed
				ctx.gen_id0 = ctx.pickup:GetData()._QingUniqueGeneration and ctx.pickup:GetData()._QingUniqueGeneration.id
			end },
			{ run = function(ctx)
				unique.reset_shadow_stats()
				use_active(CollectibleType.COLLECTIBLE_D6)
			end },
			{ wait = 10, run = function(ctx)
				snap_row(ctx, nil, ctx.pickup, ctx.token0)
				observe(ctx, "seed_changed", ctx.pickup and ctx.pickup.InitSeed ~= ctx.seed0)
				observe(ctx, "gen_id_changed", ctx.gen_id0 ~= nil and ctx.observations.gen_id ~= ctx.gen_id0)
			end },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			expect(ctx, gen_is_new(ctx.observations.gen_kind), "GEN_NEW")
			expect(ctx, ctx.observations.flag_new == true, "first_appear true")
			observe(ctx, "native_token_observed", ctx.observations.token_same)
		end,
		cleanup = disable_shadow,
	})

	-- U8：Empty not GEN_NEW
	cases[#cases + 1] = u_case({
		id = "U8",
		name = "Unique Shadow U8 Empty not NEW",
		setup = function(ctx)
			if not lifetime.is_available() then ctx.status = "SKIPPED" return end
			enable_shadow(ctx)
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
		end,
		steps = {
			{ wait = 3, run = function(ctx)
				lifetime.ensure_token(ctx.pickup)
				ctx.token0 = lifetime.get_token(ctx.pickup)
			end },
			{ run = function(ctx)
				empty_collectible_pedestal(ctx.pickup)
			end },
			{ wait_until = function(ctx)
				return ctx.pickup and ctx.pickup:Exists() and (ctx.pickup.SubType or 0) == 0
			end, timeout = 60 },
			{ wait = 5, run = function(ctx)
				snap_row(ctx, nil, ctx.pickup, ctx.token0)
			end },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			expect(ctx, (ctx.observations.subtype or 0) == 0, "empty subtype 0")
			expect(ctx, not gen_is_new(ctx.observations.gen_kind), "not GEN_NEW")
			expect(ctx, gen_is_empty(ctx.observations.gen_kind) or gen_is_same(ctx.observations.gen_kind), "GEN_EMPTY/SAME")
			expect(ctx, ctx.observations.flag_new ~= true, "first_appear false")
		end,
		cleanup = disable_shadow,
	})

	-- U9：Empty restore SAME
	cases[#cases + 1] = u_case({
		id = "U9",
		name = "Unique Shadow U9 Empty restore SAME",
		setup = function(ctx)
			if not lifetime.is_available() then ctx.status = "SKIPPED" return end
			enable_shadow(ctx)
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
		end,
		steps = {
			{ wait = 3, run = function(ctx)
				lifetime.ensure_token(ctx.pickup)
				ctx.token0 = lifetime.get_token(ctx.pickup)
				ctx.gen_id0 = ctx.pickup:GetData()._QingUniqueGeneration and ctx.pickup:GetData()._QingUniqueGeneration.id
			end },
			{ run = function(ctx) empty_collectible_pedestal(ctx.pickup) end },
			{ wait_until = function(ctx)
				return ctx.pickup and ctx.pickup:Exists() and (ctx.pickup.SubType or 0) == 0
			end, timeout = 60 },
			{ wait = 2, run = function(ctx)
				unique.reset_shadow_stats()
				morph_pickup(ctx.pickup, ITEM_A, true)
			end },
			{ wait = 4, run = function(ctx)
				snap_row(ctx, nil, ctx.pickup, ctx.token0)
				observe(ctx, "gen_id_unchanged", ctx.gen_id0 ~= nil and ctx.observations.gen_id == ctx.gen_id0)
			end },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			expect(ctx, gen_is_same(ctx.observations.gen_kind), "GEN_SAME")
			expect(ctx, ctx.observations.flag_new ~= true, "not NEW")
			expect(ctx, ctx.observations.token_same == true, "token unchanged")
		end,
		cleanup = disable_shadow,
	})

	-- U10：Pickup Removal
	cases[#cases + 1] = u_case({
		id = "U10",
		name = "Unique Shadow U10 Pickup Removal",
		setup = function(ctx)
			if not lifetime.is_available() then ctx.status = "SKIPPED" return end
			enable_shadow(ctx)
			ctx.pickup = spawn_collectible(ctx, ITEM_A)
			ctx.before_unresolved = shadow_snap().unresolved or 0
			ctx.before_new = shadow_snap().gen_new or shadow_snap().new_midroom or 0
		end,
		steps = {
			{ wait = 3 },
			{ run = function(ctx)
				local p = ctx.pickup
				local player = player0()
				if p and p:Exists() and player then
					pcall(function()
						player:AnimateCollectible(p.SubType or ITEM_A, "Pickup", "PlayerPickupSparkle")
					end)
					pcall(function()
						p:Remove()
					end)
				end
			end },
			{ wait = 5, run = function(ctx)
				local s = shadow_snap()
				observe(ctx, "unresolved_delta", (s.unresolved or 0) - (ctx.before_unresolved or 0))
				observe(ctx, "gen_new_delta", (s.gen_new or s.new_midroom or 0) - (ctx.before_new or 0))
				observe(ctx, "gone", not (ctx.pickup and ctx.pickup:Exists()))
			end },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			expect(ctx, ctx.observations.gone == true, "pickup removed")
			expect(ctx, (ctx.observations.gen_new_delta or 0) <= 1, "no false NEW after remove")
		end,
		cleanup = disable_shadow,
	})

	-- U11：Options Removal — 存活座不得因兄弟 Remove 而换 generation / 再刷 NEW
	cases[#cases + 1] = u_case({
		id = "U11",
		name = "Unique Shadow U11 Options Removal",
		setup = function(ctx)
			if not lifetime.is_available() then ctx.status = "SKIPPED" return end
			enable_shadow(ctx)
			local c = Game():GetRoom():GetCenterPos()
			ctx.pickup_a = spawn_collectible(ctx, ITEM_A, c + Vector(-40, 0))
			ctx.pickup_b = spawn_collectible(ctx, ITEM_B, c + Vector(40, 0))
			local idx = 1000 + (Game():GetFrameCount() % 1000)
			pcall(function()
				ctx.pickup_a.OptionsPickupIndex = idx
				ctx.pickup_b.OptionsPickupIndex = idx
			end)
			lifetime.ensure_token(ctx.pickup_a)
			lifetime.ensure_token(ctx.pickup_b)
			ctx.token_a = lifetime.get_token(ctx.pickup_a)
			ctx.token_b = lifetime.get_token(ctx.pickup_b)
			local gb = ctx.pickup_b:GetData()._QingUniqueGeneration
			ctx.gen_id_b = gb and gb.id
			ctx.seed_b = ctx.pickup_b.InitSeed
			ctx.before_gen_new = shadow_snap().gen_new or 0
		end,
		steps = {
			{ wait = 4, run = function(ctx)
				observe(ctx, "tok_a", ctx.token_a)
				observe(ctx, "tok_b", ctx.token_b)
				observe(ctx, "distinct", ctx.token_a ~= nil and ctx.token_b ~= nil and ctx.token_a ~= ctx.token_b)
				if ctx.pickup_a and ctx.pickup_a:Exists() then
					pcall(function() ctx.pickup_a:Remove() end)
				end
			end },
			{ wait = 5, run = function(ctx)
				if ctx.pickup_b and ctx.pickup_b:Exists() then
					snap_row(ctx, "b", ctx.pickup_b, ctx.token_b)
					observe(ctx, "b_gen_id_unchanged", ctx.gen_id_b ~= nil and ctx.observations.b_gen_id == ctx.gen_id_b)
					observe(ctx, "b_seed_unchanged", ctx.pickup_b.InitSeed == ctx.seed_b)
					local s = shadow_snap()
					observe(ctx, "gen_new_delta", (s.gen_new or 0) - (ctx.before_gen_new or 0))
				end
				observe(ctx, "b_alive", ctx.pickup_b and ctx.pickup_b:Exists())
			end },
		},
		verify = function(ctx)
			summarize_case_observations(ctx)
			expect(ctx, ctx.observations.distinct == true, "siblings distinct tokens")
			expect(ctx, ctx.observations.b_alive == true, "survivor alive")
			-- marker 出生可为 GEN_NEW 并保持；禁止因 Options Remove 换 id / 再 alloc NEW
			expect(ctx, ctx.observations.b_gen_id_unchanged == true, "survivor generation id unchanged")
			expect(ctx, ctx.observations.b_seed_unchanged == true, "survivor seed unchanged")
			expect(ctx, ctx.observations.b_token_same == true, "survivor token unchanged")
			expect(ctx, (ctx.observations.gen_new_delta or 0) == 0, "no extra GEN_NEW after options remove")
		end,
		cleanup = disable_shadow,
	})

	return cases
end

return M
