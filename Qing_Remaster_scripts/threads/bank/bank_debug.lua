-- Bank Branch + HQ debug ImGui (Story Test / Coin).

local imgui_layout = require("Qing_Remaster_scripts.debug.imgui_debug_layout")
local bank_state = require("Qing_Remaster_scripts.threads.bank.bank_state")
local bank_branch = require("Qing_Remaster_scripts.threads.bank.bank_branch")
local bank_rooms = require("Qing_Remaster_scripts.threads.bank.bank_rooms")

local debug = {
	last_action = nil,
}

local function tr(zh, en)
	local language = Options and Options.Language
	return (language == "en") and en or zh
end

local function set_action(ok, msg)
	debug.last_action = string.format("[%s] %s", ok and "OK" or "FAIL", tostring(msg))
end

local function status_text()
	local snap = bank_state.debug_snapshot()
	local lines = {
		tr("银行支行 / 总部调试", "Bank Branch / HQ Debug"),
		"────────────────",
		tr("上次动作：", "Last action: ") .. tostring(debug.last_action or "-"),
		"────────────────",
		tr("周期：", "Cycle: ") .. tostring(snap.cycle_id or "-"),
		tr("上次周期：", "Last cycle: ") .. tostring(snap.last_cycle_id or "-"),
		tr("存款：", "Deposit: ") .. tostring(snap.deposit),
		tr("累计利息：", "Interest earned: ") .. tostring(snap.interest_earned),
		tr("结息次数：", "Deposit cycles: ") .. tostring(snap.deposit_cycles),
		tr("关闭挂起：", "Closed pending: ") .. tostring(snap.closed_pending),
		tr("有贷款：", "Active loan: ") .. tostring(snap.active_loan),
		tr("抵押道具：", "Collateral: ") .. tostring(snap.loan_item or "-"),
		tr("剩余：", "Remaining: ") .. tostring(snap.loan_remaining or "-"),
		tr("Secured：", "Secured: ") .. tostring(snap.secured),
		tr("到期：", "Payment due: ") .. tostring(snap.payment_due),
		tr("没收数：", "Seized: ") .. tostring(snap.seized_count),
		tr("HQ 进入：", "HQ entered: ") .. tostring(snap.hq_entered),
		tr("HQ 结算：", "HQ settled: ") .. tostring(snap.hq_settled),
		tr("存款已领：", "Deposit claimed: ") .. tostring(snap.hq_deposit_claimed),
	}
	return table.concat(lines, "\n")
end

local function goto_hq(id)
	local ok, reason = bank_rooms.enter(id)
	if ok then
		set_action(true, "goto HQ/" .. tostring(id))
	else
		local extra = ""
		if reason == "room_not_loaded" then
			local def = bank_rooms.HQ and bank_rooms.HQ[id]
			extra = tr(
				"。房间未载入，请重新导出 content/rooms/greed/00.special rooms.stb",
				". Room not loaded; re-export content/rooms/greed/00.special rooms.stb"
			)
			if def then
				extra = extra .. string.format(" (variant=%s)", tostring(def.variant))
			end
		end
		set_action(false, "goto HQ/" .. tostring(id) .. " reason=" .. tostring(reason) .. extra)
	end
end

function debug.get_test_descriptor()
	return {
		id = "chapter1.coin",
		title = {zh = "银行 / Bum Emperor", en = "Bank / Bum Emperor"},
		-- Bank can appear on many pre-Mausoleum floors; use current floor as go-to no-op.
		floor_preset = "current",
		start_step = "chapter1.coin.before",
		checkpoints = {
			{step = "chapter1.coin.before", label = {zh = "支行出现前", en = "Before branch"}},
			{step = "chapter1.coin.discover", label = {zh = "支行发现后", en = "After branch discover"}},
			{step = "chapter1.coin.boss", label = {zh = "Boss 战前", en = "Before boss"}},
			{step = "chapter1.coin.complete", label = {zh = "首次完成后", en = "After first clear"}},
			{step = "chapter1.coin.repeat_acquisition", label = {zh = "重复取得素材", en = "Repeat acquisition"}},
		},
		notes = tr(
			"前往测试楼层：银行可用当前任意适用层；也可先手动切层再开始测试。",
			"Go to floor: bank uses current applicable floor; change stage manually then Start Test."
		),
		build_advanced = function(parent_id)
			debug.build_advanced(parent_id)
		end,
	}
end

function debug.build_advanced(parent_id)
	if not ImGui or not parent_id then return end
	local prefix = parent_id .. "_BankBranch"

	ImGui.AddElement(
		parent_id, "", ImGuiElement.SeparatorText or ImGuiElement.Separator,
		tr("银行支行 / 总部沙盒", "Bank Branch / HQ sandbox")
	)

	imgui_layout.add_wrapped_text(parent_id, prefix .. "_Status", "")
	ImGui.AddCallback(prefix .. "_Status", ImGuiCallback.Render, function()
		imgui_layout.update_text(prefix .. "_Status", status_text())
	end)

	ImGui.AddButton(parent_id, prefix .. "_Spawn", tr("生成支行", "Spawn Branch"), function()
		local cycle = bank_state.get().branch.current_cycle_id or "debug_spawn"
		bank_state.on_branch_arrival(cycle, false)
		local ent = bank_branch.spawn(nil, "open")
		if ent then
			set_action(true, "Spawn Branch OK ptr=" .. tostring(GetPtrHash(ent)))
		else
			set_action(false, "Spawn Branch FAILED: branch.entity=" .. tostring(bank_branch.entity ~= nil))
		end
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_SpawnClosed", tr("生成关闭支行", "Spawn Closed"), function()
		local ent = bank_branch.spawn(nil, "closed")
		if ent then
			set_action(true, "Spawn Closed OK ptr=" .. tostring(GetPtrHash(ent)))
		else
			set_action(false, "Spawn Closed FAILED")
		end
	end)

	ImGui.AddButton(parent_id, prefix .. "_DepM10", "-10¢", function()
		local b = bank_state.get()
		b.deposit = math.max(0, b.deposit - 10)
		set_action(true, "deposit=" .. tostring(b.deposit))
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_DepM1", "-1¢", function()
		local b = bank_state.get()
		b.deposit = math.max(0, b.deposit - 1)
		set_action(true, "deposit=" .. tostring(b.deposit))
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_Dep0", "0", function()
		bank_state.get().deposit = 0
		set_action(true, "deposit=0")
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_DepP1", "+1¢", function()
		bank_state.get().deposit = bank_state.get().deposit + 1
		set_action(true, "deposit=" .. tostring(bank_state.get().deposit))
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_DepP10", "+10¢", function()
		bank_state.get().deposit = bank_state.get().deposit + 10
		set_action(true, "deposit=" .. tostring(bank_state.get().deposit))
	end)

	ImGui.AddButton(parent_id, prefix .. "_Interest", tr("结算利息", "Apply Interest"), function()
		local before = bank_state.get().deposit
		bank_state.apply_interest()
		set_action(true, string.format("interest deposit %s -> %s", tostring(before), tostring(bank_state.get().deposit)))
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_NextCycle", tr("下一银行周期", "Next Bank Cycle"), function()
		local ent, cycle, closed = bank_rooms.debug_advance_cycle()
		set_action(
			ent ~= nil,
			string.format("cycle=%s closed=%s entity=%s", tostring(cycle), tostring(closed), tostring(ent ~= nil))
		)
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_AutoSpawn", tr("尝试自动生成", "Try Auto Spawn"), function()
		local ent, reason = bank_rooms.try_auto_spawn_branch()
		if ent then
			set_action(true, "auto spawn OK ptr=" .. tostring(GetPtrHash(ent)))
		else
			set_action(false, "auto spawn: " .. tostring(reason))
		end
	end)

	ImGui.AddButton(parent_id, prefix .. "_ClearLoan", tr("清除贷款", "Clear Loan"), function()
		bank_state.get().active_loan = nil
		set_action(true, "loan cleared")
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_ForceLoan", tr("强制有抵押贷款", "Force Secured Loan"), function()
		local p = Game():GetPlayer(0)
		local list = bank_state.list_collateral_candidates(p)
		if #list <= 0 then
			set_action(false, "ForceLoan: no collateral candidates")
			return
		end
		bank_state.get().active_loan = nil
		local hq = bank_state.get().headquarters
		local was = hq.entered
		hq.entered = false
		local ok = bank_state.issue_loan(p, list[1].id)
		hq.entered = was
		hq.settled = false
		set_action(ok == true, "ForceLoan item=" .. tostring(list[1].id))
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_Missing", tr("强制抵押缺失", "Force Missing"), function()
		local loan = bank_state.get_active_loan()
		if not loan then
			set_action(false, "Force Missing: no active loan")
			return
		end
		local owner = bank_state.resolve_owner(loan)
		if owner and bank_state.collateral_still_present(owner, loan) then
			owner:RemoveCollectible(loan.item_id)
		end
		bank_state.check_collateral()
		set_action(true, "collateral check after force missing")
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_RestoreCol", tr("恢复测试抵押物", "Restore Collateral"), function()
		local loan = bank_state.get_active_loan()
		if not loan or not loan.item_id then
			set_action(false, "Restore: no loan item")
			return
		end
		local owner = bank_state.resolve_owner(loan)
		if not owner then
			set_action(false, "Restore: no owner")
			return
		end
		local need = loan.count_at_issue or 1
		local have = owner:GetCollectibleNum(loan.item_id, true)
		for _ = have + 1, need do
			owner:AddCollectible(loan.item_id, 0, false)
		end
		bank_state.check_collateral()
		set_action(true, "collateral restored item=" .. tostring(loan.item_id))
	end)

	ImGui.AddButton(parent_id, prefix .. "_Rob", tr("抢劫支行", "Rob Branch"), function()
		local p = Game():GetPlayer(0)
		local ent = bank_branch.find_nearest(p, 9999)
		if ent then
			bank_state.rob(p, ent)
			ent:GetData().BankBroken = true
			ent:GetSprite():Play("Teleport", true)
			ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
			set_action(true, "robbed nearest branch")
		else
			bank_state.rob(p, nil)
			set_action(true, "robbed (no branch entity)")
		end
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_Reset", tr("重置 BankRun", "Reset BankRun"), function()
		bank_state.reset()
		set_action(true, "BankRun reset")
	end)

	ImGui.AddElement(
		parent_id, "", ImGuiElement.SeparatorText or ImGuiElement.Separator,
		tr("银行总部 HEADQUARTERS", "HEADQUARTERS")
	)

	local hq_buttons = {
		{ "Ent", "entrance", "入口 Entrance" },
		{ "Main", "main", "大厅 Main" },
		{ "Rec", "records", "账目 Records" },
		{ "Dep", "deposit", "金库 Deposit" },
		{ "Rep", "repossession", "没收库 Repossession" },
		{ "Set", "settlement", "结算 Settlement" },
		{ "Boss", "boss", "Boss" },
		{ "Tre", "treasury", "宝库 Treasury" },
	}
	for i, row in ipairs(hq_buttons) do
		ImGui.AddButton(parent_id, prefix .. "_HQ_" .. row[1], tr(row[3], row[3]), function()
			goto_hq(row[2])
		end)
		if i < #hq_buttons then
			ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
		end
	end

	ImGui.AddButton(parent_id, prefix .. "_AddSeized", tr("添加测试没收品", "Add Seized Test Item"), function()
		local p = Game():GetPlayer(0)
		local list = bank_state.list_collateral_candidates(p)
		local item_id = (list[1] and list[1].id) or CollectibleType.COLLECTIBLE_SAD_ONION
		local d = p and p:GetData()
		bank_state.debug_add_seized(item_id, d and d.__Index)
		set_action(true, "seized item=" .. tostring(item_id))
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_ClearSeized", tr("清空没收品", "Clear Seized Assets"), function()
		bank_state.debug_clear_seized()
		set_action(true, "seized cleared")
	end)

	ImGui.AddButton(parent_id, prefix .. "_EnterHQ", tr("标记进入总部", "Mark HQ Entered"), function()
		bank_state.enter_headquarters()
		set_action(true, "HQ entered marked")
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_SettleHQ", tr("强制 HQ 结算完成", "Force HQ Settled"), function()
		bank_state.get().active_loan = nil
		bank_state.mark_settled()
		set_action(true, "HQ settled")
	end)
	ImGui.AddElement(parent_id, "", ImGuiElement.SameLine)
	ImGui.AddButton(parent_id, prefix .. "_ResetHQ", tr("重置 HQ 状态", "Reset HQ State"), function()
		bank_state.reset_headquarters()
		set_action(true, "HQ state reset")
	end)
end

function debug.build(parent_id)
	debug.build_advanced(parent_id)
end

return debug
