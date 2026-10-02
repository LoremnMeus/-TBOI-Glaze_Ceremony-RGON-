-- Pedestal Encounter Regression Lab（EN-1～EN-4 + DC-1～DC-4 核心）
-- ImGui → Debug → Audit → Pedestal Encounter Regression

local enums = require("Qing_Remaster_scripts.core.enums")
local unique = require("Qing_Remaster_scripts.others.Unique_holder")
local pe = require("Qing_Remaster_scripts.others.Pedestal_Encounter_holder")

local ITEM_A = CollectibleType.COLLECTIBLE_BREAKFAST
local ITEM_B = CollectibleType.COLLECTIBLE_LUNCH

local lab = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "pedestal_encounter_regression_lab_",
}

local state = {
	status = "Idle",
	hint = "",
	results = {},
	job = nil,
	normal_hits = 0,
	display_hits = 0,
}

local function set_result(id, row)
	state.results[id] = row
end

local function pass_fail(ok, detail)
	return { status = ok and "PASS" or "FAIL", detail = detail, ok = ok == true }
end

local function snap_pe()
	return pe.get_debug_snapshot()
end

local function spawn_collectible(subtype, opts)
	opts = opts or {}
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
	local p = ent and ent:ToPickup()
	if p and opts.options_index ~= nil then
		p.OptionsPickupIndex = opts.options_index
	end
	if p and opts.suppress then
		pe.mark_suppressed(p, "lab")
	end
	return p
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

table.insert(lab.myToCall, #lab.myToCall + 1, {
	CallBack = enums.Callbacks.POST_PEDESTAL_ENCOUNTER,
	params = nil,
	Function = function(_, encounter)
		state.normal_hits = (state.normal_hits or 0) + 1
		state.last_normal = encounter
	end,
})

table.insert(lab.myToCall, #lab.myToCall + 1, {
	CallBack = enums.Callbacks.POST_DEATH_CERTIFICATE_DISPLAY_ENCOUNTER,
	params = nil,
	Function = function(_, encounter)
		state.display_hits = (state.display_hits or 0) + 1
		state.last_display = encounter
	end,
})

--- EN-1：普通新 pedestal → normal +1，display +0
function lab.run_en1()
	local before = snap_pe()
	local n0 = state.normal_hits or 0
	local d0 = state.display_hits or 0
	local pickup = spawn_collectible(ITEM_A)
	if not pickup then
		set_result("EN-1", pass_fail(false, "spawn failed"))
		return
	end
	set_job({
		kind = "en1",
		label = "EN-1 Natural",
		seed = pickup.InitSeed,
		n0 = n0,
		d0 = d0,
		offer0 = before.normal_offer_count or 0,
		wait = 60,
	})
end

--- EN-2：Cycle → no new normal
function lab.run_en2()
	local pickup = spawn_collectible(ITEM_A)
	if not pickup then
		set_result("EN-2", pass_fail(false, "spawn failed"))
		return
	end
	set_job({
		kind = "en2",
		label = "EN-2 Cycle",
		phase = "wait_base",
		seed = pickup.InitSeed,
		n0 = state.normal_hits or 0,
		wait = 60,
	})
end

--- EN-3：D6 → new normal
function lab.run_en3()
	local pickup = spawn_collectible(ITEM_A)
	if not pickup then
		set_result("EN-3", pass_fail(false, "spawn failed"))
		return
	end
	set_job({
		kind = "en3",
		label = "EN-3 D6",
		phase = "wait_base",
		seed = pickup.InitSeed,
		n0 = state.normal_hits or 0,
		wait = 60,
	})
end

--- EN-4：标记 residue 后不应发 normal（用 mark + suppress 近似；真 Active Swap 需手测）
function lab.run_en4()
	local n0 = state.normal_hits or 0
	local pickup = spawn_collectible(ITEM_A)
	if not pickup then
		set_result("EN-4", pass_fail(false, "spawn failed"))
		return
	end
	local d = pickup:GetData()
	d._QingPedestalEncounterResidue = true
	d._QingPedestalEncounterClass = "PLAYER_RESIDUE"
	set_job({
		kind = "en4",
		label = "EN-4 Residue mark",
		seed = pickup.InitSeed,
		n0 = n0,
		wait = 45,
	})
end

--- DC-4：非 DC 维度 idx=1 → normal，非 display
function lab.run_dc4()
	if pe.is_in_death_certificate_dimension() then
		set_result("DC-4", { status = "BLOCKED", detail = "当前在 DC 维度；请在普通房间跑" })
		state.status = "BLOCKED DC-4"
		return
	end
	local n0 = state.normal_hits or 0
	local d0 = state.display_hits or 0
	local pickup = spawn_collectible(ITEM_A, { options_index = 1 })
	set_job({
		kind = "dc4",
		label = "DC-4 idx1 outside DC",
		seed = pickup and pickup.InitSeed,
		n0 = n0,
		d0 = d0,
		wait = 60,
	})
end

--- DC-3：若在 DC 维度，spawn idx=0 → normal +1
function lab.run_dc3()
	if not pe.is_in_death_certificate_dimension() then
		set_result("DC-3", { status = "BLOCKED", detail = "请先进入 Death Certificate 维度" })
		state.status = "BLOCKED DC-3"
		return
	end
	local n0 = state.normal_hits or 0
	local d0 = state.display_hits or 0
	local pickup = spawn_collectible(ITEM_A, { options_index = 0 })
	set_job({
		kind = "dc3",
		label = "DC-3 normal in DC",
		seed = pickup and pickup.InitSeed,
		n0 = n0,
		d0 = d0,
		wait = 60,
	})
end

--- DC-1：在 DC 维度统计现有 idx=1（期望 display 至多 +1，normal 不因 idx1 增加）
function lab.check_dc1()
	if not pe.is_in_death_certificate_dimension() then
		set_result("DC-1", { status = "BLOCKED", detail = "不在 DC 维度" })
		return
	end
	local snap = snap_pe()
	local n = 0
	for _, e in ipairs(Isaac.FindByType(5, 100, -1, false, false)) do
		local p = e:ToPickup()
		if p and (p.OptionsPickupIndex or 0) == 1 and (p.SubType or 0) > 0 then
			n = n + 1
		end
	end
	local ok = (snap.dc_display_count or 0) >= 1 and n > 0
	local detail = string.format(
		"idx1_count=%s display_count=%s normal_offer=%s in_dc=%s",
		tostring(n),
		tostring(snap.dc_display_count),
		tostring(snap.normal_offer_count),
		tostring(snap.in_dc_dimension)
	)
	set_result("DC-1", pass_fail(ok, detail))
	state.status = (ok and "PASS" or "FAIL") .. " DC-1"
	state.hint = detail
end

local function tick_en1(job)
	local snap = snap_pe()
	if (state.normal_hits or 0) > (job.n0 or 0) then
		local ok = (state.display_hits or 0) == (job.d0 or 0)
		local detail = string.format(
			"normal_hits %s→%s display=%s offer=%s",
			tostring(job.n0),
			tostring(state.normal_hits),
			tostring(state.display_hits),
			tostring(snap.normal_offer_count)
		)
		set_result("EN-1", pass_fail(ok, detail))
		state.status = (ok and "PASS" or "FAIL") .. " EN-1"
		finish_job()
		return
	end
	job.wait = (job.wait or 0) - 1
	if job.wait <= 0 then
		set_result("EN-1", pass_fail(false, "timeout waiting normal encounter"))
		finish_job()
	end
end

local function tick_en2(job)
	if job.phase == "wait_base" then
		if (state.normal_hits or 0) > (job.n0 or 0) then
			job.n1 = state.normal_hits
			local pickup = find_by_seed(job.seed)
			morph_cycle(pickup, ITEM_B)
			job.phase = "after_cycle"
			job.wait = 45
			state.hint = "Cycle settle..."
			return
		end
	elseif job.phase == "after_cycle" then
		if (job.wait or 0) < 30 then
			local ok = (state.normal_hits or 0) == (job.n1 or 0)
			local detail = string.format("hits after cycle=%s (base=%s)", tostring(state.normal_hits), tostring(job.n1))
			set_result("EN-2", pass_fail(ok, detail))
			finish_job()
			return
		end
	end
	job.wait = (job.wait or 0) - 1
	if job.wait <= 0 then
		set_result("EN-2", pass_fail(false, "timeout phase=" .. tostring(job.phase)))
		finish_job()
	end
end

local function tick_en3(job)
	if job.phase == "wait_base" then
		if (state.normal_hits or 0) > (job.n0 or 0) then
			job.n1 = state.normal_hits
			use_d6()
			job.phase = "after_d6"
			job.wait = 60
			return
		end
	elseif job.phase == "after_d6" then
		if (state.normal_hits or 0) > (job.n1 or 0) then
			set_result("EN-3", pass_fail(true, string.format("hits %s→%s→%s", tostring(job.n0), tostring(job.n1), tostring(state.normal_hits))))
			finish_job()
			return
		end
	end
	job.wait = (job.wait or 0) - 1
	if job.wait <= 0 then
		set_result("EN-3", pass_fail(false, "timeout phase=" .. tostring(job.phase)))
		finish_job()
	end
end

local function tick_en4(job)
	if (job.wait or 0) < 20 then
		local ok = (state.normal_hits or 0) == (job.n0 or 0)
		set_result("EN-4", pass_fail(ok, string.format("normal_hits=%s (expect no bump)", tostring(state.normal_hits))))
		finish_job()
		return
	end
	job.wait = (job.wait or 0) - 1
	if job.wait <= 0 then
		local ok = (state.normal_hits or 0) == (job.n0 or 0)
		set_result("EN-4", pass_fail(ok, "timeout"))
		finish_job()
	end
end

local function tick_dc4(job)
	if (state.normal_hits or 0) > (job.n0 or 0) then
		local ok = (state.display_hits or 0) == (job.d0 or 0)
		set_result("DC-4", pass_fail(ok, string.format("normal bumped; display=%s", tostring(state.display_hits))))
		finish_job()
		return
	end
	job.wait = (job.wait or 0) - 1
	if job.wait <= 0 then
		set_result("DC-4", pass_fail(false, "timeout"))
		finish_job()
	end
end

local function tick_dc3(job)
	if (state.normal_hits or 0) > (job.n0 or 0) then
		local ok = (state.display_hits or 0) == (job.d0 or 0)
		set_result("DC-3", pass_fail(ok, string.format("normal bumped; display unchanged=%s", tostring(ok))))
		finish_job()
		return
	end
	job.wait = (job.wait or 0) - 1
	if job.wait <= 0 then
		set_result("DC-3", pass_fail(false, "timeout"))
		finish_job()
	end
end

table.insert(lab.ToCall, #lab.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		local job = state.job
		if not job then return end
		if job.kind == "en1" then
			tick_en1(job)
		elseif job.kind == "en2" then
			tick_en2(job)
		elseif job.kind == "en3" then
			tick_en3(job)
		elseif job.kind == "en4" then
			tick_en4(job)
		elseif job.kind == "dc4" then
			tick_dc4(job)
		elseif job.kind == "dc3" then
			tick_dc3(job)
		end
	end,
})

function lab.build_report()
	local snap = snap_pe()
	local lines = {
		"=== Pedestal Encounter Regression ===",
		"",
		string.format("in_dc=%s normal_serial=%s display_serial=%s", tostring(snap.in_dc_dimension), tostring(snap.normal_serial), tostring(snap.dc_display_serial)),
		string.format("lab normal_hits=%s display_hits=%s", tostring(state.normal_hits), tostring(state.display_hits)),
		"",
	}
	local order = { "EN-1", "EN-2", "EN-3", "EN-4", "DC-1", "DC-3", "DC-4" }
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
	lines[#lines + 1] = "Manual: DC-2/5/6/7/8/9 — see codex_work/notes/pedestal_encounter_holder.md"
	return table.concat(lines, "\n")
end

function lab.get_status_text()
	return table.concat({
		"status: " .. tostring(state.status),
		"hint: " .. tostring(state.hint),
		"",
		lab.build_report(),
	}, "\n")
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
	state.normal_hits = 0
	state.display_hits = 0
	state.status = "Idle"
	state.hint = ""
	pe.reset_debug()
end

return lab
