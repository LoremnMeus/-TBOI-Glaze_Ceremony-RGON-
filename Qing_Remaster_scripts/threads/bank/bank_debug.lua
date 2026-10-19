-- Bank Branch debug: story descriptor + Bank Test Lab UI.

local imgui_layout = require("Qing_Remaster_scripts.debug.imgui_debug_layout")
local bank_rooms = require("Qing_Remaster_scripts.threads.bank.bank_rooms")
local tests = require("Qing_Remaster_scripts.threads.bank.bank_debug_tests")
local bank_panel = require("Qing_Remaster_scripts.threads.bank.bank_panel_renderer")

local debug = {}

local function tr(zh, en)
	local language = Options and Options.Language
	return (language == "en") and en or zh
end

local HQ = {
	{"entrance", "前往银行总部入口"},
	{"main", "前往银行大厅"},
	{"records", "前往账目室"},
	{"deposit", "前往存款库"},
	{"repossession", "前往没收库"},
	{"settlement", "前往结算室"},
	{"boss", "前往乞丐皇帝房间"},
	{"treasury", "前往银行宝库"},
}

function debug.get_test_descriptor()
	return {
		id = "chapter1.coin",
		title = {zh = "银行 / Bum Emperor", en = "Bank / Bum Emperor"},
		go_to_test_location = function()
			local row = tests.travel("entrance")
			return row.ok == true or row.code == "submitted", row.message
		end,
		start_step = "chapter1.coin.before",
		checkpoints = {
			{step = "chapter1.coin.before", label = {zh = "支行出现前", en = "Before branch"}},
			{step = "chapter1.coin.discover", label = {zh = "支行发现后", en = "After branch discover"}},
			{step = "chapter1.coin.boss", label = {zh = "Boss 战前", en = "Before boss"}},
			{step = "chapter1.coin.complete", label = {zh = "首次完成后", en = "After first clear"}},
			{step = "chapter1.coin.repeat_acquisition", label = {zh = "重复取得素材", en = "Repeat acquisition"}},
		},
		notes = tr(
			"金融业务测试在 Debug → 测试 → 贪婪银行测试台。这里只保留剧情检查点。前往按钮会直接尝试进入总部入口，并在测试台核对是否真正到达。",
			"Banking mechanics live under Debug → Tests → Bank Test Lab. This page keeps story checkpoints only."
		),
	}
end

local function bind_text(parent_id, element_id, getter)
	imgui_layout.add_wrapped_text(parent_id, element_id, "")
	ImGui.AddCallback(element_id, ImGuiCallback.Render, function()
		tests.note_travel_progress()
		imgui_layout.update_text(element_id, getter())
	end)
end

local function button(parent_id, id, label, fn, same)
	if same then
		ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	end
	ImGui.AddButton(parent_id, id, label, fn)
end

function debug.build_lab(parent_id)
	if not ImGui or not parent_id then return end
	local prefix = parent_id .. "_BankLab"

	imgui_layout.add_wrapped_text(
		parent_id, prefix .. "_Banner",
		"独立运行态调试。不自动推进第一章剧情，也不修改永久剧情进度。普通模式可以沙盒跳转，但不能当作贪婪模式验收。"
	)
	bind_text(parent_id, prefix .. "_Status", tests.environment_text)

	local env = imgui_layout.add_section(parent_id, prefix .. "_Env", "01  环境与快捷传送")
	button(env, prefix .. "_Refresh", "刷新环境检查", tests.refresh_env)
	button(env, prefix .. "_Rooms", "检查总部房间资源", tests.check_rooms, true)
	button(env, prefix .. "_FinalBoss", "前往贪婪最终 Boss 房", tests.goto_greed_final_boss)
	button(env, prefix .. "_FinalDoor", "检查最终 Boss 银行入口", tests.check_final_boss_entrance, true)
	for i, row in ipairs(HQ) do
		local id = row[1]
		button(env, prefix .. "_Go_" .. id, row[2], function()
			tests.travel(id)
		end, i > 1 and (i % 2 == 0))
	end

	local branch = imgui_layout.add_section(parent_id, prefix .. "_Branch", "02  支行生成与检查")
	button(branch, prefix .. "_Open", "生成营业支行", tests.spawn_open)
	button(branch, prefix .. "_Closed", "生成停业支行", tests.spawn_closed, true)
	button(branch, prefix .. "_Auto", "尝试正常生成", tests.try_auto_spawn)
	button(branch, prefix .. "_Cycle", "模拟下一银行周期", tests.next_cycle, true)
	button(branch, prefix .. "_Clean", "清理测试支行", tests.cleanup_debug)
	bind_text(branch, prefix .. "_BranchList", tests.branch_text)
	button(branch, prefix .. "_RobEnt", "测试真实支行破坏", tests.break_branch)
	button(branch, prefix .. "_RobLedger", "模拟支行抢劫结算", tests.rob_settle, true)

	local money = imgui_layout.add_section(parent_id, prefix .. "_Money", "03  存取款与利息")
	local amount_id = prefix .. "_Amount"
	ImGui.AddDragInteger(
		money,
		amount_id,
		"测试金额（硬币）",
		function(value)
			tests.set_amount(value)
		end,
		tests.amount,
		1,
		1,
		999,
		"%d"
	)
	ImGui.AddCallback(amount_id, ImGuiCallback.Render, function()
		ImGui.UpdateData(amount_id, ImGuiData.Value, tests.amount)
	end)
	button(money, prefix .. "_Dep", "存入指定金额", tests.deposit_amount)
	button(money, prefix .. "_Wd", "取出指定金额", tests.withdraw_amount, true)
	button(money, prefix .. "_DepAll", "全部存入", tests.deposit_all)
	button(money, prefix .. "_WdAll", "全部取出", tests.withdraw_all, true)
	button(money, prefix .. "_Int", "结算利息", tests.apply_interest)
	ImGui.AddElement(money, "", ImGuiElement.SeparatorText, "测试状态注入（不计入真实交易）")
	button(money, prefix .. "_InjP", "注入 +10¢", function() tests.inject_deposit(10) end)
	button(money, prefix .. "_InjM", "注入 -10¢", function() tests.inject_deposit(-10) end, true)
	button(money, prefix .. "_Inj0", "清空存款", tests.clear_deposit)

	local loan = imgui_layout.add_section(parent_id, prefix .. "_Loan", "04  抵押贷款")
	ImGui.AddCombobox(loan, prefix .. "_Col", "抵押道具", function(index)
		tests.collateral_index = index or 0
	end, {"（无合格抵押）"}, 0)
	ImGui.AddCallback(prefix .. "_Col", ImGuiCallback.Render, function()
		local labels = tests.collateral_labels()
		ImGui.UpdateData(prefix .. "_Col", ImGuiData.ListValues, labels)
		if tests.collateral_index >= #labels then tests.collateral_index = 0 end
		ImGui.UpdateData(prefix .. "_Col", ImGuiData.Value, tests.collateral_index)
	end)
	button(loan, prefix .. "_Issue", "发放贷款", tests.issue_loan)
	button(loan, prefix .. "_Repay", "偿还贷款", tests.repay_loan, true)
	button(loan, prefix .. "_Due", "模拟下一周期到期", tests.force_due)
	button(loan, prefix .. "_Miss", "移除测试抵押物（会删掉玩家道具）", tests.force_missing, true)
	button(loan, prefix .. "_Replace", "更换抵押物", tests.replace_collateral)
	button(loan, prefix .. "_Forfeit", "放弃抵押物", tests.forfeit, true)
	button(loan, prefix .. "_Broke", "余额不足还款", tests.repay_when_broke)

	local hq = imgui_layout.add_section(parent_id, prefix .. "_HQ", "05  银行总部")
	for i, row in ipairs(HQ) do
		local id = row[1]
		button(hq, prefix .. "_HQ_" .. id, tests.hq_label(id), function()
			tests.travel(id)
		end, i > 1 and (i % 4 ~= 1))
	end

	local log = imgui_layout.add_section(parent_id, prefix .. "_Log", "06  自动验收与日志")
	button(log, prefix .. "_Cfg", "静态检查房间资源", tests.check_rooms)
	button(log, prefix .. "_ClearLog", "清空结果", tests.clear_log, true)
	button(log, prefix .. "_Copy", "复制诊断文本", tests.copy_log)
	bind_text(log, prefix .. "_LogBody", tests.log_text)

	local trade = imgui_layout.add_section(parent_id, prefix .. "_Trade", "08  交易结果与主动键")
	button(trade, prefix .. "_ZeroDep", "零硬币存款", tests.deposit_zero_cash)
	button(trade, prefix .. "_ZeroWd", "零存款取款", tests.withdraw_zero_deposit, true)
	button(trade, prefix .. "_LoanOk", "正常贷款", tests.issue_loan)
	button(trade, prefix .. "_LoanNo", "贷款失败", tests.loan_rejected, true)
	button(trade, prefix .. "_Active", "主动键拦截抽样", tests.active_key_block)
	button(trade, prefix .. "_Layout", "测量 270 视口抵押页", tests.collateral_layout, true)

	local preview = imgui_layout.add_section(parent_id, prefix .. "_Preview", "09  交易面板预览")
	local pages = {
		"saving_root", "deposit", "withdraw", "pick", "manage", "due", "missing",
	}
	local page_labels = {
		"储蓄首页", "存款金额页", "取款金额页", "选择抵押物", "贷款管理", "还款到期", "抵押物缺失",
	}
	debug._preview = debug._preview or {
		on = false,
		page = 0,
		cash = 99,
		deposit = 40,
		loan = 15,
		name_len = 12,
		bounds = false,
		feedback = false,
		cursor = 1,
	}
	local state = debug._preview
	ImGui.AddCheckbox(preview, prefix .. "_PrevOn", "强制显示预览（不办理业务）", function(value)
		state.on = value == true
		if not state.on then bank_panel.set_preview(nil) end
	end, state.on)
	ImGui.AddCombobox(preview, prefix .. "_PrevPage", "页面", function(index)
		state.page = index or 0
	end, page_labels, state.page)
	local function drag(id, label, key, max_value)
		ImGui.AddDragInteger(preview, prefix .. id, label, function(value)
			state[key] = value or 0
		end, state[key], 1, 0, max_value, "%d")
	end
	drag("_PrevCash", "测试现金", "cash", 99999)
	drag("_PrevDep", "测试存款", "deposit", 99999)
	drag("_PrevLoan", "测试待还", "loan", 99999)
	drag("_PrevName", "抵押物名称长度", "name_len", 48)
	ImGui.AddCheckbox(preview, prefix .. "_PrevBox", "显示外框边界", function(value)
		state.bounds = value == true
	end, state.bounds)
	ImGui.AddCheckbox(preview, prefix .. "_PrevFeedback", "附带失败反馈", function(value)
		state.feedback = value == true
	end, state.feedback == true)
	ImGui.AddCallback(prefix .. "_PrevOn", ImGuiCallback.Render, function()
		if not state.on then
			bank_panel.set_preview(nil)
			return
		end
		local n = math.max(1, math.floor(state.name_len or 1))
		local name = string.rep("甲", n)
		bank_panel.set_preview({
			page = pages[(state.page or 0) + 1] or "saving_root",
			cash = state.cash,
			deposit = state.deposit,
			loan_remaining = state.loan,
			item_name = name,
			item_id = 1,
			show_bounds = state.bounds,
			show_feedback = state.feedback == true,
			cursor = state.cursor,
		})
		local metrics = bank_panel.preview_metrics()
		local line = "预览已打开。进入一局后看画面。"
		if metrics then
			line = string.format(
				"外框 %d / 上限 %d  %s",
				metrics.outer_h or 0,
				metrics.max_h or 0,
				metrics.fits and "装得下" or "仍超出"
			)
		end
		imgui_layout.update_text(prefix .. "_PrevStatus", line)
	end)
	imgui_layout.add_wrapped_text(preview, prefix .. "_PrevStatus", "预览关闭")
end

function debug.build(parent_id)
	if not ImGui or not parent_id then return end
	imgui_layout.add_wrapped_text(
		parent_id, parent_id .. "_BankMoved",
		"银行金融业务已移到 Debug → 测试 → 贪婪银行测试台。本页只保留剧情进度检查。"
	)
end

function debug.build_advanced(parent_id)
	debug.build(parent_id)
end

return debug
