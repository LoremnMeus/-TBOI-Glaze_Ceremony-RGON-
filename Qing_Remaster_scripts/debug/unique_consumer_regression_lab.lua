-- Unique Consumer Regression Lab（CR-1～CR-7 + Epoch Smoke）
-- 走真实生产路径；禁止伪造 generation / first_appear / audit.seen。
--
-- Consumer Regression Lab Rules:
-- 1. Never replace missing target with nearest entity (CR-1/CR-4 Room Return).
-- 2. Never mutate tested entity except the action explicitly under test.
-- 3. Never force a consumer callback to make debug counters increase.
-- 4. Identity gate must pass before consumer assertions.
-- 5. Debug counters are observational only (except authoritative first_seen_consumed).
-- 6. Production code must not read lab state.
-- 7. Consumer FAIL cannot justify Unique changes unless matching G-R also fails.
--
-- CR-1：优先 Manual Prepare → 正常出房回房 → Check；Auto 仅作对照。
-- ImGui → Debug → Audit → Unique Consumer Regression

local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local unique = require("Qing_Remaster_scripts.others.Unique_holder")
local gen_audit = require("Qing_Remaster_scripts.others.Generation_audit_holder")
local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")

local EMPRESS_OWNER = "Empress"
local LIVE_OWNER = "LiveBroadcast"
local EMPRESS_OWN = "Thoth_cd3r_Emp_"
local EMPRESS_OWN2 = "Thoth_cd3r_Emp2_"
local FOOL_OWN = "Thoth_cd0r_Foo_"
local HERMIT_OWN = "Thoth_cd9r_Her_"
local SAVE_KEY = "UniqueConsumerRegressionLab"
local ITEM_A = CollectibleType.COLLECTIBLE_BREAKFAST
local ITEM_B = CollectibleType.COLLECTIBLE_LUNCH
local ITEM_C = CollectibleType.COLLECTIBLE_DINNER

local lab = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	own_key = "unique_consumer_regression_lab_",
}

local state = {
	status = "Idle",
	hint = "",
	results = {},
	last_report = "",
	job = nil,
}

local function game_frame()
	local f = 0
	pcall(function()
		f = Game():GetFrameCount()
	end)
	return f
end

local function persist_bag()
	save.elses = save.elses or {}
	save.elses[SAVE_KEY] = save.elses[SAVE_KEY] or {}
	return save.elses[SAVE_KEY]
end

local function set_result(id, row)
	state.results[id] = row
	persist_bag().results = state.results
end

local function require_empress()
	return require("Qing_Remaster_scripts.cards.Card_03r_Empress")
end

local function require_live()
	return require("Qing_Remaster_scripts.items.Item_Live_Broadcast")
end

local function require_fool()
	return require("Qing_Remaster_scripts.cards.Card_00r_Fool")
end

local function require_hermit()
	return require("Qing_Remaster_scripts.cards.Card_09r_Hermit")
end

local function require_perhaps()
	return require("Qing_Remaster_scripts.items.Item_Perhaps_Chosen")
end

local function spawn_collectible(subtype)
	local room = Game():GetRoom()
	local player = Isaac.GetPlayer(0)
	local pos = room:FindFreePickupSpawnPosition(player.Position + Vector(40, 0), 40, true)
	local ent = Isaac.Spawn(
		EntityType.ENTITY_PICKUP,
		PickupVariant.PICKUP_COLLECTIBLE,
		subtype or ITEM_A,
		pos,
		Vector.Zero,
		nil
	)
	local p = ent and (ent:ToPickup() or ent) or nil
	if p then
		p.Wait = 0
		pcall(function()
			p.Price = 0
			p.ShopItemId = -1
		end)
	end
	return p
end

local function find_by_seed(seed)
	if seed == nil then return nil end
	local ok, list = pcall(function()
		return Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, -1, false, false)
	end)
	if not ok or type(list) ~= "table" then return nil end
	for _, ent in ipairs(list) do
		if ent.InitSeed == seed then
			return ent:ToPickup() or ent
		end
	end
	return nil
end

-- 仅允许用于非 Room-Return case；CR-1/CR-4 Room Return 禁止用本函数替代目标。
-- CR-2/5/6/7：D6/Cycle 动作本身允许；禁止无关 remorph / debug counter forcing。
-- CR-3：可构造 Touched，禁止用 debug flag 伪造 retry 结果。
local function nearest_collectible()
	local player = Isaac.GetPlayer(0)
	local best, best_d
	local ok, list = pcall(function()
		return Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, -1, false, false)
	end)
	if not ok or type(list) ~= "table" then return nil end
	for _, ent in ipairs(list) do
		local p = ent:ToPickup() or ent
		if (p.SubType or 0) > 0 then
			local d = player.Position:Distance(p.Position)
			if not best_d or d < best_d then
				best, best_d = p, d
			end
		end
	end
	return best
end

local function gen_of(pickup)
	if not pickup then return nil end
	-- CR 业务就绪用 resolve；勿把 peek nil 当未生成
	return unique.resolve_generation(pickup)
end

local function use_d6()
	local player = Isaac.GetPlayer(0)
	local ok = pcall(function()
		player:UseActiveItem(CollectibleType.COLLECTIBLE_D6, false, true, true, false)
	end)
	return ok == true
end

local function morph_cycle(pickup, subtype)
	if not pickup or not pickup.Morph then return false end
	local ok = pcall(function()
		pickup:Morph(
			EntityType.ENTITY_PICKUP,
			PickupVariant.PICKUP_COLLECTIBLE,
			subtype or ITEM_B,
			true,
			true, -- keepSeed
			true
		)
	end)
	return ok == true
end

local function enable_empress_effect()
	-- 不走 UseCard：避免 RerollLevelCollectibles 污染场景
	save.elses[EMPRESS_OWN .. "effect"] = 5
	if not gen_audit.is_active(EMPRESS_OWNER) then
		gen_audit.begin_epoch(EMPRESS_OWNER)
	end
	return gen_audit.get_epoch(EMPRESS_OWNER)
end

local function clear_empress_on_pedestal(p)
	if not p then return end
	local d = p:GetData()
	d[EMPRESS_OWN .. "effect"] = nil
	d[EMPRESS_OWN .. "shop_stamped"] = nil
	d[EMPRESS_OWN .. "real_shop"] = nil
	d[EMPRESS_OWN .. "shop_id"] = nil
	d[EMPRESS_OWN .. "pending_untouched_retry"] = nil
	pcall(function()
		p.AutoUpdatePrice = true
		p.Price = 0
		p.ShopItemId = -1
	end)
end

local function ensure_live_item()
	local player = Isaac.GetPlayer(0)
	if not player then return nil end
	if player:GetCollectibleNum(enums.Items.Live_Broadcast, true) <= 0 then
		player:AddCollectible(enums.Items.Live_Broadcast, 0, false)
	end
	if not gen_audit.is_active(LIVE_OWNER) then
		gen_audit.begin_epoch(LIVE_OWNER)
	end
	return player
end

local function arm_fool_effect(colid)
	save.elses[FOOL_OWN .. "effect"] = save.elses[FOOL_OWN .. "effect"] or {}
	table.insert(save.elses[FOOL_OWN .. "effect"], { id = colid or ITEM_C })
end

local function arm_hermit_effect(colid)
	save.elses[HERMIT_OWN .. "effect"] = save.elses[HERMIT_OWN .. "effect"] or {}
	-- cnt=1 → 下一次 new generation 立刻吐出
	table.insert(save.elses[HERMIT_OWN .. "effect"], { id = colid or ITEM_C, cnt = 1, Charge = 0 })
end

local function fool_effect_len()
	local t = save.elses[FOOL_OWN .. "effect"]
	return type(t) == "table" and #t or 0
end

local function hermit_effect_len()
	local t = save.elses[HERMIT_OWN .. "effect"]
	return type(t) == "table" and #t or 0
end

local function pass_fail(ok, detail)
	return {
		status = ok and "PASS" or "FAIL",
		detail = detail or "",
		ok = ok == true,
	}
end

local function empress_cr()
	local emp = require_empress()
	if emp.get_debug_cr then return emp.get_debug_cr() end
	return { first_seen_consumed = 0, applied = 0, retry_scheduled = 0, retry_applied = 0 }
end

local function live_cr()
	local live = require_live()
	if live.get_debug_cr then return live.get_debug_cr() end
	return { generation_seen = 0, generation_triggered = 0, generation_skipped_seen = 0 }
end

local function set_job(job)
	state.job = job
	if job then
		state.status = job.label or job.kind or "Running"
		state.hint = job.hint or "等待稳定..."
	end
end

local function finish_job()
	state.job = nil
end

--- 自动离房/回房：找门 → StartRoomTransition（与 Consistance Unique lab 同路径）
local function find_exit_door()
	local room = Game():GetRoom()
	if not room then return nil end
	for i = 0, 7 do
		local d = room:GetDoor(i)
		if d and d.IsOpen and d:IsOpen() then
			return d
		end
	end
	for i = 0, 7 do
		local d = room:GetDoor(i)
		if d then
			return d
		end
	end
	return nil
end

local function start_room_transition(room_index)
	local player = Isaac.GetPlayer(0)
	local ok = pcall(function()
		Game():StartRoomTransition(room_index, Direction.NO_DIRECTION, RoomTransitionAnim.WALK, player)
	end)
	return ok == true
end

local function current_room_index()
	local idx = nil
	pcall(function()
		idx = Game():GetLevel():GetCurrentRoomIndex()
	end)
	return idx
end

local function room_frame()
	local f = 0
	pcall(function()
		f = Game():GetRoom():GetFrameCount()
	end)
	return f
end

-- ---------- CR-1 Empress Room Return ----------
-- Manual Prepare/Check = authoritative；Auto = timing 对照，不得先于 Manual 定罪。

local function snapshot_unique_identity(pickup)
	if not pickup then return nil end
	local gen = unique.resolve_generation(pickup)
	local native = unique.get_native_identity(pickup)
	local reg = select(1, unique.lookup_restore_registry(pickup))
	return {
		seed = pickup.InitSeed,
		subtype = pickup.SubType,
		native_token = native and native.token,
		native_kind = native and native.kind,
		generation_id = gen and gen.id,
		generation_kind = gen and gen.kind,
		generation_source = gen and gen.source,
		registry_generation_id = reg and reg.generation_id,
		original_found = true,
	}
end

local function snapshot_empress_state(p)
	if not p then return nil end
	local d = p.GetData and p:GetData() or nil
	local blind = nil
	if p.IsBlind then
		blind = p:IsBlind() == true
	end
	return {
		effect = d and d[EMPRESS_OWN .. "effect"] == true,
		blind = blind,
		price = p.Price,
		shop_item_id = p.ShopItemId,
		price_catched = price_holder.have_catched_price(p) == true,
		consistance_main = consistance_holder.try_check_entity(p, EMPRESS_OWN) == true,
		consistance_over = consistance_holder.try_check_entity(p, EMPRESS_OWN2) == true,
	}
end

local function snapshot_empress_consumer(pickup)
	local gen = gen_of(pickup)
	local cr = empress_cr()
	local epoch = gen_audit.get_epoch(EMPRESS_OWNER)
	local seen = gen and gen.id and gen_audit.has_seen(EMPRESS_OWNER, gen.id) == true
	return {
		epoch = epoch,
		seen = seen == true,
		first_seen_consumed = cr.first_seen_consumed or 0,
		applied = cr.applied or 0,
		generation_id = gen and gen.id,
		last_source = cr.last_source,
		last_generation_id = cr.last_generation_id,
	}
end

--- Prepare 稳定：有 pickup + generation + epoch + seen + effect + blind；不要求 applied。
local function cr1_prepare_stable(pickup)
	if not pickup then
		return false, nil, "missing_pickup"
	end
	local gen = gen_of(pickup)
	if not (gen and gen.id) then
		return false, gen, "no_generation"
	end
	local epoch = gen_audit.get_epoch(EMPRESS_OWNER)
	if not epoch then
		return false, gen, "no_epoch"
	end
	local seen = gen_audit.has_seen(EMPRESS_OWNER, gen.id) == true
	if not seen then
		return false, gen, "not_seen"
	end
	local st = snapshot_empress_state(pickup)
	if not (st and st.effect == true) then
		return false, gen, "no_effect"
	end
	if st.blind ~= true then
		return false, gen, "not_blind"
	end
	return true, gen, "ok", st
end

local function cr1_capture_before(job, pickup)
	job.seed = pickup.InitSeed
	job.before_identity = snapshot_unique_identity(pickup)
	job.before_consumer = snapshot_empress_consumer(pickup)
	job.before_empress = snapshot_empress_state(pickup)
	job.epoch = job.before_consumer and job.before_consumer.epoch
	job.gen_before = job.before_identity and job.before_identity.generation_id
end

local function cr1_evaluate(job, pickup)
	local before_i = job.before_identity or {}
	local before_c = job.before_consumer or {}
	local before_e = job.before_empress or {}
	local after_i
	local after_c
	local after_e
	local original_found = pickup ~= nil
	if not original_found then
		after_i = {
			original_found = false,
			seed = nil,
			native_token = nil,
			generation_id = nil,
			generation_kind = nil,
			generation_source = nil,
			registry_generation_id = nil,
		}
		after_c = {
			epoch = gen_audit.get_epoch(EMPRESS_OWNER),
			seen = false,
			first_seen_consumed = empress_cr().first_seen_consumed or 0,
			applied = empress_cr().applied or 0,
		}
		after_e = nil
	else
		after_i = snapshot_unique_identity(pickup)
		after_c = snapshot_empress_consumer(pickup)
		after_e = snapshot_empress_state(pickup)
	end

	local result = "PASS"
	local detail = nil

	-- A. Identity Gate
	local identity_ok = original_found
		and after_i.seed == before_i.seed
		and after_i.native_token == before_i.native_token
		and after_i.generation_id == before_i.generation_id
	-- 回房后应为 restore 表达（GEN_RESTORED；GEN_SAME 为项目内可接受的稳定 restored）
	local kind_ok = after_i.generation_kind == "GEN_RESTORED"
		or after_i.generation_kind == "GEN_SAME"
	if after_i.registry_generation_id ~= nil and after_i.generation_id ~= nil then
		identity_ok = identity_ok and (after_i.registry_generation_id == after_i.generation_id)
	end
	identity_ok = identity_ok and kind_ok

	if not identity_ok then
		result = "FAIL_IDENTITY"
		if not original_found then
			detail = "original pedestal missing after room return"
		else
			detail = string.format(
				"seed %s->%s token %s->%s gen %s->%s kind %s->%s reg=%s",
				tostring(before_i.seed),
				tostring(after_i.seed),
				tostring(before_i.native_token),
				tostring(after_i.native_token),
				tostring(before_i.generation_id),
				tostring(after_i.generation_id),
				tostring(before_i.generation_kind),
				tostring(after_i.generation_kind),
				tostring(after_i.registry_generation_id)
			)
		end
	else
		-- B. Consumer Gate（仅 Identity PASS）
		local consumer_ok = after_c.epoch == before_c.epoch
			and before_c.seen == true
			and after_c.seen == true
			and (after_c.first_seen_consumed or 0) == (before_c.first_seen_consumed or 0)
		if not consumer_ok then
			result = "FAIL_CONSUMER"
			detail = string.format(
				"epoch %s->%s seen %s->%s first_seen %s->%s applied(obs) %s->%s",
				tostring(before_c.epoch),
				tostring(after_c.epoch),
				tostring(before_c.seen),
				tostring(after_c.seen),
				tostring(before_c.first_seen_consumed),
				tostring(after_c.first_seen_consumed),
				tostring(before_c.applied),
				tostring(after_c.applied)
			)
		else
			-- C. State（视觉/effect；不挡 Identity/Consumer 解释优先级）
			local state_ok = after_e
				and after_e.effect == true
				and after_e.blind == true
			if not state_ok then
				result = "FAIL_STATE"
				detail = string.format(
					"effect %s->%s blind %s->%s price %s->%s catched %s->%s",
					tostring(before_e.effect),
					tostring(after_e and after_e.effect),
					tostring(before_e.blind),
					tostring(after_e and after_e.blind),
					tostring(before_e.price),
					tostring(after_e and after_e.price),
					tostring(before_e.price_catched),
					tostring(after_e and after_e.price_catched)
				)
			else
				detail = "identity+consumer+state ok"
			end
		end
	end

	local row = {
		status = result,
		detail = detail,
		before_identity = before_i,
		after_identity = after_i,
		before_consumer = before_c,
		after_consumer = after_c,
		before_empress = before_e,
		after_empress = after_e,
		-- flat fields for report
		original_found = original_found,
		seed_before = before_i.seed,
		seed_after = after_i.seed,
		token_before = before_i.native_token,
		token_after = after_i.native_token,
		gen_before = before_i.generation_id,
		gen_after = after_i.generation_id,
		kind_before = before_i.generation_kind,
		kind_after = after_i.generation_kind,
		source_after = after_i.generation_source,
		registry_gen_after = after_i.registry_generation_id,
		epoch_before = before_c.epoch,
		epoch_after = after_c.epoch,
		seen_before = before_c.seen,
		seen_after = after_c.seen,
		first_seen_before = before_c.first_seen_consumed,
		first_seen_after = after_c.first_seen_consumed,
		applied_before = before_c.applied,
		applied_after = after_c.applied,
		effect_before = before_e.effect,
		effect_after = after_e and after_e.effect,
		blind_before = before_e.blind,
		blind_after = after_e and after_e.blind,
		price_before = before_e.price,
		price_after = after_e and after_e.price,
		price_catched_before = before_e.price_catched,
		price_catched_after = after_e and after_e.price_catched,
		consistance_main_before = before_e.consistance_main,
		consistance_main_after = after_e and after_e.consistance_main,
		consistance_over_before = before_e.consistance_over,
		consistance_over_after = after_e and after_e.consistance_over,
	}
	set_result("CR-1", row)
	state.status = result .. " CR-1"
	state.hint = detail or result
	finish_job()
	return row
end

--- Manual：Prepare → 玩家正常出房回房 → Check
function lab.prepare_cr1()
	local emp = require_empress()
	if emp.reset_debug_cr then emp.reset_debug_cr() end
	local epoch = enable_empress_effect()
	local pickup = spawn_collectible(ITEM_A)
	if not pickup then
		set_result("CR-1", { status = "BLOCKED", detail = "spawn failed" })
		state.status = "BLOCKED CR-1"
		state.hint = "spawn failed"
		return
	end
	set_job({
		kind = "cr1",
		mode = "manual",
		label = "CR-1 Prepare",
		hint = "等待 Empress 稳定...（取消暂停）",
		phase = "wait_prepare",
		seed = pickup.InitSeed,
		epoch = epoch,
		home_index = current_room_index(),
		wait = 120,
	})
end

function lab.check_cr1()
	local job = state.job
	if not (job and job.kind == "cr1" and job.before_identity) then
		state.status = "BLOCKED CR-1"
		state.hint = "请先 Prepare CR-1，并等提示离开房间"
		return
	end
	-- 只用原 seed；禁止 nearest fallback
	local pickup = find_by_seed(job.seed)
	cr1_evaluate(job, pickup)
end

--- Auto：离房后等目标房 frame≥20，回 home 后 frame≥12 再 settle
function lab.run_cr1()
	local emp = require_empress()
	if emp.reset_debug_cr then emp.reset_debug_cr() end
	local door = find_exit_door()
	if not door then
		set_result("CR-1", { status = "BLOCKED", detail = "no door for room transition" })
		state.status = "BLOCKED CR-1"
		state.hint = "当前房无门，无法自动离房回房"
		return
	end
	local epoch = enable_empress_effect()
	local pickup = spawn_collectible(ITEM_A)
	if not pickup then
		set_result("CR-1", { status = "BLOCKED", detail = "spawn failed" })
		state.status = "BLOCKED CR-1"
		return
	end
	set_job({
		kind = "cr1",
		mode = "auto",
		label = "CR-1 Auto",
		hint = "等待 Empress 稳定...（取消暂停）",
		phase = "wait_prepare",
		seed = pickup.InitSeed,
		epoch = epoch,
		home_index = current_room_index(),
		target_index = door.TargetRoomIndex,
		wait = 120,
		timeout_left = 360,
		timeout_home = 360,
	})
end

-- ---------- CR-2 Empress D6 ----------

function lab.run_cr2()
	local emp = require_empress()
	if emp.reset_debug_cr then emp.reset_debug_cr() end
	enable_empress_effect()
	local pickup = spawn_collectible(ITEM_A)
	if not pickup then
		set_result("CR-2", pass_fail(false, "spawn failed"))
		state.status = "FAIL CR-2"
		return
	end
	set_job({
		kind = "cr2",
		label = "CR-2 running",
		hint = "等待 A 被 Empress 处理...",
		phase = "wait_a",
		seed = pickup.InitSeed,
		wait = 90,
		applied0 = empress_cr().applied,
	})
end

-- ---------- CR-3 Empress Touched→D6 ----------

function lab.run_cr3()
	local emp = require_empress()
	if emp.reset_debug_cr then emp.reset_debug_cr() end
	enable_empress_effect()
	local pickup = spawn_collectible(ITEM_A)
	if not pickup then
		set_result("CR-3", pass_fail(false, "spawn failed"))
		state.status = "FAIL CR-3"
		return
	end
	-- INIT 可能已套女帝；清掉再设 Touched（与 timeline probe 一致）
	clear_empress_on_pedestal(pickup)
	pickup.Touched = true
	set_job({
		kind = "cr3",
		label = "CR-3 running",
		hint = "确认 Touched 未 apply，再 D6...",
		phase = "confirm_skip",
		seed = pickup.InitSeed,
		wait = 20,
		applied0 = empress_cr().applied,
		retry0 = empress_cr().retry_scheduled,
		retry_applied0 = empress_cr().retry_applied,
	})
end

-- ---------- CR-4 Live Room Return（全自动离房回房）----------

function lab.run_cr4()
	local live = require_live()
	if live.reset_debug_cr then live.reset_debug_cr() end
	local door = find_exit_door()
	if not door then
		set_result("CR-4", pass_fail(false, "no door for room transition"))
		state.status = "FAIL CR-4"
		state.hint = "当前房无门，无法自动离房回房"
		return
	end
	local player = ensure_live_item()
	if not player then
		set_result("CR-4", pass_fail(false, "no player"))
		state.status = "FAIL CR-4"
		return
	end
	-- 先保证 Live epoch 激活，再 spawn（避免 INIT 时 is_active=false 丢 schedule）
	if not gen_audit.is_active(LIVE_OWNER) then
		gen_audit.begin_epoch(LIVE_OWNER)
	end
	local pickup = spawn_collectible(ITEM_A)
	if not pickup then
		set_result("CR-4", pass_fail(false, "spawn failed"))
		state.status = "FAIL CR-4"
		return
	end
	-- INIT 可能早于 epoch/Unique；显式补一次 schedule
	if live.debug_schedule_generation_audit then
		live.debug_schedule_generation_audit(pickup, player, "cr4_spawn")
	end
	set_job({
		kind = "cr4",
		label = "CR-4 running",
		hint = "等待 Live first-seen...（请取消暂停）",
		phase = "wait_apply",
		seed = pickup.InitSeed,
		epoch = gen_audit.get_epoch(LIVE_OWNER),
		home_index = current_room_index(),
		target_index = door.TargetRoomIndex,
		wait = 120,
		timeout_left = 360,
		timeout_home = 360,
		seen0 = live_cr().generation_seen,
		kick_left = 1,
	})
end

function lab.prepare_cr4()
	lab.run_cr4()
end

function lab.check_cr4()
	state.status = "CR-4 is fully automatic"
	state.hint = "请用 Run CR-4；已不再需要手动 Check。"
end

-- ---------- CR-5 Live D6 ----------

function lab.run_cr5()
	local live = require_live()
	if live.reset_debug_cr then live.reset_debug_cr() end
	ensure_live_item()
	local pickup = spawn_collectible(ITEM_A)
	if not pickup then
		set_result("CR-5", pass_fail(false, "spawn failed"))
		state.status = "FAIL CR-5"
		return
	end
	set_job({
		kind = "cr5",
		label = "CR-5 running",
		hint = "等待 A Live first-seen...",
		phase = "wait_a",
		seed = pickup.InitSeed,
		wait = 45,
		seen0 = live_cr().generation_seen,
	})
end

-- ---------- CR-6 Fool / Hermit ----------

function lab.run_cr6()
	local fool = require_fool()
	local hermit = require_hermit()
	if fool.reset_debug_cr then fool.reset_debug_cr() end
	if hermit.reset_debug_cr then hermit.reset_debug_cr() end
	save.elses[FOOL_OWN .. "effect"] = {}
	save.elses[HERMIT_OWN .. "effect"] = {}
	arm_fool_effect(ITEM_C)
	arm_hermit_effect(ITEM_C)
	local pickup = spawn_collectible(ITEM_A)
	if not pickup then
		set_result("CR-6", pass_fail(false, "spawn failed"))
		state.status = "FAIL CR-6"
		return
	end
	set_job({
		kind = "cr6",
		label = "CR-6 running",
		hint = "Fool/Hermit baseline...",
		phase = "baseline",
		seed = pickup.InitSeed,
		wait = 60,
		fool_trig0 = fool.get_debug_cr and fool.get_debug_cr().triggered_new_generation or 0,
		hermit_trig0 = hermit.get_debug_cr and hermit.get_debug_cr().triggered_new_generation or 0,
		sub = {},
	})
end

-- ---------- CR-7 Perhaps ----------

function lab.run_cr7()
	local perhaps = require_perhaps()
	if perhaps.reset_debug_audit then perhaps.reset_debug_audit() end
	if perhaps.debug_remove_active_carriers then
		perhaps.debug_remove_active_carriers(true)
	end
	if perhaps.debug_clear_pending then
		perhaps.debug_clear_pending()
	end
	local player = Isaac.GetPlayer(0)
	if player and player:GetCollectibleNum(enums.Items.Perhaps_Chosen, true) <= 0 then
		player:AddCollectible(enums.Items.Perhaps_Chosen, 0, false)
	end
	if perhaps.set_pending_count then
		perhaps.set_pending_count(1)
	end
	local pickup = spawn_collectible(ITEM_A)
	if not pickup then
		set_result("CR-7", pass_fail(false, "spawn failed"))
		state.status = "FAIL CR-7"
		return
	end
	set_job({
		kind = "cr7",
		label = "CR-7 running",
		hint = "等待 Perhaps host claim...",
		phase = "wait_host",
		seed = pickup.InitSeed,
		wait = 60,
		new0 = perhaps.debug_audit and perhaps.debug_audit.new_host_hits or 0,
		same0 = perhaps.debug_audit and perhaps.debug_audit.same_generation_blocks or 0,
		sub = {},
	})
end

-- ---------- Epoch Smoke ----------

function lab.run_epoch_smoke()
	local emp = require_empress()
	local live = require_live()
	if emp.reset_debug_cr then emp.reset_debug_cr() end
	if live.reset_debug_cr then live.reset_debug_cr() end
	enable_empress_effect()
	ensure_live_item()
	local pickup = spawn_collectible(ITEM_A)
	if not pickup then
		set_result("Epoch", pass_fail(false, "spawn failed"))
		state.status = "FAIL Epoch"
		return
	end
	set_job({
		kind = "epoch",
		label = "Epoch Smoke",
		hint = "epoch1 first-seen...",
		phase = "epoch1",
		seed = pickup.InitSeed,
		wait = 45,
		emp0 = empress_cr().applied,
		live0 = live_cr().generation_seen,
	})
end

-- ---------- Job tick ----------

local function empress_pedestal_flagged(pickup)
	if not pickup or not pickup.GetData then return false end
	local d = pickup:GetData()
	return d and d[EMPRESS_OWN .. "effect"] == true
end

--- 无 remorph / 无 applied 门槛。CR-2 等也复用。
local function empress_ready_on_pedestal(pickup, job)
	local ok, gen, reason = cr1_prepare_stable(pickup)
	local seen = gen and gen.id and gen_audit.has_seen(EMPRESS_OWNER, gen.id) == true
	local flagged = empress_pedestal_flagged(pickup)
	return ok, gen, seen, flagged, reason
end

local function tick_cr1(job)
	if job.phase == "wait_prepare" then
		local pickup = find_by_seed(job.seed)
		local ready, gen, seen, flagged, reason = empress_ready_on_pedestal(pickup, job)
		local cr = empress_cr()
		local st = pickup and snapshot_empress_state(pickup)
		state.hint = string.format(
			"wait_prepare gen=%s seen=%s effect=%s blind=%s first_seen=%s applied(obs)=%s reason=%s",
			tostring(gen and gen.id),
			tostring(seen),
			tostring(st and st.effect),
			tostring(st and st.blind),
			tostring(cr.first_seen_consumed),
			tostring(cr.applied),
			tostring(reason)
		)
		if ready then
			cr1_capture_before(job, pickup)
			if job.mode == "manual" then
				job.phase = "await_manual_return"
				state.status = "PREPARED CR-1"
				state.hint = "Leave room normally, stay briefly, return, then press Check CR-1."
				-- 保留 job（含 before snapshot）；不 finish
				return
			end
			job.phase = "leave"
			state.hint = "自动离房...（请取消暂停）"
			return
		end
		if job._from_render then
			return
		end
		job.wait = (job.wait or 0) - 1
		if job.wait <= 0 then
			set_result("CR-1", {
				status = "BLOCKED",
				detail = "timeout waiting Empress stable: " .. tostring(state.hint),
			})
			state.status = "BLOCKED CR-1"
			finish_job()
		end
		return
	end
	if job.phase == "await_manual_return" then
		-- Manual：不自动离房；Check 按钮触发 evaluate
		state.hint = "Leave room normally, stay briefly, return, then press Check CR-1."
		return
	end
	if Game().IsPaused and Game():IsPaused() then
		state.hint = (job.phase or "?") .. " — 游戏暂停中，取消暂停以继续离房/回房"
		return
	end
	if job.phase == "leave" then
		start_room_transition(job.target_index)
		job.phase = "wait_left"
		state.hint = "等待离开本房..."
		return
	end
	if job.phase == "wait_left" then
		if current_room_index() ~= job.home_index then
			job.phase = "wait_away_settle"
			job.away_need_frame = 20
			state.hint = "已离房，等待目标房 settle (frame>=20)..."
			return
		end
		job.timeout_left = (job.timeout_left or 0) - 1
		if job.timeout_left <= 0 then
			set_result("CR-1", { status = "BLOCKED", detail = "timeout leaving room" })
			state.status = "BLOCKED CR-1"
			finish_job()
		end
		return
	end
	if job.phase == "wait_away_settle" then
		if room_frame() >= (job.away_need_frame or 20) then
			job.phase = "return_home"
			state.hint = "目标房已 settle，回房..."
			return
		end
		job.timeout_left = (job.timeout_left or 0) - 1
		if job.timeout_left <= 0 then
			set_result("CR-1", { status = "BLOCKED", detail = "timeout away-room settle" })
			state.status = "BLOCKED CR-1"
			finish_job()
		end
		return
	end
	if job.phase == "return_home" then
		start_room_transition(job.home_index)
		job.phase = "wait_home"
		state.hint = "等待回房 restore..."
		return
	end
	if job.phase == "wait_home" then
		if current_room_index() == job.home_index and room_frame() >= 12 then
			job.phase = "settle"
			job.wait = 15
			state.hint = "回房 settle..."
			return
		end
		job.timeout_home = (job.timeout_home or 0) - 1
		if job.timeout_home <= 0 then
			set_result("CR-1", { status = "BLOCKED", detail = "timeout returning home" })
			state.status = "BLOCKED CR-1"
			finish_job()
		end
		return
	end
	if job.phase == "settle" then
		job.wait = (job.wait or 0) - 1
		if job.wait > 0 then return end
		-- 禁止 nearest fallback
		local pickup = find_by_seed(job.seed)
		cr1_evaluate(job, pickup)
	end
end

local function tick_cr2(job)
	local pickup = find_by_seed(job.seed) or nearest_collectible()
	local gen = gen_of(pickup)
	local cr = empress_cr()
	if job.phase == "wait_a" then
		local ready, g2, seen = empress_ready_on_pedestal(pickup, job)
		gen = g2 or gen
		state.hint = string.format(
			"CR-2 wait_a gen=%s seen=%s applied=%s",
			tostring(gen and gen.id),
			tostring(seen),
			tostring(cr.applied)
		)
		if ready then
			job.genA = gen.id
			job.applied_before = cr.applied
			job.seed = pickup.InitSeed
			if job._from_render then
				state.hint = "CR-2 ready — 取消暂停以继续 D6"
				return
			end
			use_d6()
			job.phase = "wait_b"
			job.wait = 60
			job.hint = "D6 后等待 generation B..."
			state.hint = job.hint
			return
		end
	elseif job.phase == "wait_b" then
		pickup = find_by_seed(job.seed) or nearest_collectible()
		gen = gen_of(pickup)
		cr = empress_cr()
		if gen and gen.id and gen.id ~= job.genA then
			local seenA = gen_audit.has_seen(EMPRESS_OWNER, job.genA) == true
			local seenB = gen_audit.has_seen(EMPRESS_OWNER, gen.id) == true
			local flaggedB = empress_pedestal_flagged(pickup)
			-- D6 新 gen：允许 Morph apply_question 或 INIT/flag；delta 可为 0 若仅 flag
			local delta = (cr.applied or 0) - (job.applied_before or 0)
			local ok = seenA and (seenB or flaggedB) and (delta >= 1 or flaggedB)
			local detail = string.format(
				"genA=%s genB=%s applied_delta=%s seenA=%s seenB=%s flaggedB=%s",
				tostring(job.genA),
				tostring(gen.id),
				tostring(delta),
				tostring(seenA),
				tostring(seenB),
				tostring(flaggedB)
			)
			local row = pass_fail(ok, detail)
			row.genA = job.genA
			row.genB = gen.id
			row.applied_delta = delta
			set_result("CR-2", row)
			state.status = row.status .. " CR-2"
			state.hint = detail
			finish_job()
			return
		end
	end
	if job._from_render then
		return
	end
	job.wait = (job.wait or 0) - 1
	if job.wait <= 0 then
		set_result("CR-2", pass_fail(false, "timeout phase=" .. tostring(job.phase) .. " " .. tostring(state.hint)))
		state.status = "FAIL CR-2"
		finish_job()
	end
end

local function tick_cr3(job)
	local pickup = find_by_seed(job.seed) or nearest_collectible()
	local gen = gen_of(pickup)
	local cr = empress_cr()
	if job.phase == "confirm_skip" then
		-- 等几帧确认 Touched 路径未 apply
		if (job.wait or 0) > 10 then
			job.wait = job.wait - 1
			return
		end
		local applied_bump = (cr.applied or 0) > (job.applied0 or 0)
		if applied_bump then
			-- 可能 INIT 抢跑；再清一次并保持 Touched
			clear_empress_on_pedestal(pickup)
			pickup.Touched = true
			job.applied0 = cr.applied
			job.wait = 15
			return
		end
		job.genA = gen and gen.id
		job.seed = pickup and pickup.InitSeed or job.seed
		job.morph_touched = pickup and pickup.Touched == true
		use_d6()
		job.phase = "wait_retry"
		job.wait = 90
		job.hint = "等待 Touched 清零 + retry apply..."
		state.hint = job.hint
		return
	elseif job.phase == "wait_retry" then
		-- D6 可能改 InitSeed：先 seed，再 nearest（本 case 单底座）
		pickup = find_by_seed(job.seed) or nearest_collectible()
		gen = gen_of(pickup)
		cr = empress_cr()
		local stable = pickup and pickup.Touched == false
		local genB = gen and gen.id
		local retry_sched = (cr.retry_scheduled or 0) - (job.retry0 or 0)
		local retry_app = (cr.retry_applied or 0) - (job.retry_applied0 or 0)
		local delta = (cr.applied or 0) - (job.applied0 or 0)
		local flagged = empress_pedestal_flagged(pickup)
		-- 权威：Touched Morph 排了 retry；引擎清 Touched 后 retry 真正 apply；generation 已换。
		-- applied 总量只 OBSERVE：D6 可能多次 Morph/sweep，不得要求 delta==1。
		if genB and job.genA and genB ~= job.genA and stable and retry_sched >= 1 and retry_app >= 1 then
			local ok = flagged == true
			local detail = string.format(
				"genA=%s genB=%s morph_touched=%s touched_after=%s retry_sched=%s retry_app=%s applied_delta(obs)=%s flagged=%s",
				tostring(job.genA),
				tostring(genB),
				tostring(job.morph_touched),
				tostring(pickup.Touched),
				tostring(retry_sched),
				tostring(retry_app),
				tostring(delta),
				tostring(flagged)
			)
			local row = pass_fail(ok, detail)
			row.genA = job.genA
			row.genB = genB
			row.morph_touched = job.morph_touched
			row.stable_touched = stable
			row.retry_scheduled = retry_sched
			row.retry_applied = retry_app
			row.applied_delta = delta
			row.flagged = flagged
			set_result("CR-3", row)
			state.status = row.status .. " CR-3"
			state.hint = detail
			finish_job()
			return
		end
	end
	if job._from_render then
		return
	end
	job.wait = (job.wait or 0) - 1
	if job.wait <= 0 then
		local pickup2 = find_by_seed(job.seed) or nearest_collectible()
		local gen2 = gen_of(pickup2)
		local cr2 = empress_cr()
		local detail = string.format(
			"timeout phase=%s genA=%s genB=%s touched=%s retry_sched=%s retry_app=%s applied(obs)=%s",
			tostring(job.phase),
			tostring(job.genA),
			tostring(gen2 and gen2.id),
			tostring(pickup2 and pickup2.Touched),
			tostring((cr2.retry_scheduled or 0) - (job.retry0 or 0)),
			tostring((cr2.retry_applied or 0) - (job.retry_applied0 or 0)),
			tostring((cr2.applied or 0) - (job.applied0 or 0))
		)
		set_result("CR-3", pass_fail(false, detail))
		state.status = "FAIL CR-3"
		state.hint = detail
		finish_job()
	end
end

local function finish_cr4(job, pickup)
	local before_i = job.before_identity or {}
	local before_c = job.before_consumer or {}
	if not pickup then
		local row = {
			status = "FAIL_IDENTITY",
			detail = "original pedestal missing after room return",
			original_found = false,
			gen_before = before_i.generation_id or job.gen_before,
			gen_after = nil,
			epoch_before = before_c.epoch or job.epoch,
			epoch_after = gen_audit.get_epoch(LIVE_OWNER),
			trigger_before = before_c.trigger or job.trigger_before,
			trigger_after = live_cr().generation_seen,
		}
		set_result("CR-4", row)
		state.status = "FAIL_IDENTITY CR-4"
		state.hint = row.detail
		finish_job()
		return
	end
	local after_i = snapshot_unique_identity(pickup)
	local cr = live_cr()
	local epoch = gen_audit.get_epoch(LIVE_OWNER)
	local seen = after_i and after_i.generation_id
		and gen_audit.has_seen(LIVE_OWNER, after_i.generation_id) == true
	local after_c = {
		epoch = epoch,
		seen = seen == true,
		trigger = cr.generation_seen or 0,
		generation_id = after_i and after_i.generation_id,
	}

	local identity_ok = after_i
		and after_i.seed == before_i.seed
		and after_i.generation_id == before_i.generation_id
		and (
			after_i.generation_kind == "GEN_RESTORED"
			or after_i.generation_kind == "GEN_SAME"
			or after_i.generation_kind == before_i.generation_kind
		)

	local result = "PASS"
	local detail
	if not identity_ok then
		result = "FAIL_IDENTITY"
		detail = string.format(
			"seed %s->%s gen %s->%s kind %s->%s",
			tostring(before_i.seed),
			tostring(after_i and after_i.seed),
			tostring(before_i.generation_id),
			tostring(after_i and after_i.generation_id),
			tostring(before_i.generation_kind),
			tostring(after_i and after_i.generation_kind)
		)
	else
		-- Consumer：同 epoch + 目标 gen 仍 seen。
		-- generation_seen 全局计数只 OBSERVE：回房 INIT 会扫到房内其他底座。
		local consumer_ok = after_c.epoch == before_c.epoch
			and before_c.seen == true
			and after_c.seen == true
			and after_c.generation_id == before_c.generation_id
		if not consumer_ok then
			result = "FAIL_CONSUMER"
			detail = string.format(
				"epoch %s->%s seen %s->%s gen %s->%s trigger(obs) %s->%s",
				tostring(before_c.epoch),
				tostring(after_c.epoch),
				tostring(before_c.seen),
				tostring(after_c.seen),
				tostring(before_c.generation_id),
				tostring(after_c.generation_id),
				tostring(before_c.trigger),
				tostring(after_c.trigger)
			)
		else
			detail = string.format(
				"identity+consumer ok trigger(obs) %s->%s",
				tostring(before_c.trigger),
				tostring(after_c.trigger)
			)
		end
	end

	local row = {
		status = result,
		detail = detail,
		original_found = true,
		gen_before = before_i.generation_id,
		gen_after = after_i and after_i.generation_id,
		kind_before = before_i.generation_kind,
		kind_after = after_i and after_i.generation_kind,
		epoch = after_c.epoch,
		epoch_before = before_c.epoch,
		epoch_after = after_c.epoch,
		trigger_before = before_c.trigger,
		trigger_after = after_c.trigger,
		seen_before = before_c.seen,
		seen_after = after_c.seen,
	}
	set_result("CR-4", row)
	state.status = result .. " CR-4"
	state.hint = detail
	finish_job()
end

local function tick_cr4(job)
	if job.phase == "wait_apply" then
		local pickup = find_by_seed(job.seed)
		local gen = gen_of(pickup)
		local cr = live_cr()
		local active = gen_audit.is_active(LIVE_OWNER) == true
		local seen = gen and gen.id and gen_audit.has_seen(LIVE_OWNER, gen.id) == true
		-- 权威：audit has_seen；generation_seen 只 OBSERVE（暂停时 delay 不跑会假超时）
		state.hint = string.format(
			"wait_apply gen=%s seen=%s active=%s trigger=%s（取消暂停）",
			tostring(gen and gen.id),
			tostring(seen),
			tostring(active),
			tostring(cr.generation_seen)
		)
		if gen and gen.id and active and seen then
			job.before_identity = snapshot_unique_identity(pickup)
			job.before_consumer = {
				epoch = gen_audit.get_epoch(LIVE_OWNER),
				seen = true,
				trigger = cr.generation_seen or 0,
				generation_id = gen.id,
			}
			job.gen_before = gen.id
			job.trigger_before = cr.generation_seen
			job.epoch = job.before_consumer.epoch
			job.seed = pickup.InitSeed
			job.phase = "leave"
			state.hint = "自动离房..."
			return
		end
		-- 仍未 seen：再 kick 一次 schedule（仅一次）
		if pickup and active and (job.kick_left or 0) > 0 and not job._from_render then
			local live = require_live()
			if live.debug_schedule_generation_audit then
				live.debug_schedule_generation_audit(pickup, Isaac.GetPlayer(0), "cr4_retry_kick")
			end
			job.kick_left = job.kick_left - 1
		end
		if job._from_render then
			return
		end
		job.wait = (job.wait or 0) - 1
		if job.wait <= 0 then
			set_result("CR-4", pass_fail(false, string.format(
				"timeout waiting Live first-seen gen=%s seen=%s active=%s trigger=%s",
				tostring(gen and gen.id),
				tostring(seen),
				tostring(active),
				tostring(cr.generation_seen)
			)))
			state.status = "FAIL CR-4"
			finish_job()
		end
		return
	end
	if Game().IsPaused and Game():IsPaused() then
		state.hint = (job.phase or "?") .. " — 取消暂停以继续离房/回房"
		return
	end
	if job.phase == "leave" then
		start_room_transition(job.target_index)
		job.phase = "wait_left"
		state.hint = "等待离开本房..."
		return
	end
	if job.phase == "wait_left" then
		if current_room_index() ~= job.home_index then
			job.phase = "wait_away_settle"
			job.away_need_frame = 20
			state.hint = "已离房，等待目标房 settle..."
			return
		end
		job.timeout_left = (job.timeout_left or 0) - 1
		if job.timeout_left <= 0 then
			set_result("CR-4", pass_fail(false, "timeout leaving room"))
			state.status = "FAIL CR-4"
			finish_job()
		end
		return
	end
	if job.phase == "wait_away_settle" then
		if room_frame() >= (job.away_need_frame or 20) then
			job.phase = "return_home"
			state.hint = "目标房已 settle，回房..."
			return
		end
		job.timeout_left = (job.timeout_left or 0) - 1
		if job.timeout_left <= 0 then
			set_result("CR-4", pass_fail(false, "timeout away-room settle"))
			state.status = "FAIL CR-4"
			finish_job()
		end
		return
	end
	if job.phase == "return_home" then
		start_room_transition(job.home_index)
		job.phase = "wait_home"
		state.hint = "等待回房 restore..."
		return
	end
	if job.phase == "wait_home" then
		if current_room_index() == job.home_index and room_frame() >= 12 then
			job.phase = "settle"
			job.wait = 15
			state.hint = "回房 settle..."
			return
		end
		job.timeout_home = (job.timeout_home or 0) - 1
		if job.timeout_home <= 0 then
			set_result("CR-4", pass_fail(false, "timeout returning home"))
			state.status = "FAIL CR-4"
			finish_job()
		end
		return
	end
	if job.phase == "settle" then
		job.wait = (job.wait or 0) - 1
		if job.wait > 0 then return end
		local pickup = find_by_seed(job.seed)
		finish_cr4(job, pickup)
	end
end

local function tick_cr5(job)
	local pickup = find_by_seed(job.seed) or nearest_collectible()
	local gen = gen_of(pickup)
	local cr = live_cr()
	if job.phase == "wait_a" then
		local seen = gen and gen_audit.has_seen(LIVE_OWNER, gen.id) == true
		if gen and gen.id and seen and (cr.generation_seen or 0) > (job.seen0 or 0) then
			job.genA = gen.id
			job.countA = cr.generation_seen
			job.seed = pickup.InitSeed
			use_d6()
			job.phase = "wait_b"
			job.wait = 60
			state.hint = "D6 后等待 Live B..."
			return
		end
	elseif job.phase == "wait_b" then
		pickup = find_by_seed(job.seed) or nearest_collectible()
		gen = gen_of(pickup)
		cr = live_cr()
		if gen and gen.id and gen.id ~= job.genA then
			local seenA = gen_audit.has_seen(LIVE_OWNER, job.genA) == true
			local seenB = gen_audit.has_seen(LIVE_OWNER, gen.id) == true
			local delta = (cr.generation_seen or 0) - (job.countA or 0)
			local ok = seenA and seenB and delta >= 1
			local detail = string.format(
				"genA=%s genB=%s trigger_delta=%s seenA=%s seenB=%s",
				tostring(job.genA),
				tostring(gen.id),
				tostring(delta),
				tostring(seenA),
				tostring(seenB)
			)
			local row = pass_fail(ok, detail)
			row.genA = job.genA
			row.genB = gen.id
			row.trigger_delta = delta
			set_result("CR-5", row)
			state.status = row.status .. " CR-5"
			state.hint = detail
			finish_job()
			return
		end
	end
	job.wait = (job.wait or 0) - 1
	if job.wait <= 0 then
		set_result("CR-5", pass_fail(false, "timeout phase=" .. tostring(job.phase)))
		state.status = "FAIL CR-5"
		finish_job()
	end
end

local function tick_cr6(job)
	local fool = require_fool()
	local hermit = require_hermit()
	local pickup = find_by_seed(job.seed) or nearest_collectible()
	local gen = gen_of(pickup)
	local fcr = fool.get_debug_cr and fool.get_debug_cr() or {}
	local hcr = hermit.get_debug_cr and hermit.get_debug_cr() or {}
	if job.phase == "baseline" then
		local f_ok = (fcr.triggered_new_generation or 0) > (job.fool_trig0 or 0)
		local h_ok = (hcr.triggered_new_generation or 0) > (job.hermit_trig0 or 0)
		-- Hermit FrameCount==1 / Fool ==2；允许只等到至少一个已触发且 gen 就绪后再齐
		if gen and gen.id and f_ok and h_ok then
			job.genA = gen.id
			job.sub.fool_base = true
			job.sub.hermit_base = true
			job.fool_trig1 = fcr.triggered_new_generation
			job.hermit_trig1 = hcr.triggered_new_generation
			job.fool_ign0 = fcr.ignored_same_generation or 0
			job.hermit_ign0 = hcr.ignored_same_generation or 0
			arm_fool_effect(ITEM_C)
			arm_hermit_effect(ITEM_C)
			morph_cycle(pickup, ITEM_B)
			job.phase = "cycle"
			job.wait = 60
			state.hint = "Cycle：同 generation 不得再触发..."
			return
		end
	elseif job.phase == "cycle" then
		pickup = find_by_seed(job.seed) or nearest_collectible()
		gen = gen_of(pickup)
		fcr = fool.get_debug_cr and fool.get_debug_cr() or {}
		hcr = hermit.get_debug_cr and hermit.get_debug_cr() or {}
		if gen and gen.id and (job.wait or 0) < 45 then
			-- 给 FrameCount 复位后至少一轮 UPDATE
			local same = gen.id == job.genA
			local fool_cycle = same
				and (fcr.triggered_new_generation or 0) == (job.fool_trig1 or 0)
				and ((fcr.ignored_same_generation or 0) > (job.fool_ign0 or 0) or fool_effect_len() > 0)
			local hermit_cycle = same
				and (hcr.triggered_new_generation or 0) == (job.hermit_trig1 or 0)
				and ((hcr.ignored_same_generation or 0) > (job.hermit_ign0 or 0) or hermit_effect_len() > 0)
			job.sub.fool_cycle = fool_cycle
			job.sub.hermit_cycle = hermit_cycle
			job.gen_cycle = gen.id
			-- 准备 D6 段
			if fool.reset_debug_cr then fool.reset_debug_cr() end
			if hermit.reset_debug_cr then hermit.reset_debug_cr() end
			save.elses[FOOL_OWN .. "effect"] = {}
			save.elses[HERMIT_OWN .. "effect"] = {}
			arm_fool_effect(ITEM_C)
			arm_hermit_effect(ITEM_C)
			job.seed = pickup.InitSeed
			job.genC = gen.id
			use_d6()
			job.phase = "d6"
			job.wait = 60
			state.hint = "D6：新 generation 应触发..."
			return
		end
	elseif job.phase == "d6" then
		pickup = find_by_seed(job.seed) or nearest_collectible()
		gen = gen_of(pickup)
		fcr = fool.get_debug_cr and fool.get_debug_cr() or {}
		hcr = hermit.get_debug_cr and hermit.get_debug_cr() or {}
		if gen and gen.id and gen.id ~= job.genC then
			job.genD = gen.id
			-- Fool 只在 FrameCount==2 触发；Hermit 在 ==1。gen 一变就结算会漏 Fool。
			local fc = pickup.FrameCount or 0
			job.d6_settle = (job.d6_settle or 0) + 1
			if fc < 2 and (job.d6_settle or 0) < 15 then
				state.hint = string.format("D6 settle FrameCount=%s fool_trig=%s...", tostring(fc), tostring(fcr.triggered_new_generation))
				return
			end
			local fool_d6 = (fcr.triggered_new_generation or 0) >= 1
			local hermit_d6 = (hcr.triggered_new_generation or 0) >= 1
			job.sub.fool_d6 = fool_d6
			job.sub.hermit_d6 = hermit_d6
			local ok = job.sub.fool_cycle and job.sub.hermit_cycle and fool_d6 and hermit_d6
			local detail = string.format(
				"Fool Cycle=%s Fool D6=%s Hermit Cycle=%s Hermit D6=%s genA=%s genCycle=%s genC=%s genD=%s fc=%s",
				tostring(job.sub.fool_cycle),
				tostring(fool_d6),
				tostring(job.sub.hermit_cycle),
				tostring(hermit_d6),
				tostring(job.genA),
				tostring(job.gen_cycle),
				tostring(job.genC),
				tostring(job.genD),
				tostring(fc)
			)
			local row = pass_fail(ok, detail)
			row.fool_cycle = job.sub.fool_cycle
			row.fool_d6 = fool_d6
			row.hermit_cycle = job.sub.hermit_cycle
			row.hermit_d6 = hermit_d6
			set_result("CR-6", row)
			state.status = row.status .. " CR-6"
			state.hint = detail
			finish_job()
			return
		end
	end
	job.wait = (job.wait or 0) - 1
	if job.wait <= 0 then
		set_result("CR-6", pass_fail(false, "timeout phase=" .. tostring(job.phase) .. " sub=" .. tostring(job.sub and job.sub.fool_cycle)))
		state.status = "FAIL CR-6"
		finish_job()
	end
end

local function tick_cr7(job)
	local perhaps = require_perhaps()
	local pickup = find_by_seed(job.seed) or nearest_collectible()
	local gen = gen_of(pickup)
	local da = perhaps.debug_audit or {}
	if job.phase == "wait_host" then
		if gen and gen.id and (da.new_host_hits or 0) > (job.new0 or 0) then
			job.genA = gen.id
			job.new1 = da.new_host_hits
			job.same1 = da.same_generation_blocks or 0
			job.seed = pickup.InitSeed
			morph_cycle(pickup, ITEM_B)
			job.phase = "cycle"
			job.wait = 45
			state.hint = "Cycle：same host..."
			return
		end
	elseif job.phase == "cycle" then
		pickup = find_by_seed(job.seed) or nearest_collectible()
		gen = gen_of(pickup)
		da = perhaps.debug_audit or {}
		if gen and gen.id and (job.wait or 0) < 30 then
			local same_host = gen.id == job.genA
			local no_new = (da.new_host_hits or 0) == (job.new1 or 0)
			job.sub.cycle_same = same_host and no_new
			job.gen_cycle = gen.id
			job.new2 = da.new_host_hits or 0
			-- D6 新 host：清掉本房已 attach，再补一条 pending（否则 should_skip_attach）
			if perhaps.debug_remove_active_carriers then
				perhaps.debug_remove_active_carriers(true)
			end
			if perhaps.set_pending_count then
				perhaps.set_pending_count(1)
			end
			job.seed = pickup.InitSeed
			use_d6()
			job.phase = "d6"
			job.wait = 60
			state.hint = "D6：new host..."
			return
		end
	elseif job.phase == "d6" then
		pickup = find_by_seed(job.seed) or nearest_collectible()
		gen = gen_of(pickup)
		da = perhaps.debug_audit or {}
		if gen and gen.id and gen.id ~= job.genA then
			job.genB = gen.id
			job.d6_settle = (job.d6_settle or 0) + 1
			-- 等 attach / is_newly_generated 跑几帧
			if (job.d6_settle or 0) < 8 then
				state.hint = string.format("D6 settle genB=%s new_hits=%s...", tostring(gen.id), tostring(da.new_host_hits))
				return
			end
			local new_host = (da.new_host_hits or 0) > (job.new2 or 0)
				or unique.is_fresh_generation(pickup)
			-- 权威：新 generation 且本房 fresh（不依赖 kind 仍为 GEN_NEW）
			local ok = job.sub.cycle_same == true
				and gen.id ~= job.genA
				and unique.is_fresh_generation(pickup)
			job.sub.d6_new = new_host
			local detail = string.format(
				"Cycle same host=%s D6 fresh=%s kind=%s new_host(obs)=%s genA=%s genCycle=%s genB=%s birth=%s room_epoch=%s new_hits=%s->%s->%s",
				tostring(job.sub.cycle_same),
				tostring(unique.is_fresh_generation(pickup)),
				tostring(gen.kind),
				tostring(new_host),
				tostring(job.genA),
				tostring(job.gen_cycle),
				tostring(gen.id),
				tostring(gen.birth_room_epoch),
				tostring(unique.get_room_generation_epoch and unique.get_room_generation_epoch()),
				tostring(job.new0),
				tostring(job.new1),
				tostring(da.new_host_hits)
			)
			local row = pass_fail(ok, detail)
			row.cycle_same_host = job.sub.cycle_same
			row.d6_new_host = ok
			set_result("CR-7", row)
			state.status = row.status .. " CR-7"
			state.hint = detail
			finish_job()
			return
		end
	end
	job.wait = (job.wait or 0) - 1
	if job.wait <= 0 then
		set_result("CR-7", pass_fail(false, "timeout phase=" .. tostring(job.phase)))
		state.status = "FAIL CR-7"
		finish_job()
	end
end

local function tick_epoch(job)
	local pickup = find_by_seed(job.seed) or nearest_collectible()
	local gen = gen_of(pickup)
	local cr_e = empress_cr()
	local cr_l = live_cr()
	if job.phase == "epoch1" then
		local e_ok = gen and gen_audit.has_seen(EMPRESS_OWNER, gen.id) and (cr_e.applied or 0) > (job.emp0 or 0)
		local l_ok = gen and gen_audit.has_seen(LIVE_OWNER, gen.id) and (cr_l.generation_seen or 0) > (job.live0 or 0)
		if e_ok and l_ok then
			job.genA = gen.id
			-- 结束并重开 epoch（Live 用 remove+add 触发真实 begin_live 扫房）
			if gen_audit.is_active(EMPRESS_OWNER) then gen_audit.end_epoch(EMPRESS_OWNER) end
			if gen_audit.is_active(LIVE_OWNER) then gen_audit.end_epoch(LIVE_OWNER) end
			gen_audit.begin_epoch(EMPRESS_OWNER)
			save.elses[EMPRESS_OWN .. "effect"] = 5
			clear_empress_on_pedestal(pickup)
			job.emp1 = empress_cr().applied
			job.live1 = live_cr().generation_seen
			job.epoch2_e = gen_audit.get_epoch(EMPRESS_OWNER)
			local player = Isaac.GetPlayer(0)
			if player and player:GetCollectibleNum(enums.Items.Live_Broadcast, true) > 0 then
				player:RemoveCollectible(enums.Items.Live_Broadcast)
				player:AddCollectible(enums.Items.Live_Broadcast, 0, false)
			else
				gen_audit.begin_epoch(LIVE_OWNER)
			end
			job.epoch2_l = gen_audit.get_epoch(LIVE_OWNER)
			job.phase = "epoch2"
			job.wait = 60
			state.hint = "epoch2：同 gen 应可重新 first-seen..."
			return
		end
	elseif job.phase == "epoch2" then
		pickup = find_by_seed(job.seed) or nearest_collectible()
		gen = gen_of(pickup)
		cr_e = empress_cr()
		cr_l = live_cr()
		if gen and gen.id == job.genA then
			local e_seen = gen_audit.has_seen(EMPRESS_OWNER, gen.id) == true
			local l_seen = gen_audit.has_seen(LIVE_OWNER, gen.id) == true
			local e_bump = (cr_e.applied or 0) > (job.emp1 or 0)
			local l_bump = (cr_l.generation_seen or 0) > (job.live1 or 0)
			if e_seen and e_bump and l_seen and l_bump then
				local detail = string.format(
					"Empress=PASS Live=PASS genA=%s epochE=%s epochL=%s",
					tostring(job.genA),
					tostring(job.epoch2_e),
					tostring(job.epoch2_l)
				)
				local row = pass_fail(true, detail)
				row.empress = "PASS"
				row.live = "PASS"
				set_result("Epoch", row)
				state.status = "PASS Epoch"
				state.hint = detail
				finish_job()
				return
			end
		end
	end
	job.wait = (job.wait or 0) - 1
	if job.wait <= 0 then
		local e_ok = gen and gen_audit.has_seen(EMPRESS_OWNER, job.genA or (gen and gen.id))
		local l_ok = gen and gen_audit.has_seen(LIVE_OWNER, job.genA or (gen and gen.id))
		local detail = string.format(
			"timeout phase=%s Empress=%s Live=%s gen=%s",
			tostring(job.phase),
			tostring(e_ok and "seen" or "miss"),
			tostring(l_ok and "seen" or "miss"),
			tostring(job.genA or (gen and gen.id))
		)
		local row = pass_fail(false, detail)
		row.empress = e_ok and "PARTIAL" or "FAIL"
		row.live = l_ok and "PARTIAL" or "FAIL"
		set_result("Epoch", row)
		state.status = "FAIL Epoch"
		state.hint = detail
		finish_job()
	end
end

table.insert(lab.ToCall, #lab.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		local job = state.job
		if not job then return end
		if job.kind == "cr1" then
			tick_cr1(job)
		elseif job.kind == "cr2" then
			tick_cr2(job)
		elseif job.kind == "cr3" then
			tick_cr3(job)
		elseif job.kind == "cr4" then
			tick_cr4(job)
		elseif job.kind == "cr5" then
			tick_cr5(job)
		elseif job.kind == "cr6" then
			tick_cr6(job)
		elseif job.kind == "cr7" then
			tick_cr7(job)
		elseif job.kind == "epoch" then
			tick_epoch(job)
		end
	end,
})

-- ImGui 打开时常暂停：POST_UPDATE 不跑。用 RENDER 推进 wait_prepare / 状态提示；
-- 离房回房仍须取消暂停（StartRoomTransition 依赖逻辑帧）。
table.insert(lab.ToCall, #lab.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_RENDER,
	params = nil,
	Function = function()
		local job = state.job
		if not job then return end
		local paused = Game().IsPaused and Game():IsPaused()
		if not paused then return end
		-- 仅推进「等 Empress/Live 就绪」阶段，避免在暂停中发 Transition
		if job.kind == "cr1" and (job.phase == "wait_prepare" or job.phase == "await_manual_return") then
			job._from_render = true
			tick_cr1(job)
			job._from_render = nil
		elseif job.kind == "cr2" and job.phase == "wait_a" then
			job._from_render = true
			tick_cr2(job)
			job._from_render = nil
		elseif job.kind == "cr4" and job.phase == "wait_apply" then
			job._from_render = true
			tick_cr4(job)
			job._from_render = nil
		elseif job.kind == "cr5" and job.phase == "wait_a" then
			job._from_render = true
			tick_cr5(job)
			job._from_render = nil
		elseif job.kind == "cr3" and job.phase == "confirm_skip" then
			job._from_render = true
			tick_cr3(job)
			job._from_render = nil
		elseif job.kind == "epoch" and job.phase == "epoch1" then
			job._from_render = true
			tick_epoch(job)
			job._from_render = nil
		else
			state.hint = tostring(job.phase) .. " — 请取消暂停以继续"
		end
	end,
})

-- ---------- Report / Reset ----------

function lab.build_report()
	local lines = {
		"=== Unique Consumer Regression ===",
		"",
	}
	local order = { "CR-1", "CR-2", "CR-3", "CR-4", "CR-5", "CR-6", "CR-7", "Epoch" }
	local pass_n, fail_n, obs_n = 0, 0, 0
	local r1 = state.results["CR-1"]
	if r1 then
		lines[#lines + 1] = "=== CR-1 Empress Room Return ==="
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Identity:"
		lines[#lines + 1] = "original_found=" .. tostring(r1.original_found)
		lines[#lines + 1] = "seed_before=" .. tostring(r1.seed_before)
		lines[#lines + 1] = "seed_after=" .. tostring(r1.seed_after)
		lines[#lines + 1] = "token_before=" .. tostring(r1.token_before)
		lines[#lines + 1] = "token_after=" .. tostring(r1.token_after)
		lines[#lines + 1] = "gen_before=" .. tostring(r1.gen_before)
		lines[#lines + 1] = "gen_after=" .. tostring(r1.gen_after)
		lines[#lines + 1] = "kind_before=" .. tostring(r1.kind_before)
		lines[#lines + 1] = "kind_after=" .. tostring(r1.kind_after)
		lines[#lines + 1] = "source_after=" .. tostring(r1.source_after)
		lines[#lines + 1] = "registry_gen_after=" .. tostring(r1.registry_gen_after)
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Consumer:"
		lines[#lines + 1] = "epoch_before=" .. tostring(r1.epoch_before)
		lines[#lines + 1] = "epoch_after=" .. tostring(r1.epoch_after)
		lines[#lines + 1] = "seen_before=" .. tostring(r1.seen_before)
		lines[#lines + 1] = "seen_after=" .. tostring(r1.seen_after)
		lines[#lines + 1] = "first_seen_before=" .. tostring(r1.first_seen_before)
		lines[#lines + 1] = "first_seen_after=" .. tostring(r1.first_seen_after)
		lines[#lines + 1] = "applied_before=" .. tostring(r1.applied_before)
		lines[#lines + 1] = "applied_after=" .. tostring(r1.applied_after)
		lines[#lines + 1] = "last_source_before=" .. tostring(
			r1.before_consumer and r1.before_consumer.last_source
		)
		lines[#lines + 1] = "last_source_after=" .. tostring(
			r1.after_consumer and r1.after_consumer.last_source
		)
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Empress State:"
		lines[#lines + 1] = "effect_before=" .. tostring(r1.effect_before)
		lines[#lines + 1] = "effect_after=" .. tostring(r1.effect_after)
		lines[#lines + 1] = "blind_before=" .. tostring(r1.blind_before)
		lines[#lines + 1] = "blind_after=" .. tostring(r1.blind_after)
		lines[#lines + 1] = "price_before=" .. tostring(r1.price_before)
		lines[#lines + 1] = "price_after=" .. tostring(r1.price_after)
		lines[#lines + 1] = "price_catched_before=" .. tostring(r1.price_catched_before)
		lines[#lines + 1] = "price_catched_after=" .. tostring(r1.price_catched_after)
		lines[#lines + 1] = "consistance_main_before=" .. tostring(r1.consistance_main_before)
		lines[#lines + 1] = "consistance_main_after=" .. tostring(r1.consistance_main_after)
		lines[#lines + 1] = "consistance_over_before=" .. tostring(r1.consistance_over_before)
		lines[#lines + 1] = "consistance_over_after=" .. tostring(r1.consistance_over_after)
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Result:"
		lines[#lines + 1] = tostring(r1.status)
		if r1.detail then lines[#lines + 1] = r1.detail end
		lines[#lines + 1] = ""
	else
		lines[#lines + 1] = "=== CR-1 Empress Room Return ===\n(not run)\n"
	end
	local r2 = state.results["CR-2"]
	if r2 then
		lines[#lines + 1] = "CR-2 Empress D6:"
		lines[#lines + 1] = tostring(r2.status)
		lines[#lines + 1] = string.format("genA=%s\ngenB=%s\napplied_delta=%s", tostring(r2.genA), tostring(r2.genB), tostring(r2.applied_delta))
		if r2.detail then lines[#lines + 1] = r2.detail end
		lines[#lines + 1] = ""
	else
		lines[#lines + 1] = "CR-2 Empress D6:\n(not run)\n"
	end
	local r3 = state.results["CR-3"]
	if r3 then
		lines[#lines + 1] = "CR-3 Empress Touched->D6:"
		lines[#lines + 1] = tostring(r3.status)
		lines[#lines + 1] = string.format(
			"genA=%s\ngenB=%s\nmorph_touched=%s\nstable_touched=%s\nretry_scheduled=%s\nretry_applied=%s\napplied_delta(obs)=%s\nflagged=%s",
			tostring(r3.genA),
			tostring(r3.genB),
			tostring(r3.morph_touched),
			tostring(r3.stable_touched),
			tostring(r3.retry_scheduled),
			tostring(r3.retry_applied),
			tostring(r3.applied_delta),
			tostring(r3.flagged)
		)
		if r3.detail then lines[#lines + 1] = r3.detail end
		lines[#lines + 1] = ""
	else
		lines[#lines + 1] = "CR-3 Empress Touched->D6:\n(not run)\n"
	end
	local r4 = state.results["CR-4"]
	if r4 then
		lines[#lines + 1] = "CR-4 Live Room Return:"
		lines[#lines + 1] = tostring(r4.status)
		lines[#lines + 1] = string.format(
			"gen_before=%s\ngen_after=%s\nkind_before=%s\nkind_after=%s\nepoch_before=%s\nepoch_after=%s\ntrigger_before=%s\ntrigger_after=%s\nseen_before=%s\nseen_after=%s",
			tostring(r4.gen_before),
			tostring(r4.gen_after),
			tostring(r4.kind_before),
			tostring(r4.kind_after),
			tostring(r4.epoch_before or (r4.before and r4.before.epoch)),
			tostring(r4.epoch_after or r4.epoch),
			tostring(r4.trigger_before),
			tostring(r4.trigger_after),
			tostring(r4.seen_before),
			tostring(r4.seen_after)
		)
		if r4.detail then lines[#lines + 1] = r4.detail end
		lines[#lines + 1] = ""
	else
		lines[#lines + 1] = "CR-4 Live Room Return:\n(not run)\n"
	end
	local r5 = state.results["CR-5"]
	if r5 then
		lines[#lines + 1] = "CR-5 Live D6:"
		lines[#lines + 1] = tostring(r5.status)
		lines[#lines + 1] = string.format("genA=%s\ngenB=%s\ntrigger_delta=%s", tostring(r5.genA), tostring(r5.genB), tostring(r5.trigger_delta))
		if r5.detail then lines[#lines + 1] = r5.detail end
		lines[#lines + 1] = ""
	else
		lines[#lines + 1] = "CR-5 Live D6:\n(not run)\n"
	end
	local r6 = state.results["CR-6"]
	if r6 then
		lines[#lines + 1] = "CR-6 Fool/Hermit:"
		lines[#lines + 1] = string.format(
			"Fool Cycle=%s\nFool D6=%s\nHermit Cycle=%s\nHermit D6=%s\n%s",
			tostring(r6.fool_cycle),
			tostring(r6.fool_d6),
			tostring(r6.hermit_cycle),
			tostring(r6.hermit_d6),
			tostring(r6.status)
		)
		if r6.detail then lines[#lines + 1] = r6.detail end
		lines[#lines + 1] = ""
	else
		lines[#lines + 1] = "CR-6 Fool/Hermit:\n(not run)\n"
	end
	local r7 = state.results["CR-7"]
	if r7 then
		lines[#lines + 1] = "CR-7 Perhaps:"
		lines[#lines + 1] = string.format(
			"Cycle same host=%s\nD6 new host=%s\n%s",
			tostring(r7.cycle_same_host),
			tostring(r7.d6_new_host),
			tostring(r7.status)
		)
		if r7.detail then lines[#lines + 1] = r7.detail end
		lines[#lines + 1] = ""
	else
		lines[#lines + 1] = "CR-7 Perhaps:\n(not run)\n"
	end
	local re = state.results["Epoch"]
	if re then
		lines[#lines + 1] = "Epoch Smoke:"
		lines[#lines + 1] = string.format("Empress=%s\nLive=%s", tostring(re.empress or re.status), tostring(re.live or re.status))
		if re.detail then lines[#lines + 1] = re.detail end
		lines[#lines + 1] = ""
	else
		lines[#lines + 1] = "Epoch Smoke:\n(not run)\n"
	end
	for _, id in ipairs(order) do
		local r = state.results[id]
		if r then
			local st = tostring(r.status or "?")
			if st == "PASS" then
				pass_n = pass_n + 1
			elseif st == "PREPARED" or st == "OBSERVED" then
				obs_n = obs_n + 1
			elseif st:find("^FAIL", 1, false) or st == "BLOCKED" or st == "FAIL" then
				fail_n = fail_n + 1
			end
		end
	end
	lines[#lines + 1] = "Summary:"
	lines[#lines + 1] = string.format("PASS=%d", pass_n)
	lines[#lines + 1] = string.format("FAIL=%d", fail_n)
	lines[#lines + 1] = string.format("OBSERVED=%d", obs_n)
	return table.concat(lines, "\n")
end

function lab.copy_report()
	local text = lab.build_report()
	state.last_report = text
	persist_bag().last_report = text
	pcall(function()
		Isaac.SetClipboard(text)
	end)
	state.status = "Report copied"
	state.hint = "已复制 Consumer Report"
	return text
end

function lab.reset_tests()
	state.job = nil
	state.results = {}
	state.last_report = ""
	state.status = "Reset"
	state.hint = ""
	local bag = persist_bag()
	bag.results = {}
	bag.cr1 = nil
	bag.cr4 = nil
	bag.last_report = nil
	local emp = require_empress()
	local live = require_live()
	local fool = require_fool()
	local hermit = require_hermit()
	local perhaps = require_perhaps()
	if emp.reset_debug_cr then emp.reset_debug_cr() end
	if live.reset_debug_cr then live.reset_debug_cr() end
	if fool.reset_debug_cr then fool.reset_debug_cr() end
	if hermit.reset_debug_cr then hermit.reset_debug_cr() end
	if perhaps.reset_debug_audit then perhaps.reset_debug_audit() end
end

function lab.get_status_text()
	local job = state.job
	local job_s = job and string.format("%s phase=%s wait=%s", tostring(job.kind), tostring(job.phase), tostring(job.wait)) or "-"
	return string.format(
		"%s\n%s\njob=%s\nframe=%s",
		tostring(state.status),
		tostring(state.hint),
		job_s,
		tostring(game_frame())
	)
end

return lab
