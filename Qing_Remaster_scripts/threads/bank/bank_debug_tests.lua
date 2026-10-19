-- Bank Test Lab executor. Assertions and result log only; no business lifecycle.

local bank_state = require("Qing_Remaster_scripts.threads.bank.bank_state")
local bank_branch = require("Qing_Remaster_scripts.threads.bank.bank_branch")
local bank_rooms = require("Qing_Remaster_scripts.threads.bank.bank_rooms")
local bank_panel = require("Qing_Remaster_scripts.threads.bank.bank_panel_renderer")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")

local tests = {
	amount = 10,
	collateral_index = 0,
	log = {},
	last = nil,
}

local HQ_LABEL = {
	entrance = "银行总部入口",
	main = "银行大厅",
	records = "账目室",
	deposit = "存款库",
	repossession = "没收库",
	settlement = "结算室",
	boss = "乞丐皇帝",
	treasury = "银行宝库",
}

local function player()
	return Game():GetPlayer(0)
end

local function tag_of(row)
	if not row then return "-" end
	if row.code == "skip" then return "SKIP" end
	if row.code == "submitted" then return "WAIT" end
	return row.ok and "PASS" or "FAIL"
end

local function push(result)
	result = result or {ok = false, action = "未知", code = "empty", message = "没有结果"}
	tests.last = result
	table.insert(tests.log, 1, result)
	while #tests.log > 30 do
		table.remove(tests.log)
	end
	return result
end

local function result(ok, action, code, message, before, after, checks)
	return push({
		ok = ok == true,
		action = action,
		code = code,
		message = message,
		before = before,
		after = after,
		checks = checks,
	})
end

function tests.set_amount(n)
	n = math.floor(tonumber(n) or 1)
	if n < 1 then n = 1 end
	if n > 999 then n = 999 end
	tests.amount = n
	return n
end

function tests.hq_label(id)
	return HQ_LABEL[id] or tostring(id)
end

function tests.environment_lines()
	local level = Game():GetLevel()
	local room = Game():GetRoom()
	local desc = level:GetCurrentRoomDesc()
	local data = desc and desc.Data
	local greed = Game():IsGreedMode()
	local rows = bank_branch.describe_room()
	local snap = bank_state.debug_snapshot()
	local travel = bank_rooms.travel_state()
	local lines = {
		greed and "游戏模式：贪婪模式（正式环境）" or "游戏模式：普通模式（非正式验收；直接跳转只作沙盒）",
		string.format(
			"当前场景：Stage %s / Type %s / Room %s / Variant %s",
			tostring(level:GetStage()),
			tostring(level:GetStageType()),
			tostring(room and room:GetType() or "-"),
			tostring(data and data.Variant or "-")
		),
		"当前总部房间：" .. tostring(bank_rooms.get_current_id() or "无"),
		string.format("银行支行：%d 个", #rows),
		"总部状态：" .. (snap.hq_entered and "已进入" or "未进入"),
		string.format("存款余额：%s¢", tostring(snap.deposit)),
		snap.active_loan
			and string.format(
				"贷款状态：%s（道具 %s，剩余 %s）",
				snap.payment_due and "已到期" or "未到期",
				tostring(snap.loan_item),
				tostring(snap.loan_remaining)
			)
			or "贷款状态：无",
	}
	if travel and travel.message then
		local phase = travel.phase == "arrived" and "到达成功"
			or (travel.phase == "failed" and "到达失败" or "已提交")
		lines[#lines + 1] = "传送：" .. phase .. " — " .. tostring(travel.message)
	else
		lines[#lines + 1] = "传送：未执行"
	end
	if tests.flash then
		lines[#lines + 1] = "提示：" .. tostring(tests.flash)
	end
	if tests.last then
		lines[#lines + 1] = string.format(
			"上次操作：[%s] %s — %s",
			tag_of(tests.last),
			tostring(tests.last.action),
			tostring(tests.last.message)
		)
	end
	return lines
end

function tests.environment_text()
	return table.concat(tests.environment_lines(), "\n")
end

function tests.refresh_env()
	return result(true, "刷新环境检查", "env", table.concat(tests.environment_lines(), " | "))
end

local function finish_open_travel(code, ok, message)
	local open = tests._open_travel
	if not open or open.closed or not open.log_row then return end
	open.closed = true
	open.log_row.code = code
	open.log_row.ok = ok == true
	open.log_row.message = message
	tests.flash = message
end

function tests.travel(id)
	tests._travel_seq = (tests._travel_seq or 0) + 1
	local request_id = tests._travel_seq
	finish_open_travel("superseded", false, "已被新的传送请求取代，不再等待这次结果。")
	tests._open_travel = nil
	local begun = bank_rooms.begin_travel(id, request_id)
	local label = tests.hq_label(id)
	local action = "前往" .. label
	if begun.phase == "failed" then
		return result(false, action, begun.code or "travel_failed", begun.message)
	end
	if begun.phase == "arrived" then
		local actual = bank_rooms.get_current_id()
		if actual ~= id then
			return result(false, action, "not_arrived", "传送失败：房间标识与目标不一致。")
		end
		return result(true, action, begun.code or "arrived", begun.message)
	end
	local row = result(false, action, "submitted", begun.message or "已提交传送，等待进房核对。")
	row.request_id = request_id
	tests._open_travel = {request_id = request_id, log_row = row, closed = false}
	return row
end

function tests.note_travel_progress()
	local open = tests._open_travel
	if not open or open.closed then return end
	local t = bank_rooms.poll_travel()
	if not t or t.request_id ~= open.request_id then return end
	if t.phase == "arrived" then
		local actual = bank_rooms.get_current_id()
		if actual == t.id then
			finish_open_travel("arrived", true, t.message)
		else
			finish_open_travel("not_arrived", false, "传送失败：已提交指令，但玩家没有进入指定房间。")
		end
	elseif t.phase == "failed" then
		finish_open_travel(t.code or "not_arrived", false, t.message)
	end
end

function tests.check_rooms()
	local rows = bank_rooms.diagnose_room_configs()
	local bad = {}
	for _, row in ipairs(rows) do
		if not row.ok then
			bad[#bad + 1] = string.format("%s(%s)=%s", tests.hq_label(row.id), tostring(row.variant), tostring(row.code))
		end
	end
	if #bad > 0 then
		return result(false, "检查总部房间资源", "room_not_loaded", "未载入：" .. table.concat(bad, "；"))
	end
	return result(true, "检查总部房间资源", "rooms_loaded", "八个总部房间 RoomConfig 均可加载。")
end

local function spawn_at(state)
	local p = player()
	if not p then
		return result(false, "生成支行", "no_player", "没有玩家。")
	end
	local before = #bank_branch.describe_room()
	local pos = p.Position + Vector(70, 0)
	local ent = bank_branch.spawn(pos, state)
	if not ent or not ent:Exists() then
		return result(false, state == "closed" and "生成停业支行" or "生成营业支行", "spawn_failed", "实体没有生成。")
	end
	bank_branch.mark_debug_spawn(ent)
	local closed = bank_branch.is_closed(ent)
	local want_closed = state == "closed"
	local after = #bank_branch.describe_room()
	if closed ~= want_closed or after < before + 1 then
		return result(false, want_closed and "生成停业支行" or "生成营业支行", "state_mismatch", "实体已创建，但营业状态或数量不符合预期。", {count = before}, {count = after, closed = closed})
	end
	local action = want_closed and "生成停业支行" or "生成营业支行"
	return result(true, action, "spawned", string.format("已生成，房间内支行 %d → %d。", before, after), {count = before}, {count = after, closed = closed})
end

function tests.spawn_open()
	return spawn_at("open")
end

function tests.spawn_closed()
	return spawn_at("closed")
end

function tests.try_auto_spawn()
	local ent, reason = bank_rooms.try_auto_spawn_branch()
	if ent and ent:Exists() then
		return result(true, "尝试正常生成", "auto_spawn", "正式条件生成成功，ptr=" .. tostring(GetPtrHash(ent)))
	end
	return result(false, "尝试正常生成", tostring(reason or "failed"), "未生成。原因：" .. tostring(reason))
end

function tests.next_cycle()
	local before = bank_state.get().deposit
	local ent, cycle, closed = bank_rooms.debug_advance_cycle()
	local after = bank_state.get().deposit
	if not ent or not ent:Exists() then
		return result(false, "模拟下一银行周期", "no_entity", "周期已推进，但没有生成支行实体。", {deposit = before}, {deposit = after, cycle = cycle})
	end
	return result(true, "模拟下一银行周期", "cycle", string.format("周期 %s，停业=%s，存款 %s → %s。", tostring(cycle), tostring(closed), tostring(before), tostring(after)), {deposit = before}, {deposit = after, cycle = cycle, closed = closed})
end

function tests.cleanup_debug()
	local n = bank_branch.remove_debug_spawns()
	local left = 0
	for _, row in ipairs(bank_branch.describe_room()) do
		if row.debug_spawn then left = left + 1 end
	end
	if left > 0 then
		return result(false, "清理测试支行", "cleanup_left", "仍有测试支行未被移除。", nil, {removed = n, left = left})
	end
	return result(true, "清理测试支行", "cleanup", string.format("已移除 %d 个测试支行。", n), nil, {removed = n})
end

function tests.branch_text()
	local rows = bank_branch.describe_room()
	if #rows == 0 then return "当前房间没有银行支行。" end
	local lines = {string.format("当前房间银行支行：%d", #rows)}
	for i, row in ipairs(rows) do
		lines[#lines + 1] = string.format(
			"%d. ptr=%s  pos=(%.0f,%.0f)  %s  %s  周期=%s  交互=%s  测试生成=%s",
			i,
			tostring(row.ptr),
			row.x or 0,
			row.y or 0,
			row.closed and "停业" or "营业",
			row.broken and "已破坏" or "完好",
			tostring(row.cycle or "-"),
			row.busy and "进行中" or "无",
			row.debug_spawn and "是" or "否"
		)
	end
	return table.concat(lines, "\n")
end

function tests.break_branch()
	local p = player()
	local ent = p and bank_branch.find_nearest(p, 9999) or nil
	if not ent or not ent:Exists() then
		return result(false, "测试真实支行破坏", "no_entity", "当前房间没有可破坏的支行实体。")
	end
	if bank_branch.is_closed(ent) then
		return result(false, "测试真实支行破坏", "closed", "最近的是停业支行。正式破坏路径不会对它做抢劫结算。")
	end
	if ent:GetData()["Every_Entity_holder_Killed"] == true then
		return result(false, "测试真实支行破坏", "already_killed", "这个支行已经走过击杀。请再生成一个营业支行。")
	end
	local before = bank_state.get().deposit
	local slots = require("Qing_Remaster_scripts.callbacks.every_entity_holder")
	slots.kill_slot(ent, p)
	local data = ent:GetData()
	local anim = ent:GetSprite():GetAnimation()
	local robbed = data.BankRobbed == true
	local broken = data.BankBroken == true
	local hidden = ent.EntityCollisionClass == EntityCollisionClass.ENTCOLL_NONE
	local tele = anim == "Teleport"
	local after = bank_state.get().deposit
	if not (robbed and broken and hidden and tele) then
		return result(false, "测试真实支行破坏", "slot_kill_incomplete", string.format(
			"Slot 击杀后状态不完整：抢劫标记=%s 破坏=%s 无碰撞=%s 动画=%s。",
			tostring(robbed), tostring(broken), tostring(hidden), tostring(anim)
		), {deposit = before}, {deposit = after})
	end
	return result(true, "测试真实支行破坏", "slot_kill", string.format(
		"已走正式 Slot 击杀。动画 Teleport，存款 %s → %s。", tostring(before), tostring(after)
	), {deposit = before}, {deposit = after})
end

function tests.rob_settle()
	local p = player()
	if not p then return result(false, "模拟支行抢劫结算", "no_player", "没有玩家。") end
	local before = bank_state.get().deposit
	local rows_before = #bank_branch.describe_room()
	bank_state.rob(p, nil)
	local after = bank_state.get().deposit
	local broken_n = 0
	for _, row in ipairs(bank_branch.describe_room()) do
		if row.broken then broken_n = broken_n + 1 end
	end
	return result(true, "模拟支行抢劫结算", "rob_ledger", string.format(
		"只调用了账目结算，没有走 Slot 击杀。存款 %s → %s。房间支行 %d，已破坏 %d。",
		tostring(before), tostring(after), rows_before, broken_n
	), {deposit = before}, {deposit = after})
end

local function coin_cap(p)
	if p.HasCollectible and p:HasCollectible(CollectibleType.COLLECTIBLE_DEEP_POCKETS) then
		return 999
	end
	return 99
end

local function transfer(action, amount, direction)
	local p = player()
	if not p then return result(false, action, "no_player", "没有玩家。") end
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then
		return result(false, action, "bad_amount", "金额必须大于 0。")
	end
	local coins_before = p:GetNumCoins()
	local deposit_before = bank_state.get_deposit()
	local before = {coins = coins_before, deposit = deposit_before, amount = amount}
	if direction == "withdraw" and coins_before + amount > coin_cap(p) then
		return result(false, action, "coin_cap", string.format(
			"取出 %d¢ 会超过硬币上限 %d（当前 %d）。这是上限边界，不算提款成功。",
			amount, coin_cap(p), coins_before
		), before, before)
	end
	local ok, reason
	if direction == "deposit" then
		ok, reason = bank_state.deposit(p, amount)
	else
		ok, reason = bank_state.withdraw(p, amount)
	end
	local coins_after = p:GetNumCoins()
	local deposit_after = bank_state.get_deposit()
	local after = {coins = coins_after, deposit = deposit_after, amount = amount}
	if not ok then
		if coins_after ~= coins_before or deposit_after ~= deposit_before then
			return result(false, action, "mutated_on_fail", "交易失败，但硬币或存款发生了变化。", before, after)
		end
		return result(false, action, tostring(reason or "failed"), "交易未完成：" .. tostring(reason), before, after)
	end
	local expect_coins = direction == "deposit" and (coins_before - amount) or (coins_before + amount)
	local expect_deposit = direction == "deposit" and (deposit_before + amount) or (deposit_before - amount)
	if coins_after ~= expect_coins or deposit_after ~= expect_deposit then
		return result(false, action, "amount_mismatch", string.format(
			"请求 %d¢。硬币应为 %d，实际 %d；存款应为 %d，实际 %d。",
			amount, expect_coins, coins_after, expect_deposit, deposit_after
		), before, after)
	end
	return result(true, action, "verified", string.format(
		"请求 %d¢。硬币 %d → %d，存款 %d → %d。",
		amount, coins_before, coins_after, deposit_before, deposit_after
	), before, after)
end

function tests.deposit_amount()
	return transfer("存入指定金额", tests.amount, "deposit")
end

function tests.withdraw_amount()
	return transfer("取出指定金额", tests.amount, "withdraw")
end

function tests.deposit_all()
	local p = player()
	local amount = p and p:GetNumCoins() or 0
	return transfer("全部存入", amount, "deposit")
end

function tests.withdraw_all()
	return transfer("全部取出", bank_state.get_deposit(), "withdraw")
end

function tests.apply_interest()
	local before = bank_state.get_deposit()
	local expect = bank_state.preview_interest(before)
	local gain = bank_state.apply_interest()
	local after = bank_state.get_deposit()
	if before <= 0 then
		if gain ~= 0 or after ~= before then
			return result(false, "结算利息", "zero_mismatch", "零存款仍产生了利息。", {deposit = before}, {deposit = after, gain = gain})
		end
		return result(true, "结算利息", "zero", "存款为 0，利息为 0。", {deposit = before}, {deposit = after, gain = gain})
	end
	if gain ~= expect or after ~= before + expect then
		return result(false, "结算利息", "interest_mismatch", string.format("预期利息 %s，实际 %s。", tostring(expect), tostring(gain)), {deposit = before, expect = expect}, {deposit = after, gain = gain})
	end
	return result(true, "结算利息", "interest", string.format("存款 %s → %s，利息 %s。", tostring(before), tostring(after), tostring(gain)), {deposit = before}, {deposit = after, gain = gain})
end

function tests.inject_deposit(delta)
	local before = bank_state.get_deposit()
	local b = bank_state.get()
	b.deposit = math.max(0, before + delta)
	local after = bank_state.get_deposit()
	return result(true, "注入存款", "inject", string.format("测试注入，不计入真实交易。存款 %s → %s。", tostring(before), tostring(after)), {deposit = before}, {deposit = after})
end

function tests.clear_deposit()
	local before = bank_state.get_deposit()
	bank_state.get().deposit = 0
	local after = bank_state.get_deposit()
	if after ~= 0 then
		return result(false, "清空存款", "inject_failed", "存款没有被清成 0。", {deposit = before}, {deposit = after})
	end
	return result(true, "清空存款", "inject", "测试注入：存款已清零。这不是取款。", {deposit = before}, {deposit = after})
end

function tests.collateral_rows()
	return bank_state.list_collateral_candidates(player())
end

function tests.collateral_labels()
	local rows = tests.collateral_rows()
	if #rows == 0 then return {"（无合格抵押）"} end
	local labels = {}
	for _, row in ipairs(rows) do
		labels[#labels + 1] = string.format("%s  id=%s  价值=%s", tostring(row.name), tostring(row.id), tostring(row.value))
	end
	return labels
end

function tests.selected_collateral()
	local rows = tests.collateral_rows()
	local idx = (tonumber(tests.collateral_index) or 0) + 1
	return rows[idx]
end

function tests.issue_loan()
	local p = player()
	local row = tests.selected_collateral()
	if not p or not row then
		return result(false, "发放贷款", "no_collateral", "没有可选择的合格抵押道具。")
	end
	if bank_state.get_active_loan() then
		return result(false, "发放贷款", "loan_exists", "已有贷款。请先还款，不要把清空表当成发放成功。")
	end
	local coins_before = p:GetNumCoins()
	local ok, reason = bank_state.issue_loan(p, row.id)
	local loan = bank_state.get_active_loan()
	local coins_after = p:GetNumCoins()
	if not ok or not loan or loan.item_id ~= row.id then
		return result(false, "发放贷款", tostring(reason or "issue_failed"), "贷款没有按所选道具建立。", {coins = coins_before}, {coins = coins_after})
	end
	local expect = row.value or 0
	if coins_after ~= coins_before + expect then
		return result(false, "发放贷款", "coin_mismatch", string.format("应到账 %s¢，实际硬币 %s → %s。", tostring(expect), tostring(coins_before), tostring(coins_after)))
	end
	return result(true, "发放贷款", "issued", string.format("抵押 %s，到账 %s¢。", tostring(row.id), tostring(expect)), {coins = coins_before}, {coins = coins_after, item = row.id})
end

function tests.repay_loan()
	local p = player()
	local loan = bank_state.get_active_loan()
	if not loan then
		return result(false, "偿还贷款", "no_loan", "当前没有贷款。")
	end
	local due = loan.remaining or loan.principal or 0
	local coins_before = p:GetNumCoins()
	local ok, reason = bank_state.repay_loan(p)
	local still = bank_state.get_active_loan()
	local coins_after = p:GetNumCoins()
	if not ok then
		if still == nil then
			return result(false, "偿还贷款", "cleared_on_fail", "还款失败，但贷款被清掉了。")
		end
		return result(false, "偿还贷款", tostring(reason), "还款未完成：" .. tostring(reason), {coins = coins_before, due = due}, {coins = coins_after})
	end
	if still ~= nil or coins_after ~= coins_before - due then
		return result(false, "偿还贷款", "repay_mismatch", "贷款状态或扣款与预期不一致。", {coins = coins_before, due = due}, {coins = coins_after, loan = still ~= nil})
	end
	return result(true, "偿还贷款", "repaid", string.format("已还款 %s¢，贷款已清除。", tostring(due)), {coins = coins_before}, {coins = coins_after})
end

function tests.force_due()
	local loan = bank_state.get_active_loan()
	if not loan then return result(false, "模拟下一周期到期", "no_loan", "当前没有贷款。") end
	local cycle = "lab_due_" .. tostring(Game():GetFrameCount())
	local ok, reason = bank_state.on_branch_arrival(cycle, false)
	loan = bank_state.get_active_loan()
	if not ok or not loan or loan.payment_due ~= true then
		return result(false, "模拟下一周期到期", tostring(reason or "not_due"), "周期已调用，但 payment_due 没有变成 true。")
	end
	return result(true, "模拟下一周期到期", "due", "贷款已标记到期。这不是还款。")
end

function tests.force_missing()
	local loan = bank_state.get_active_loan()
	if not loan then return result(false, "移除测试抵押物", "no_loan", "当前没有贷款。") end
	local owner = bank_state.resolve_owner(loan)
	if not owner then return result(false, "移除测试抵押物", "no_owner", "找不到贷款所属玩家。") end
	if bank_state.collateral_still_present(owner, loan) then
		owner:RemoveCollectible(loan.item_id)
	end
	bank_state.check_collateral()
	loan = bank_state.get_active_loan()
	if not loan or loan.secured ~= false then
		return result(false, "移除测试抵押物", "still_secured", "抵押物检查后贷款仍显示有效。")
	end
	return result(true, "移除测试抵押物", "unsecured", "抵押已失效，贷款记录仍在。")
end

function tests.replace_collateral()
	local p = player()
	local loan = bank_state.get_active_loan()
	if not loan then return result(false, "更换抵押物", "no_loan", "当前没有贷款。") end
	local row = tests.selected_collateral()
	if not row then return result(false, "更换抵押物", "no_collateral", "没有可选择的合格抵押道具。") end
	local ok, reason = bank_state.replace_collateral(p, row.id)
	loan = bank_state.get_active_loan()
	if not ok or not loan or loan.item_id ~= row.id then
		return result(false, "更换抵押物", tostring(reason or "replace_failed"), "抵押物没有换成所选道具。")
	end
	return result(true, "更换抵押物", "replaced", "当前抵押道具为 " .. tostring(row.id))
end

function tests.forfeit()
	local before = #(bank_state.get().seized_assets or {})
	local had = bank_state.get_active_loan() ~= nil
	if not had then return result(false, "放弃抵押物", "no_loan", "当前没有贷款。") end
	local ok, reason = bank_state.forfeit_collateral(player())
	local after_loan = bank_state.get_active_loan()
	local after = #(bank_state.get().seized_assets or {})
	if not ok or after_loan ~= nil or after < before then
		return result(false, "放弃抵押物", tostring(reason or "forfeit_failed"), "没收没有完成。", {seized = before}, {seized = after, loan = after_loan ~= nil})
	end
	return result(true, "放弃抵押物", "forfeit", string.format("贷款已清除，没收品 %d → %d。", before, after), {seized = before}, {seized = after})
end

function tests.repay_when_broke()
	local p = player()
	local loan = bank_state.get_active_loan()
	if not loan then return result(false, "余额不足还款", "no_loan", "当前没有贷款，无法验证失败路径。") end
	local due = loan.remaining or 0
	if p:GetNumCoins() >= due then
		return result(false, "余额不足还款", "skip", "SKIP：玩家硬币足够还款，本项未执行。")
	end
	local ok = bank_state.repay_loan(p)
	if ok or bank_state.get_active_loan() == nil then
		return result(false, "余额不足还款", "cleared", "余额不足时贷款被错误清除。")
	end
	return result(true, "余额不足还款", "insufficient_coins", "还款失败，贷款仍在。")
end

function tests.log_text()
	if #tests.log == 0 then return "尚无操作记录。" end
	local lines = {}
	for i, row in ipairs(tests.log) do
		lines[#lines + 1] = string.format(
			"%d. [%s] %s (%s) %s",
			i,
			tag_of(row),
			tostring(row.action),
			tostring(row.code),
			tostring(row.message)
		)
	end
	return table.concat(lines, "\n")
end

function tests.clear_log()
	local keep = nil
	if tests._open_travel and not tests._open_travel.closed then
		keep = tests._open_travel.log_row
	end
	tests.log = {}
	if keep then tests.log[1] = keep end
	tests.last = keep
	tests.flash = keep and "记录已清空。未完成的传送仍保留。" or "记录已清空。"
	return {ok = true, action = "清空结果", code = "cleared", message = tests.flash}
end

function tests.goto_greed_final_boss()
	if not Game():IsGreedMode() then
		return result(false, "前往贪婪最终 Boss 房", "not_greed", "当前不是贪婪模式。不会用切层指令伪装成贪婪。")
	end
	if REPENTOGON then
		Game():ChangeRoom(45)
	else
		Game():GetLevel():ChangeRoom(45)
	end
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local idx = desc and desc.SafeGridIndex
	local room = Game():GetRoom()
	if idx == 45 and room:GetType() == RoomType.ROOM_BOSS then
		return result(true, "前往贪婪最终 Boss 房", "boss_room", "已在贪婪最终 Boss 房（格子 45）。清房后才能出现银行入口。")
	end
	return result(false, "前往贪婪最终 Boss 房", "not_arrived", string.format("已请求格子 45，当前格子是 %s。", tostring(idx)))
end

function tests.check_final_boss_entrance()
	local thread = require("Qing_Remaster_scripts.threads.thread_Coin")
	local info = thread.debug_ensure_bank_entrance()
	if not info.greed then
		return result(false, "检查最终 Boss 银行入口", "not_greed", "当前不是贪婪模式。没有调用切层，也没有生成入口。")
	end
	if not info.matched then
		return result(false, "检查最终 Boss 银行入口", "skip", string.format(
			"SKIP：未满足正式条件（需要贪婪 Stage7、Boss 房、格子 45、已清房）。当前 stage=%s type=%s index=%s clear=%s。",
			tostring(info.stage), tostring(info.room_type), tostring(info.index), tostring(info.clear)
		))
	end
	if not info.present then
		return result(false, "检查最终 Boss 银行入口", "no_door", "条件已满足并调用了正式入口逻辑，但没有登记通往 23509 的门。")
	end
	return result(true, "检查最终 Boss 银行入口", "entrance_door", "正式条件满足，已登记通往银行总部入口（23509）的门。")
end

function tests.copy_log()
	local probe_output = require("Qing_Remaster_scripts.debug.probe_output")
	local ok = probe_output.copy_text(tests.log_text(), "bank_lab")
	if ok == false then
		return result(false, "复制诊断文本", "clipboard", "复制失败。诊断文本仍显示在本页。")
	end
	return result(true, "复制诊断文本", "clipboard", "已复制最近的诊断记录。")
end

function tests.deposit_zero_cash()
	local p = player()
	if not p then return result(false, "零硬币存款", "no_player", "没有玩家。") end
	local cash = p:GetNumCoins()
	local deposit = bank_state.get_deposit()
	if cash > 0 then p:AddCoins(-cash) end
	local ok, reason = bank_state.deposit(p, 10)
	local mid_cash = p:GetNumCoins()
	local mid_deposit = bank_state.get_deposit()
	if cash > 0 then p:AddCoins(cash) end
	local before = {coins = cash, deposit = deposit}
	local after = {coins = mid_cash, deposit = mid_deposit, restored = cash}
	if ok or mid_cash ~= 0 or mid_deposit ~= deposit then
		return result(false, "零硬币存款", tostring(reason), "零硬币时存款仍改变了硬币或余额。", before, after)
	end
	return result(true, "零硬币存款", tostring(reason), string.format(
		"拒绝原因 %s。硬币与存款未变。测试前现金 %d¢ 已恢复。", tostring(reason), cash
	), before, after)
end

function tests.withdraw_zero_deposit()
	local p = player()
	if not p then return result(false, "零存款取款", "no_player", "没有玩家。") end
	local saved = bank_state.get_deposit()
	local coins = p:GetNumCoins()
	bank_state.get().deposit = 0
	local ok, reason = bank_state.withdraw(p, 10)
	local mid_coins = p:GetNumCoins()
	local mid_deposit = bank_state.get_deposit()
	bank_state.get().deposit = saved
	if mid_coins ~= coins then p:AddCoins(coins - mid_coins) end
	local before = {coins = coins, deposit = saved}
	local after = {coins = mid_coins, deposit = mid_deposit, restored = saved}
	if ok or mid_coins ~= coins or mid_deposit ~= 0 then
		return result(false, "零存款取款", tostring(reason), "银行存款为 0 时仍付出了硬币或改了余额。", before, after)
	end
	return result(true, "零存款取款", tostring(reason), string.format(
		"拒绝原因 %s。硬币未增加。原存款 %d¢ 已恢复。", tostring(reason), saved
	), before, after)
end

function tests.loan_rejected()
	local p = player()
	if not p then return result(false, "贷款失败", "no_player", "没有玩家。") end
	local coins = p:GetNumCoins()
	local had = bank_state.get_active_loan() ~= nil
	local ok, reason
	if had then
		local rows = bank_state.list_collateral_candidates(p)
		local id = (rows[1] and rows[1].id) or 1
		ok, reason = bank_state.issue_loan(p, id)
	else
		ok, reason = bank_state.issue_loan(p, 0)
	end
	local after_coins = p:GetNumCoins()
	local expect = had and "loan_exists" or "bad_args"
	if not had and reason == "ineligible" then expect = reason end
	local before = {coins = coins, loan = had}
	local after = {coins = after_coins, reason = reason}
	if ok or after_coins ~= coins or reason ~= expect then
		return result(false, "贷款失败", tostring(reason), string.format(
			"预期拒绝 %s，实际 %s。硬币 %d → %d。", expect, tostring(reason), coins, after_coins
		), before, after)
	end
	return result(true, "贷款失败", tostring(reason), string.format(
		"贷款被拒绝（%s）。硬币保持 %d¢。", tostring(reason), after_coins
	), before, after)
end

function tests.active_key_block()
	local p = player()
	if not p then return result(false, "主动键拦截", "no_player", "没有玩家。") end
	local coins = p:GetNumCoins()
	local sample = bank_branch.debug_sample_item_block(p)
	local after_coins = p:GetNumCoins()
	if not sample then
		return result(false, "主动键拦截", "no_sample", "没有读到拦截抽样。", {coins = coins}, {coins = after_coins})
	end
	local blocked = sample.triggered == false and sample.pressed == false and sample.value == 0
	local detail = string.format(
		"主槽主动道具 %s。triggered=%s pressed=%s value=%s。硬币 %d → %d。这是面板会话下的拦截返回值，仍需在游戏里按使用键确认主动道具没有发动。",
		tostring(sample.active), tostring(sample.triggered), tostring(sample.pressed), tostring(sample.value), coins, after_coins
	)
	local before = {coins = coins, active = sample.active}
	local after = {coins = after_coins, triggered = sample.triggered, pressed = sample.pressed, value = sample.value}
	if not blocked or after_coins ~= coins then
		return result(false, "主动键拦截", "not_blocked", detail, before, after)
	end
	if not sample.active or sample.active <= 0 then
		return result(false, "主动键拦截", "no_active", detail .. " 请先拿起一个主动道具再测。", before, after)
	end
	return result(true, "主动键拦截", "blocked", detail, before, after)
end

function tests.collateral_layout()
	local font = (gui and (gui.f2 or gui.f)) or nil
	if not font or not bank_panel.fit_layout then
		return result(false, "抵押网格高度", "no_font", "没有可用于测量的字体。")
	end
	local screen = Vector(480, 270)
	local sample = {cash = 0, deposit = 0}
	local candidates = {}
	for i = 1, 4 do
		candidates[i] = {id = 1, name = "Item", value = 15}
	end
	local feedback = {kind = "error", message = "硬币已达上限，无法足额发放贷款"}
	local cases = {
		{
			name = "浏览",
			sess = {mode = "loan", page = "pick", candidates = candidates, loan_ui = {phase = "browse", focus_index = 1, page = 1}},
		},
		{
			name = "浏览带反馈",
			sess = {mode = "loan", page = "pick", candidates = candidates, feedback = feedback, loan_ui = {phase = "browse", focus_index = 1, page = 1}},
		},
		{
			name = "确认带反馈",
			sess = {
				mode = "loan", page = "pick", candidates = candidates, feedback = feedback,
				loan_ui = {phase = "confirm", focus_index = 1, page = 1, confirm_cursor = 1, selected_item_id = 1},
			},
		},
	}
	local lines = {}
	local ok = true
	for _, case in ipairs(cases) do
		local measured = bank_panel.fit_layout(case.sess, font, screen, sample, nil)
		local fits = measured and measured.fits == true
		ok = ok and fits
		lines[#lines + 1] = string.format(
			"%s %s/%s %s",
			case.name,
			tostring(measured and measured.outer_h),
			tostring(measured and measured.max_h),
			fits and "装得下" or "超出"
		)
	end
	local message = table.concat(lines, "；")
	if not ok then
		return result(false, "抵押网格高度", "overflow", "270 视口下抵押页超出屏幕。" .. message)
	end
	return result(true, "抵押网格高度", "fits", "270 视口下浏览、带反馈浏览和确认都装得下。" .. message)
end

return tests
