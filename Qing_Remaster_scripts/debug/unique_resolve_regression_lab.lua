-- Unique Resolve Regression Lab（UR-1～UR-7 核心）
-- 验证 resolve_generation：不把 readiness timing 暴露给 consumer。
-- ImGui → Debug → Audit → Unique Resolve Regression

local enums = require("Qing_Remaster_scripts.core.enums")
local unique = require("Qing_Remaster_scripts.others.Unique_holder")

local ITEM_A = CollectibleType.COLLECTIBLE_BREAKFAST
local ITEM_B = CollectibleType.COLLECTIBLE_LUNCH
local SAVE_KEY = "UniqueResolveRegressionLab"

local lab = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	own_key = "unique_resolve_regression_lab_",
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

--- UR-1：spawn 后立即 resolve 必须有稳定 id
function lab.run_ur1()
	local pickup = spawn_collectible(ITEM_A)
	if not pickup then
		set_result("UR-1", pass_fail(false, "spawn failed"))
		state.status = "FAIL UR-1"
		return
	end
	local peek0 = unique.peek_generation(pickup)
	local gen = unique.resolve_generation(pickup)
	local ok = gen ~= nil and gen.id ~= nil
	local detail = string.format(
		"peek_before=%s resolve_id=%s kind=%s source=%s",
		tostring(peek0 and peek0.id),
		tostring(gen and gen.id),
		tostring(gen and gen.kind),
		tostring(gen and gen.source)
	)
	local row = pass_fail(ok, detail)
	row.resolve_id = gen and gen.id
	set_result("UR-1", row)
	state.status = row.status .. " UR-1"
	state.hint = detail
end

--- UR-2 Manual：Prepare → 出房回房 → Check（禁止 nearest）
function lab.prepare_ur2()
	local pickup = spawn_collectible(ITEM_A)
	if not pickup then
		set_result("UR-2", { status = "BLOCKED", detail = "spawn failed" })
		return
	end
	local gen = unique.resolve_generation(pickup)
	if not (gen and gen.id) then
		set_result("UR-2", pass_fail(false, "resolve failed on prepare"))
		state.status = "FAIL UR-2"
		return
	end
	set_job({
		kind = "ur2",
		label = "UR-2 Prepare",
		phase = "await_return",
		seed = pickup.InitSeed,
		gen_before = gen.id,
		kind_before = gen.kind,
	})
	state.status = "PREPARED UR-2"
	state.hint = "Leave room normally, return, then Check UR-2."
end

function lab.check_ur2()
	local job = state.job
	if not (job and job.kind == "ur2" and job.gen_before) then
		state.status = "BLOCKED UR-2"
		state.hint = "请先 Prepare UR-2"
		return
	end
	local pickup = find_by_seed(job.seed)
	if not pickup then
		set_result("UR-2", {
			status = "FAIL",
			detail = "original pedestal missing after room return",
		})
		state.status = "FAIL UR-2"
		finish_job()
		return
	end
	local gen = unique.resolve_generation(pickup)
	local ok = gen
		and tonumber(gen.id) == tonumber(job.gen_before)
		and (gen.kind == "GEN_RESTORED" or gen.kind == "GEN_SAME")
	local detail = string.format(
		"gen %s->%s kind %s->%s source=%s",
		tostring(job.gen_before),
		tostring(gen and gen.id),
		tostring(job.kind_before),
		tostring(gen and gen.kind),
		tostring(gen and gen.source)
	)
	set_result("UR-2", pass_fail(ok, detail))
	state.status = (ok and "PASS" or "FAIL") .. " UR-2"
	state.hint = detail
	finish_job()
end

--- UR-4：keepSeed Cycle → same id
function lab.run_ur4()
	local pickup = spawn_collectible(ITEM_A)
	if not pickup then
		set_result("UR-4", pass_fail(false, "spawn failed"))
		return
	end
	local before = unique.resolve_generation(pickup)
	if not (before and before.id) then
		set_result("UR-4", pass_fail(false, "resolve before failed"))
		return
	end
	local seed = pickup.InitSeed
	morph_cycle(pickup, ITEM_B)
	pickup = find_by_seed(seed) or pickup
	local after = unique.resolve_generation(pickup)
	local ok = after
		and tonumber(after.id) == tonumber(before.id)
		and after.kind == "GEN_SAME"
	local detail = string.format(
		"id %s->%s kind %s->%s",
		tostring(before.id),
		tostring(after and after.id),
		tostring(before.kind),
		tostring(after and after.kind)
	)
	set_result("UR-4", pass_fail(ok, detail))
	state.status = (ok and "PASS" or "FAIL") .. " UR-4"
	state.hint = detail
end

--- UR-5：D6 → new id
function lab.run_ur5()
	local pickup = spawn_collectible(ITEM_A)
	if not pickup then
		set_result("UR-5", pass_fail(false, "spawn failed"))
		return
	end
	local before = unique.resolve_generation(pickup)
	if not (before and before.id) then
		set_result("UR-5", pass_fail(false, "resolve before failed"))
		return
	end
	set_job({
		kind = "ur5",
		label = "UR-5 D6",
		phase = "wait_b",
		seed = pickup.InitSeed,
		gen_before = before.id,
		wait = 45,
	})
	use_d6()
	state.hint = "等待 D6 后 resolve..."
end

local function tick_ur5(job)
	-- D6 会改 InitSeed：禁止只用旧 seed；在房内找不同 generation
	local after = nil
	for _, e in ipairs(Isaac.FindByType(5, 100, -1, false, false)) do
		local p = e:ToPickup()
		if p and (p.SubType or 0) > 0 then
			local gen = unique.resolve_generation(p)
			if gen and gen.id and tonumber(gen.id) ~= tonumber(job.gen_before) then
				after = gen
				break
			end
		end
	end
	if after then
		local ok = after.kind == "GEN_NEW"
		local detail = string.format(
			"id %s->%s kind=%s source=%s",
			tostring(job.gen_before),
			tostring(after.id),
			tostring(after.kind),
			tostring(after.source)
		)
		set_result("UR-5", pass_fail(ok, detail))
		state.status = (ok and "PASS" or "FAIL") .. " UR-5"
		state.hint = detail
		finish_job()
		return
	end
	job.wait = (job.wait or 0) - 1
	if job.wait <= 0 then
		set_result("UR-5", pass_fail(false, "timeout waiting new generation"))
		state.status = "FAIL UR-5"
		finish_job()
	end
end

table.insert(lab.ToCall, #lab.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		local job = state.job
		if not job then return end
		if job.kind == "ur5" then
			tick_ur5(job)
		end
	end,
})

function lab.build_report()
	local lines = { "=== Unique Resolve Regression ===", "" }
	local order = { "UR-1", "UR-2", "UR-4", "UR-5" }
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
	local dbg = unique.debug or {}
	lines[#lines + 1] = "Resolve counters:"
	lines[#lines + 1] = string.format(
		"runtime=%s registry=%s essm=%s morph=%s classify=%s unresolved=%s conflict=%s",
		tostring(dbg.resolve_runtime_hit),
		tostring(dbg.resolve_registry_hit),
		tostring(dbg.resolve_essm_hit),
		tostring(dbg.resolve_morph_hit),
		tostring(dbg.resolve_classify_hit),
		tostring(dbg.resolve_unresolved),
		tostring(dbg.resolve_conflict)
	)
	if dbg.last_resolve then
		lines[#lines + 1] = "last_resolve=" .. tostring(dbg.last_resolve.reason)
			.. " id=" .. tostring(dbg.last_resolve.generation_id)
	end
	return table.concat(lines, "\n")
end

function lab.copy_report()
	local text = lab.build_report()
	pcall(function()
		Isaac.SetClipboard(text)
	end)
	state.hint = "Report copied"
	return text
end

function lab.reset_tests()
	state.results = {}
	state.job = nil
	state.status = "Idle"
	state.hint = "reset"
	if unique.reset_shadow_stats then
		unique.reset_shadow_stats()
	end
end

function lab.get_status_text()
	return string.format("%s\n%s", tostring(state.status), tostring(state.hint or ""))
end

return lab
