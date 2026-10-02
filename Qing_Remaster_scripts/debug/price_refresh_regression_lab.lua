-- Price Holder native visual-commit regression (PR-1～PR-6).
-- ImGui → Debug → Tests → Price Refresh Regression
-- Focus: pending VISUAL COMMIT state machine (not full sprite pixels).

local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")

local PRICE_SPIKES = (PickupPrice and PickupPrice.PRICE_SPIKES) or -5

local lab = {
	pre_ToCall = {},
	ToCall = {},
	myToCall = {},
	own_key = "price_refresh_regression_lab_",
}

local state = {
	status = "Idle",
	results = {},
	job = nil,
}

local function pass_fail(ok, detail)
	return {status = ok and "PASS" or "FAIL", detail = detail, ok = ok == true}
end

local function set_result(id, row)
	state.results[id] = row
end

local function spawn_pickup(variant, subtype, price)
	local room = Game():GetRoom()
	local player = Isaac.GetPlayer(0)
	local pos = room:FindFreePickupSpawnPosition(player.Position + Vector(40, 0), 40, true)
	local ent = Isaac.Spawn(
		EntityType.ENTITY_PICKUP,
		variant or PickupVariant.PICKUP_HEART,
		subtype or 1,
		pos,
		Vector.Zero,
		nil
	)
	local p = ent and ent:ToPickup()
	if not p then
		return nil
	end
	p.ShopItemId = -1
	p.AutoUpdatePrice = false
	p.Price = price or PRICE_SPIKES
	price_holder.catch_price_over(p)
	-- Force resolved quote immediately for lab control.
	local d = p:GetData()
	d._Data = d._Data or {}
	local rec = d._Data[price_holder.own_key]
	if rec then
		rec.set_the_price = p.Price
		rec.price = p.Price
		rec.quote_state = "resolved"
		rec.has_price = true
		rec.record_subtype = p.SubType
	end
	consistance_holder.try_hold_entity(p, price_holder.own_key, {ignore_subtype = true})
	return p
end

local function find_by_seed(seed)
	if not seed then
		return nil
	end
	for _, e in ipairs(Isaac.GetRoomEntities()) do
		local p = e:ToPickup()
		if p and p.InitSeed == seed then
			return p
		end
	end
	return nil
end

--- PR-1: schedule after writeback; due_frame = current+1; expected matches Price
local function run_pr1()
	local p = spawn_pickup(PickupVariant.PICKUP_HEART, 1, PRICE_SPIKES)
	if not p then
		set_result("PR-1", pass_fail(false, "spawn failed"))
		return
	end
	local frame = Game():GetFrameCount()
	-- Simulate FINALIZE writeback scheduling
	p.Price = PRICE_SPIKES
	price_holder.debug_clear_visual_commit(p)
	price_holder.debug_schedule_visual_commit(p, PRICE_SPIKES, frame + 1)
	local pending = price_holder.get_pending_visual_commit(p)
	local ok = pending
		and pending.due_frame == frame + 1
		and pending.expected_price == PRICE_SPIKES
		and p.Price == PRICE_SPIKES
		and p.AutoUpdatePrice == false
	set_result("PR-1", pass_fail(ok, string.format(
		"due=%s expect=%s price=%s auto=%s",
		tostring(pending and pending.due_frame),
		tostring(pending and pending.expected_price),
		tostring(p.Price),
		tostring(p.AutoUpdatePrice)
	)))
end

--- PR-2: numeric shop price — commit does not change value
local function run_pr2()
	local p = spawn_pickup(PickupVariant.PICKUP_HEART, 1, 5)
	if not p then
		set_result("PR-2", pass_fail(false, "spawn failed"))
		return
	end
	local before = p.Price
	price_holder.debug_schedule_visual_commit(p, before, Game():GetFrameCount())
	price_holder.debug_try_commit_visual(p)
	local after = p.Price
	local pending = price_holder.get_pending_visual_commit(p)
	local ok = before == 5 and after == 5 and pending == nil
	set_result("PR-2", pass_fail(ok, string.format(
		"before=%s after=%s pending=%s",
		tostring(before),
		tostring(after),
		tostring(pending ~= nil)
	)))
end

--- PR-3: second schedule supersedes first
local function run_pr3()
	local p = spawn_pickup(PickupVariant.PICKUP_HEART, 1, PRICE_SPIKES)
	if not p then
		set_result("PR-3", pass_fail(false, "spawn failed"))
		return
	end
	local frame = Game():GetFrameCount()
	price_holder.debug_schedule_visual_commit(p, -5, frame + 1)
	p.Price = 15
	price_holder.debug_schedule_visual_commit(p, 15, frame + 1)
	local pending = price_holder.get_pending_visual_commit(p)
	local ok = pending and pending.expected_price == 15 and pending.due_frame == frame + 1
	set_result("PR-3", pass_fail(ok, string.format(
		"expected=%s due=%s",
		tostring(pending and pending.expected_price),
		tostring(pending and pending.due_frame)
	)))
end

--- PR-4: Price mismatch / missing entity clears stale commit
local function run_pr4()
	local p = spawn_pickup(PickupVariant.PICKUP_HEART, 1, PRICE_SPIKES)
	if not p then
		set_result("PR-4", pass_fail(false, "spawn failed"))
		return
	end
	local frame = Game():GetFrameCount()
	price_holder.debug_schedule_visual_commit(p, PRICE_SPIKES, frame)
	p.Price = 7 -- mismatch vs expected
	local ran = price_holder.debug_try_commit_visual(p)
	local pending = price_holder.get_pending_visual_commit(p)
	local ok = ran == false and pending == nil and p.Price == 7
	set_result("PR-4", pass_fail(ok, string.format(
		"ran=%s pending=%s price=%s",
		tostring(ran),
		tostring(pending ~= nil),
		tostring(p.Price)
	)))
end

--- PR-5: Price==0 must not commit
local function run_pr5()
	local p = spawn_pickup(PickupVariant.PICKUP_HEART, 1, PRICE_SPIKES)
	if not p then
		set_result("PR-5", pass_fail(false, "spawn failed"))
		return
	end
	price_holder.debug_schedule_visual_commit(p, 0, Game():GetFrameCount())
	p.Price = 0
	local ran = price_holder.debug_try_commit_visual(p)
	local pending = price_holder.get_pending_visual_commit(p)
	local ok = ran == false and pending == nil and p.Price == 0
	set_result("PR-5", pass_fail(ok, string.format(
		"ran=%s pending=%s price=%s",
		tostring(ran),
		tostring(pending ~= nil),
		tostring(p.Price)
	)))
end

--- PR-6: locked quote survives reset_price invalidate; writeback may schedule
local function run_pr6()
	local p = spawn_pickup(PickupVariant.PICKUP_HEART, 1, PRICE_SPIKES)
	if not p then
		set_result("PR-6", pass_fail(false, "spawn failed"))
		return
	end
	price_holder.lock_price(p, PRICE_SPIKES, {
		was_shop_item = true,
	})
	price_holder.debug_schedule_visual_commit(p, PRICE_SPIKES, Game():GetFrameCount() + 5)
	price_holder.reset_price({p})
	local locked = price_holder.is_locked(p)
	local pending = price_holder.get_pending_visual_commit(p)
	-- locked path applies locked price; may clear old pending and re-schedule if wrote
	local ok = locked == true and p.Price == PRICE_SPIKES
	set_result("PR-6", pass_fail(ok, string.format(
		"locked=%s price=%s pending=%s",
		tostring(locked),
		tostring(p.Price),
		tostring(pending and pending.expected_price)
	)))
end

function lab.run_all()
	state.status = "Running"
	run_pr1()
	run_pr2()
	run_pr3()
	run_pr4()
	run_pr5()
	run_pr6()
	local pass, fail = 0, 0
	for _, row in pairs(state.results) do
		if row.ok then
			pass = pass + 1
		else
			fail = fail + 1
		end
	end
	state.status = string.format("Done PASS=%d FAIL=%d", pass, fail)
	return fail == 0
end

function lab.run_pr1() run_pr1() end
function lab.run_pr2() run_pr2() end
function lab.run_pr3() run_pr3() end
function lab.run_pr4() run_pr4() end
function lab.run_pr5() run_pr5() end
function lab.run_pr6() run_pr6() end

function lab.reset_tests()
	state.results = {}
	state.status = "Idle"
	state.job = nil
end

function lab.get_status_text()
	local lines = {
		"Price Refresh Regression",
		"status=" .. tostring(state.status),
	}
	for _, id in ipairs({"PR-1", "PR-2", "PR-3", "PR-4", "PR-5", "PR-6"}) do
		local row = state.results[id]
		if row then
			lines[#lines + 1] = string.format("%s %s — %s", id, row.status, tostring(row.detail or ""))
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
