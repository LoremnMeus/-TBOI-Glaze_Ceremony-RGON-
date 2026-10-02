-- Unique Fresh Generation Regression Lab（FR-1～FR-8）
-- 验证 is_fresh_generation / birth_room_epoch，不依赖 kind 仍为 GEN_NEW。
-- ImGui → Debug → Audit → Unique Fresh Generation

local unique = require("Qing_Remaster_scripts.others.Unique_holder")

local ITEM_A = CollectibleType.COLLECTIBLE_BREAKFAST
local ITEM_B = CollectibleType.COLLECTIBLE_LUNCH
local SAVE_KEY = "UniqueFreshGenerationLab"

local lab = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	own_key = "unique_fresh_generation_lab_",
}

local state = {
	status = "Idle",
	hint = "",
	results = {},
	job = nil,
}

local function set_result(id, row)
	state.results[id] = row
end

local function pass_fail(ok, detail)
	return { status = ok and "PASS" or "FAIL", detail = detail, ok = ok == true }
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
	return ent and ent:ToPickup() or nil
end

local function find_by_seed(seed)
	if not seed then return nil end
	for _, e in ipairs(Isaac.FindByType(5, 100, -1, false, false)) do
		local p = e:ToPickup()
		if p and p.InitSeed == seed then return p end
	end
	return nil
end

local function morph_cycle(pickup, subtype)
	if not pickup or not pickup.Morph then return end
	pcall(function()
		pickup:Morph(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, subtype or ITEM_B, true, true, true)
	end)
end

local function morph_seed_change(pickup, subtype)
	if not pickup or not pickup.Morph then return end
	pcall(function()
		-- keepSeed=false → 新 generation
		pickup:Morph(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, subtype or ITEM_B, false, true, true)
	end)
end

local function use_d6()
	local player = Isaac.GetPlayer(0)
	pcall(function()
		player:UseActiveItem(CollectibleType.COLLECTIBLE_D6, false, false, true, false)
	end)
end

local function finish_job()
	state.job = nil
end

local function set_job(job)
	state.job = job
	state.status = job.label or job.kind
	state.hint = job.hint or ""
end

local function snap(pickup)
	local gen = unique.resolve_generation(pickup)
	local fresh = unique.is_fresh_generation(pickup)
	return {
		gen = gen,
		id = gen and gen.id,
		kind = gen and gen.kind,
		birth = gen and gen.birth_room_epoch,
		room_epoch = unique.get_room_generation_epoch(),
		fresh = fresh,
	}
end

local function fmt_snap(s)
	return string.format(
		"id=%s kind=%s birth=%s room=%s fresh=%s",
		tostring(s and s.id),
		tostring(s and s.kind),
		tostring(s and s.birth),
		tostring(s and s.room_epoch),
		tostring(s and s.fresh)
	)
end

--- FR-1：spawn 后 0/1/2/5 帧仍 fresh，id 稳定
function lab.run_fr1()
	local pickup = spawn_collectible(ITEM_A)
	if not pickup then
		set_result("FR-1", pass_fail(false, "spawn failed"))
		state.status = "FAIL FR-1"
		return
	end
	local s0 = snap(pickup)
	if not (s0.id and s0.fresh) then
		set_result("FR-1", pass_fail(false, "immediate not fresh: " .. fmt_snap(s0)))
		state.status = "FAIL FR-1"
		return
	end
	set_job({
		kind = "fr1",
		label = "FR-1 New Spawn",
		seed = pickup.InitSeed,
		gen_id = s0.id,
		birth = s0.birth,
		checks = { { at = 0, done = true, ok = true }, { at = 1 }, { at = 2 }, { at = 5 } },
		frame0 = pickup.FrameCount,
		wait = 90,
		hint = "等待 delayed fresh reads...",
	})
end

--- FR-2 Manual：Prepare → 出房回房 → Check（restore 不得 fresh）
function lab.prepare_fr2()
	local pickup = spawn_collectible(ITEM_A)
	if not pickup then
		set_result("FR-2", { status = "BLOCKED", detail = "spawn failed" })
		return
	end
	local s = snap(pickup)
	if not (s.id and s.fresh) then
		set_result("FR-2", pass_fail(false, "prepare not fresh: " .. fmt_snap(s)))
		state.status = "FAIL FR-2"
		return
	end
	state._fr2 = {
		seed = pickup.InitSeed,
		gen_id = s.id,
		birth = s.birth,
		room_epoch = s.room_epoch,
	}
	set_result("FR-2", { status = "READY", detail = "出房再回房后点 Check FR-2" })
	state.status = "READY FR-2"
	state.hint = "离开房间再回来，然后 Check FR-2"
end

function lab.check_fr2()
	local bag = state._fr2
	if not bag then
		set_result("FR-2", pass_fail(false, "no prepare"))
		return
	end
	local pickup = find_by_seed(bag.seed)
	if not pickup then
		set_result("FR-2", pass_fail(false, "seed not found after return"))
		state.status = "FAIL FR-2"
		return
	end
	local s = snap(pickup)
	local same = tonumber(s.id) == tonumber(bag.gen_id)
	local not_fresh = s.fresh ~= true
	local restored = s.kind == "GEN_RESTORED" or not_fresh
	local ok = same and not_fresh
	local detail = string.format(
		"same_id=%s not_fresh=%s kind=%s %s (prep birth=%s room=%s→%s)",
		tostring(same),
		tostring(not_fresh),
		tostring(s.kind),
		fmt_snap(s),
		tostring(bag.birth),
		tostring(bag.room_epoch),
		tostring(s.room_epoch)
	)
	local row = pass_fail(ok, detail)
	row.restored_obs = restored
	set_result("FR-2", row)
	state.status = row.status .. " FR-2"
	state.hint = detail
end

--- FR-3：Cycle keepSeed → same id，fresh 仍 true，birth 不变
function lab.run_fr3()
	local pickup = spawn_collectible(ITEM_A)
	if not pickup then
		set_result("FR-3", pass_fail(false, "spawn failed"))
		return
	end
	local before = snap(pickup)
	if not (before.id and before.fresh) then
		set_result("FR-3", pass_fail(false, "before not fresh: " .. fmt_snap(before)))
		return
	end
	morph_cycle(pickup, ITEM_B)
	set_job({
		kind = "fr3",
		label = "FR-3 Cycle",
		seed = pickup.InitSeed,
		gen_before = before.id,
		birth_before = before.birth,
		wait = 45,
		hint = "Cycle settle...",
	})
end

--- FR-4：D6 → new id，fresh true
function lab.run_fr4()
	local pickup = spawn_collectible(ITEM_A)
	if not pickup then
		set_result("FR-4", pass_fail(false, "spawn failed"))
		return
	end
	local before = snap(pickup)
	if not before.id then
		set_result("FR-4", pass_fail(false, "resolve before failed"))
		return
	end
	set_job({
		kind = "fr4",
		label = "FR-4 D6",
		seed = pickup.InitSeed,
		gen_before = before.id,
		wait = 60,
		hint = "D6 settle...",
	})
	use_d6()
end

--- FR-5：same-seed Morph → same id / birth，fresh 不因 Morph 重建
function lab.run_fr5()
	local pickup = spawn_collectible(ITEM_A)
	if not pickup then
		set_result("FR-5", pass_fail(false, "spawn failed"))
		return
	end
	local before = snap(pickup)
	morph_cycle(pickup, ITEM_B)
	set_job({
		kind = "fr5",
		label = "FR-5 same-seed Morph",
		seed = pickup.InitSeed,
		gen_before = before.id,
		birth_before = before.birth,
		wait = 45,
	})
end

--- FR-6：seed-changing Morph → new id，fresh true
function lab.run_fr6()
	local pickup = spawn_collectible(ITEM_A)
	if not pickup then
		set_result("FR-6", pass_fail(false, "spawn failed"))
		return
	end
	local before = snap(pickup)
	morph_seed_change(pickup, ITEM_B)
	set_job({
		kind = "fr6",
		label = "FR-6 seed Morph",
		seed = pickup.InitSeed,
		gen_before = before.id,
		wait = 45,
	})
end

--- FR-7：delayed read 2/5/10 帧仍 fresh
function lab.run_fr7()
	local pickup = spawn_collectible(ITEM_A)
	if not pickup then
		set_result("FR-7", pass_fail(false, "spawn failed"))
		return
	end
	local s0 = snap(pickup)
	set_job({
		kind = "fr7",
		label = "FR-7 delayed",
		seed = pickup.InitSeed,
		gen_id = s0.id,
		targets = { 2, 5, 10 },
		hits = {},
		frame0 = Game():GetFrameCount(),
		wait = 120,
	})
end

--- FR-8 Manual：回房后 delayed 2/5/10 始终 not fresh
function lab.prepare_fr8()
	lab.prepare_fr2()
	if state._fr2 then
		state._fr8 = state._fr2
		set_result("FR-8", { status = "READY", detail = "回房后点 Run FR-8 Delayed" })
		state.status = "READY FR-8"
		state.hint = "回房后点 FR-8 Delayed Check"
	end
end

function lab.run_fr8_delayed()
	local bag = state._fr8 or state._fr2
	if not bag then
		set_result("FR-8", pass_fail(false, "no prepare"))
		return
	end
	local pickup = find_by_seed(bag.seed)
	if not pickup then
		set_result("FR-8", pass_fail(false, "seed not found"))
		return
	end
	set_job({
		kind = "fr8",
		label = "FR-8 restored delayed",
		seed = bag.seed,
		gen_id = bag.gen_id,
		targets = { 2, 5, 10 },
		hits = {},
		frame0 = Game():GetFrameCount(),
		wait = 120,
	})
end

local function tick_fr1(job)
	local pickup = find_by_seed(job.seed)
	if not pickup then
		job.wait = (job.wait or 0) - 1
		if job.wait <= 0 then
			set_result("FR-1", pass_fail(false, "lost pickup"))
			state.status = "FAIL FR-1"
			finish_job()
		end
		return
	end
	local fc = pickup.FrameCount or 0
	local all_ok = true
	local parts = {}
	for _, c in ipairs(job.checks) do
		if not c.done and fc >= c.at then
			local s = snap(pickup)
			c.done = true
			c.ok = tonumber(s.id) == tonumber(job.gen_id) and s.fresh == true
				and tonumber(s.birth) == tonumber(job.birth)
			c.snap = s
		end
		if c.done then
			all_ok = all_ok and c.ok
			parts[#parts + 1] = string.format("t=%s ok=%s %s", tostring(c.at), tostring(c.ok), fmt_snap(c.snap))
		end
	end
	local pending = false
	for _, c in ipairs(job.checks) do
		if not c.done then pending = true break end
	end
	if not pending then
		local detail = table.concat(parts, " | ")
		set_result("FR-1", pass_fail(all_ok, detail))
		state.status = (all_ok and "PASS" or "FAIL") .. " FR-1"
		state.hint = detail
		finish_job()
		return
	end
	job.wait = (job.wait or 0) - 1
	if job.wait <= 0 then
		set_result("FR-1", pass_fail(false, "timeout " .. table.concat(parts, " | ")))
		state.status = "FAIL FR-1"
		finish_job()
	end
end

local function tick_fr3(job)
	local pickup = find_by_seed(job.seed)
	if pickup and (job.wait or 0) < 35 then
		local s = snap(pickup)
		local ok = tonumber(s.id) == tonumber(job.gen_before)
			and s.fresh == true
			and tonumber(s.birth) == tonumber(job.birth_before)
		local detail = string.format("same+fresh+birth: %s", fmt_snap(s))
		set_result("FR-3", pass_fail(ok, detail))
		state.status = (ok and "PASS" or "FAIL") .. " FR-3"
		state.hint = detail
		finish_job()
		return
	end
	job.wait = (job.wait or 0) - 1
	if job.wait <= 0 then
		set_result("FR-3", pass_fail(false, "timeout"))
		state.status = "FAIL FR-3"
		finish_job()
	end
end

local function tick_fr4(job)
	local after = nil
	for _, e in ipairs(Isaac.FindByType(5, 100, -1, false, false)) do
		local p = e:ToPickup()
		if p and (p.SubType or 0) > 0 then
			local s = snap(p)
			if s.id and tonumber(s.id) ~= tonumber(job.gen_before) then
				after = s
				break
			end
		end
	end
	if after then
		local ok = after.fresh == true
			and tonumber(after.birth) == tonumber(after.room_epoch)
		local detail = string.format("%s→%s", tostring(job.gen_before), fmt_snap(after))
		set_result("FR-4", pass_fail(ok, detail))
		state.status = (ok and "PASS" or "FAIL") .. " FR-4"
		state.hint = detail
		finish_job()
		return
	end
	job.wait = (job.wait or 0) - 1
	if job.wait <= 0 then
		set_result("FR-4", pass_fail(false, "timeout waiting new gen"))
		state.status = "FAIL FR-4"
		finish_job()
	end
end

local function tick_fr5(job)
	local pickup = find_by_seed(job.seed)
	if pickup and (job.wait or 0) < 35 then
		local s = snap(pickup)
		local ok = tonumber(s.id) == tonumber(job.gen_before)
			and tonumber(s.birth) == tonumber(job.birth_before)
			and s.fresh == true
		local detail = fmt_snap(s)
		set_result("FR-5", pass_fail(ok, detail))
		state.status = (ok and "PASS" or "FAIL") .. " FR-5"
		finish_job()
		return
	end
	job.wait = (job.wait or 0) - 1
	if job.wait <= 0 then
		set_result("FR-5", pass_fail(false, "timeout"))
		finish_job()
	end
end

local function tick_fr6(job)
	-- seed change 可能换 InitSeed：扫房找不同 gen
	local after = nil
	for _, e in ipairs(Isaac.FindByType(5, 100, -1, false, false)) do
		local p = e:ToPickup()
		if p and (p.SubType or 0) > 0 then
			local s = snap(p)
			if s.id and tonumber(s.id) ~= tonumber(job.gen_before) then
				after = s
				break
			end
		end
	end
	if after and (job.wait or 0) < 35 then
		local ok = after.fresh == true
		local detail = string.format("%s→%s", tostring(job.gen_before), fmt_snap(after))
		set_result("FR-6", pass_fail(ok, detail))
		state.status = (ok and "PASS" or "FAIL") .. " FR-6"
		finish_job()
		return
	end
	job.wait = (job.wait or 0) - 1
	if job.wait <= 0 then
		set_result("FR-6", pass_fail(false, "timeout"))
		finish_job()
	end
end

local function tick_delayed(job, case_id, expect_fresh)
	local pickup = find_by_seed(job.seed)
	if not pickup then
		job.wait = (job.wait or 0) - 1
		if job.wait <= 0 then
			set_result(case_id, pass_fail(false, "lost pickup"))
			finish_job()
		end
		return
	end
	local elapsed = Game():GetFrameCount() - (job.frame0 or 0)
	for _, t in ipairs(job.targets) do
		if job.hits[t] == nil and elapsed >= t then
			local s = snap(pickup)
			local same = tonumber(s.id) == tonumber(job.gen_id)
			local ok = same and (s.fresh == expect_fresh)
			job.hits[t] = { ok = ok, snap = s }
		end
	end
	local pending = false
	local all_ok = true
	local parts = {}
	for _, t in ipairs(job.targets) do
		local h = job.hits[t]
		if not h then
			pending = true
		else
			all_ok = all_ok and h.ok
			parts[#parts + 1] = string.format("t=%s ok=%s %s", tostring(t), tostring(h.ok), fmt_snap(h.snap))
		end
	end
	if not pending then
		local detail = table.concat(parts, " | ")
		set_result(case_id, pass_fail(all_ok, detail))
		state.status = (all_ok and "PASS" or "FAIL") .. " " .. case_id
		state.hint = detail
		finish_job()
		return
	end
	job.wait = (job.wait or 0) - 1
	if job.wait <= 0 then
		set_result(case_id, pass_fail(false, "timeout " .. table.concat(parts, " | ")))
		finish_job()
	end
end

table.insert(lab.ToCall, #lab.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		local job = state.job
		if not job then return end
		if job.kind == "fr1" then
			tick_fr1(job)
		elseif job.kind == "fr3" then
			tick_fr3(job)
		elseif job.kind == "fr4" then
			tick_fr4(job)
		elseif job.kind == "fr5" then
			tick_fr5(job)
		elseif job.kind == "fr6" then
			tick_fr6(job)
		elseif job.kind == "fr7" then
			tick_delayed(job, "FR-7", true)
		elseif job.kind == "fr8" then
			tick_delayed(job, "FR-8", false)
		end
	end,
})

function lab.build_report()
	local lines = { "=== Unique Fresh Generation Regression ===", "" }
	local order = { "FR-1", "FR-2", "FR-3", "FR-4", "FR-5", "FR-6", "FR-7", "FR-8" }
	for _, id in ipairs(order) do
		local r = state.results[id]
		lines[#lines + 1] = id .. ":"
		if r then
			lines[#lines + 1] = tostring(r.status)
			if r.detail then lines[#lines + 1] = r.detail end
		else
			lines[#lines + 1] = "(not run)"
		end
		lines[#lines + 1] = ""
	end
	return table.concat(lines, "\n")
end

function lab.get_status_text()
	local lines = {
		"status: " .. tostring(state.status),
		"hint: " .. tostring(state.hint),
		"",
		lab.build_report(),
	}
	return table.concat(lines, "\n")
end

function lab.copy_report()
	local text = lab.build_report()
	pcall(function()
		Isaac.SetClipboard(text)
	end)
	state.hint = "report copied"
	return text
end

function lab.reset_tests()
	state.job = nil
	state.results = {}
	state._fr2 = nil
	state._fr8 = nil
	state.status = "Idle"
	state.hint = ""
end

return lab
