-- Bank Branch debug: story descriptor + Bank Test Lab UI.

local imgui_layout = require("Qing_Remaster_scripts.debug.imgui_debug_layout")
local bank_rooms = require("Qing_Remaster_scripts.threads.bank.bank_rooms")
local tests = require("Qing_Remaster_scripts.threads.bank.bank_debug_tests")
local bank_panel = require("Qing_Remaster_scripts.threads.bank.bank_panel_renderer")
local bank_branch = require("Qing_Remaster_scripts.threads.bank.bank_branch")

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
			local row = tests.goto_greed_exit()
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
			"金融业务测试在 Debug → 系统 → 贪婪银行。这里只保留剧情检查点。",
			"Banking tests are under Debug → Systems → Greed Bank. This page keeps story checkpoints only."
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
	ImGui.AddElement(parent_id, "", ImGuiElement.SeparatorText, "场景与支行")
	button(parent_id, prefix .. "_GreedExit", "前往贪婪出口", tests.goto_greed_exit)
	button(parent_id, prefix .. "_QuickOpen", "生成营业支行", tests.spawn_open)
	button(parent_id, prefix .. "_QuickClosed", "生成停业支行", tests.spawn_closed, true)
	button(parent_id, prefix .. "_Cycle", "模拟下一银行周期", tests.next_cycle)
	button(parent_id, prefix .. "_QuickHQ", "进入银行总部", function() tests.travel("entrance") end, true)
	bind_text(parent_id, prefix .. "_Summary", tests.summary_text)
	bind_text(parent_id, prefix .. "_LastResult", function()
		return tests.last and tostring(tests.last.message) or "尚未执行操作"
	end)
	local scenes = parent_id
	local hq_selected = 0
	local hq_labels = {}
	for _, row in ipairs(HQ) do hq_labels[#hq_labels + 1] = row[2] end
	ImGui.AddCombobox(scenes, prefix .. "_HQSelect", "总部房间", function(index)
		hq_selected = index or 0
	end, hq_labels, 0)
	button(scenes, prefix .. "_HQTravel", "前往所选房间", function()
		local row = HQ[hq_selected + 1]
		if row then tests.travel(row[1]) end
	end)

	ImGui.AddElement(parent_id, "", ImGuiElement.SeparatorText, "金融交易")
	local money = parent_id
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
	button(money, prefix .. "_Dep", "存入", tests.deposit_amount)
	button(money, prefix .. "_Wd", "取出", tests.withdraw_amount, true)
	button(money, prefix .. "_Int", "结算利息", tests.apply_interest)

	local loan = parent_id
	ImGui.AddCombobox(loan, prefix .. "_Col", "抵押道具", function(index)
		tests.collateral_index = index or 0
	end, {"（无合格抵押）"}, 0)
	ImGui.AddCallback(prefix .. "_Col", ImGuiCallback.Render, function()
		local labels = tests.collateral_labels()
		ImGui.UpdateData(prefix .. "_Col", ImGuiData.ListValues, labels)
		if tests.collateral_index >= #labels then tests.collateral_index = 0 end
		ImGui.UpdateData(prefix .. "_Col", ImGuiData.Value, tests.collateral_index)
	end)
	button(loan, prefix .. "_Issue", "抵押贷款", tests.issue_loan)
	button(loan, prefix .. "_Repay", "赎回道具", tests.repay_loan, true)
	button(loan, prefix .. "_Forfeit", "放弃赎回", tests.forfeit)
	button(loan, prefix .. "_Broke", "测试余额不足", tests.repay_when_broke, true)

	ImGui.AddElement(parent_id, "", ImGuiElement.SeparatorText, "外观与交互")
	local tuning = parent_id
	local settings = bank_branch.contact_settings()
	local function integer(id, label, key, lo, hi)
		ImGui.AddDragInteger(tuning, prefix .. id, label, function(value)
			settings[key] = math.max(lo, math.min(hi, value))
			for _, row in ipairs(bank_branch.describe_room()) do
				bank_branch.apply_collision_size(row.ent)
			end
		end, settings[key], 1, lo, hi, "%d")
	end
	integer("_Size", "碰撞 Size", "size", 18, 38)
	integer("_Divider", "横向分界", "divider", -20, 20)
	integer("_Deadzone", "中央死区", "deadzone", 0, 20)
	integer("_Release", "重新触发距离", "release", 0, 20)
	integer("_Cooldown", "接触冷却（帧）", "cooldown", 6, 24)
	integer("_Delay", "接触后延迟（帧）", "delay", 0, 20)
	local function fraction(id, label, key, lo, hi)
		ImGui.AddDragFloat(tuning, prefix .. id, label, function(value)
			settings[key] = math.max(lo, math.min(hi, value))
			for _, row in ipairs(bank_branch.describe_room()) do
				bank_branch.apply_collision_size(row.ent)
			end
		end, settings[key], 0.05, lo, hi, "%.2f")
	end
	fraction("_SizeX", "SizeMulti.X", "x", 1, 2)
	fraction("_SizeY", "SizeMulti.Y", "y", 0.5, 1.5)
	ImGui.AddCheckbox(tuning, prefix .. "_CollisionVisual", "显示碰撞轮廓", function(value)
		bank_branch.debug_collision = value == true
	end, bank_branch.debug_collision)
	bind_text(tuning, prefix .. "_ContactStatus", bank_branch.contact_debug_text)
	bind_text(tuning, prefix .. "_AnimationStatus", function()
		local lines = {}
		for _, row in ipairs(bank_branch.describe_room()) do
			lines[#lines + 1] = string.format("%s: %s", tostring(row.ptr), row.ent:GetSprite():GetAnimation())
		end
		return #lines > 0 and table.concat(lines, "\n") or "当前无支行"
	end)
	local animations = {"Idle", "Saving", "Loan", "Open", "Closed", "Broken"}
	local animation_index = 0
	ImGui.AddCombobox(tuning, prefix .. "_AnimSelect", "支行动画", function(index)
		animation_index = index or 0
	end, animations, 0)
	button(tuning, prefix .. "_AnimPlay", "播放所选动画", function()
		local name = animations[animation_index + 1]
		if name then
			local p = Game():GetPlayer(0)
			local ent = p and bank_branch.find_nearest(p, 9999)
			if ent then ent:GetSprite():Play(name, true) end
		end
	end)

	local preview = parent_id
	local pages = {
		"saving_root", "deposit", "withdraw", "pick", "manage", "due",
	}
	local page_labels = {
		"储蓄首页", "存款金额页", "取款金额页", "选择抵押物", "贷款管理", "还款到期",
	}
	debug._preview = debug._preview or {
		on = false,
		page = 0,
		cash = 99,
		deposit = 40,
		loan = 15,
		name_len = 12,
		bounds = false,
		cursor = 1,
	}
	local state = debug._preview
	ImGui.AddCombobox(preview, prefix .. "_PrevPage", "页面", function(index)
		state.page = index or 0
	end, page_labels, state.page)
	button(preview, prefix .. "_PreviewShow", "预览面板", function() state.on = true end)
	button(preview, prefix .. "_PreviewHide", "关闭预览", function()
		state.on = false
		bank_panel.set_preview(nil)
	end, true)
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
	ImGui.AddCallback(prefix .. "_PrevPage", ImGuiCallback.Render, function()
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
	ImGui.AddElement(parent_id, "", ImGuiElement.SeparatorText, "诊断与清理")
	button(parent_id, prefix .. "_Copy", "复制诊断", tests.copy_log)
	button(parent_id, prefix .. "_Clean", "清理测试支行", tests.cleanup_debug, true)
end

function debug.build(parent_id)
	if not ImGui or not parent_id then return end
	imgui_layout.add_wrapped_text(
		parent_id, parent_id .. "_BankMoved",
		"银行业务测试位于 Debug → 系统 → 贪婪银行。本页只保留剧情进度检查。"
	)
end

function debug.build_thread_tools(parent_id)
	debug.build(parent_id)
end

-- Legacy alias for old callers.
function debug.build_advanced(parent_id)
	debug.build_thread_tools(parent_id)
end

return debug
