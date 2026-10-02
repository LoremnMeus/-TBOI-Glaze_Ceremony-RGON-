-- Greed Bank Branch: dual interaction zones + savings/loan panels.
-- Registered via slots/Slot_Bank_Branch.lua thin adapter.

local enums = require("Qing_Remaster_scripts.core.enums")
local selection_holder = require("Qing_Remaster_scripts.others.selection_holder")
local bank_state = require("Qing_Remaster_scripts.threads.bank.bank_state")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")

local branch = {
	ToCall = {},
	myToCall = {},
	entity = nil, -- filled by install()
	own_key = "Slot_Bank_Branch_",
	SELECTION_KEY = "Bank_Branch_Panel",
	-- When true, MC_INPUT_ACTION must not suppress the Input.* peek we are doing.
	_reading_input = false,
}

local SAVING_OFFSET = Vector(-42, 30)
local LOAN_OFFSET = Vector(42, 30)
local INTERACT_RADIUS = 26
local AMOUNT_CHOICES = {1, 5, 10, "all"}

local DATA_KEY = "BankBranchSession"
local BUSY_KEY = "BankBusyPlayerHash"

-- Runtime only (not BankRun): panels wiped on room/level change.
local runtime = {
	sessions = {}, -- [player_hash] = session table mirror for cleanup without GetData
	cleanup_generation = 0,
}

local CLEANUP_GEN_KEY = "BankBranchCleanupGen"

local function lang_zh()
	return Options and Options.Language ~= "en"
end

local function tr(zh, en)
	return lang_zh() and zh or en
end

local function player_hash(player)
	local ok, h = pcall(GetPtrHash, player)
	return ok and h or nil
end

local function branch_ptr(ent)
	local ok, h = pcall(GetPtrHash, ent)
	return ok and h or nil
end

local function get_session(player)
	if not player then return nil end
	local ok, d = pcall(function() return player:GetData() end)
	if not ok or type(d) ~= "table" then return nil end
	return d[DATA_KEY]
end

local function set_session(player, sess)
	if not player then return end
	local ok, d = pcall(function() return player:GetData() end)
	if not ok or type(d) ~= "table" then return end
	d[DATA_KEY] = sess
	local h = player_hash(player)
	if h then runtime.sessions[h] = sess end
end

local function clear_session(player)
	if player then
		local ok, d = pcall(function() return player:GetData() end)
		if ok and type(d) == "table" then
			d[DATA_KEY] = nil
		end
		local h = player_hash(player)
		if h then runtime.sessions[h] = nil end
	end
end

function branch.scrub_runtime()
	-- Boundary-safe: only clear module Lua. Never touch Player:GetData() here.
	runtime.sessions = {}
	runtime.cleanup_generation = (runtime.cleanup_generation or 0) + 1
end

local function flush_player_boundary_cleanup(player)
	if not player then return end
	local ok, d = pcall(function() return player:GetData() end)
	if not ok or type(d) ~= "table" then return end
	local gen = runtime.cleanup_generation or 0
	if (d[CLEANUP_GEN_KEY] or 0) == gen then return end
	d[CLEANUP_GEN_KEY] = gen
	selection_holder.remove_select(player, branch.SELECTION_KEY)
	d[DATA_KEY] = nil
	local h = player_hash(player)
	if h then runtime.sessions[h] = nil end
	pcall(function()
		if player:IsHoldingItem() then
			player:AnimateCollectible(0, "HideItem", "PlayerPickup")
		end
	end)
end

function branch.install(item_table)
	branch.entity = item_table.entity or enums.Slots.Bank_Branch
	item_table.ToCall = item_table.ToCall or {}
	item_table.myToCall = item_table.myToCall or {}
	branch.ToCall = item_table.ToCall
	branch.myToCall = item_table.myToCall
	branch._wire_callbacks()
	return item_table
end

--- Prefer Greed lower-exit Trapdoor; Stairs only as fallback. Pressure plates are not exits.
function branch.find_exit_anchor(room)
	room = room or Game():GetRoom()
	if not room then return Game():GetRoom():GetCenterPos() end
	local center = room:GetCenterPos()
	local best_trap, best_trap_score = nil, nil
	local best_other, best_other_score = nil, nil
	for i = 0, room:GetGridSize() - 1 do
		local grid = room:GetGridEntity(i)
		if grid then
			local t = grid:GetType()
			local pos = grid.Position
			local score = pos.Y * 2 - math.abs(pos.X - center.X)
			if t == GridEntityType.GRID_TRAPDOOR then
				if best_trap_score == nil or score > best_trap_score then
					best_trap_score = score
					best_trap = pos
				end
			elseif t == GridEntityType.GRID_STAIRS then
				if best_other_score == nil or score > best_other_score then
					best_other_score = score
					best_other = pos
				end
			end
		end
	end
	local best = best_trap or best_other
	if best then
		return Vector(best.X, best.Y - 80)
	end
	return Vector(center.X, center.Y + 80)
end

function branch.find_greed_trapdoor_pos(room)
	room = room or Game():GetRoom()
	if not room then return nil end
	local center = room:GetCenterPos()
	local best, best_score = nil, nil
	for i = 0, room:GetGridSize() - 1 do
		local grid = room:GetGridEntity(i)
		if grid and grid:GetType() == GridEntityType.GRID_TRAPDOOR then
			local pos = grid.Position
			local score = pos.Y * 2 - math.abs(pos.X - center.X)
			if best_score == nil or score > best_score then
				best_score = score
				best = pos
			end
		end
	end
	return best
end

function branch.get_savings_zone(ent)
	return ent.Position + SAVING_OFFSET
end

function branch.get_loan_zone(ent)
	return ent.Position + LOAN_OFFSET
end

function branch.is_closed(ent)
	if not ent then return false end
	local d = ent:GetData()
	return d.BankClosed == true
end

function branch.set_closed(ent, closed)
	if not ent then return end
	ent:GetData().BankClosed = closed == true
	local s = ent:GetSprite()
	if closed then
		if s:GetAnimation() ~= "Idle" then s:Play("Idle", true) end
		s.Color = Color(0.45, 0.45, 0.55, 1, 0, 0, 0)
	else
		s.Color = Color(1, 1, 1, 1, 0, 0, 0)
		if s:GetAnimation() ~= "Idle" then s:Play("Idle", true) end
	end
end

function branch.is_broken(ent)
	return ent and ent:GetData().BankBroken == true
end

function branch.find_nearest(player, max_dist)
	max_dist = max_dist or 220
	if not branch.entity then return nil end
	local best, best_d = nil, max_dist
	for _, ent in ipairs(Isaac.FindByType(branch.entity.Type, branch.entity.Variant, -1, false, false)) do
		if ent and ent:Exists() and not branch.is_broken(ent) then
			local d = player.Position:Distance(ent.Position)
			if d < best_d then
				best_d = d
				best = ent
			end
		end
	end
	return best
end

function branch.spawn(pos, state)
	state = state or "open"
	if not branch.entity then return nil end
	pos = pos or branch.find_exit_anchor()
	local ent = Isaac.Spawn(branch.entity.Type, branch.entity.Variant, 0, pos, Vector.Zero, nil)
	ent:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
	local s = ent:GetSprite()
	s:Play("Idle", true)
	if state == "closed" then
		branch.set_closed(ent, true)
	else
		branch.set_closed(ent, false)
	end
	local b = bank_state.get()
	ent:GetData().BankCycleId = b.branch.current_cycle_id
	return ent
end

local function resolve_zone(player, ent)
	local s_pos = branch.get_savings_zone(ent)
	local l_pos = branch.get_loan_zone(ent)
	local ds = player.Position:Distance(s_pos)
	local dl = player.Position:Distance(l_pos)
	local in_s = ds <= INTERACT_RADIUS
	local in_l = dl <= INTERACT_RADIUS
	if in_s and in_l then
		return ds <= dl and "saving" or "loan"
	end
	if in_s then return "saving" end
	if in_l then return "loan" end
	return nil
end

-- Same pattern as slots/slot_offer_lift.lua: peek must bypass our own MC_INPUT_ACTION block.
local function peek_action(player, action)
	if not player then return false, false end
	branch._reading_input = true
	local ctrl = player.ControllerIndex or 0
	local triggered = Input.IsActionTriggered(action, ctrl)
	local pressed = Input.IsActionPressed(action, ctrl)
	branch._reading_input = false
	return triggered, pressed
end

local function peek_triggered(player, action)
	local trig = peek_action(player, action)
	return trig == true
end

local function peek_pressed(player, action)
	local _, held = peek_action(player, action)
	return held == true
end

local function panel_keys_held(player)
	local actions = {
		ButtonAction.ACTION_ITEM,
		ButtonAction.ACTION_DROP,
		ButtonAction.ACTION_MENUCONFIRM,
		ButtonAction.ACTION_LEFT,
		ButtonAction.ACTION_RIGHT,
		ButtonAction.ACTION_UP,
		ButtonAction.ACTION_DOWN,
		ButtonAction.ACTION_SHOOTLEFT,
		ButtonAction.ACTION_SHOOTRIGHT,
		ButtonAction.ACTION_SHOOTUP,
		ButtonAction.ACTION_SHOOTDOWN,
		ButtonAction.ACTION_BOMB,
	}
	for _, a in ipairs(actions) do
		if peek_pressed(player, a) then return true end
	end
	return false
end

local function release_busy(ent, player)
	if not ent then return end
	local d = ent:GetData()
	local h = player_hash(player)
	if d[BUSY_KEY] ~= nil and (h == nil or d[BUSY_KEY] == h) then
		d[BUSY_KEY] = nil
	end
end

local function try_claim_busy(ent, player)
	local d = ent:GetData()
	local h = player_hash(player)
	if d[BUSY_KEY] == nil then
		d[BUSY_KEY] = h
		return true
	end
	return d[BUSY_KEY] == h
end

local function stop_lift(player)
	pcall(function()
		if player:IsHoldingItem() then
			player:AnimateCollectible(0, "HideItem", "PlayerPickup")
		end
	end)
end

local function refresh_loan_lift(player, sess)
	if not sess or sess.mode ~= "loan" then return end
	if sess.page ~= "pick" and sess.page ~= "replace" then
		stop_lift(player)
		return
	end
	local list = sess.candidates or {}
	local row = list[sess.cursor]
	if not row then
		stop_lift(player)
		return
	end
	pcall(function()
		player:AnimateCollectible(row.id, "LiftItem", "PlayerPickup")
	end)
end

function branch.close_panel(player)
	local sess = get_session(player)
	if not sess then return end
	selection_holder.remove_select(player, branch.SELECTION_KEY)
	stop_lift(player)
	if sess.branch_ptr then
		for _, ent in ipairs(Isaac.FindByType(branch.entity.Type, branch.entity.Variant, -1, false, false)) do
			if branch_ptr(ent) == sess.branch_ptr then
				release_busy(ent, player)
				break
			end
		end
	end
	clear_session(player)
end

local function open_panel(player, ent, mode)
	if not try_claim_busy(ent, player) then
		return false
	end
	bank_state.check_collateral()
	local loan = bank_state.get_active_loan()
	local sess = {
		branch_ptr = branch_ptr(ent),
		zone = mode,
		state = "panel",
		mode = mode == "saving" and "saving" or "loan",
		page = "root",
		cursor = 1,
		input_armed = false,
		opened_frame = Game():GetFrameCount(),
		candidates = nil,
	}
	if sess.mode == "loan" then
		if loan and loan.payment_due then
			sess.page = "due"
		elseif loan and loan.secured == false then
			sess.page = "missing"
		elseif loan then
			sess.page = "manage"
		else
			sess.page = "pick"
			sess.candidates = bank_state.list_collateral_candidates(player)
			if #sess.candidates == 0 then
				sess.page = "empty"
			end
		end
	end
	set_session(player, sess)
	selection_holder.try_select(player, branch.SELECTION_KEY)
	refresh_loan_lift(player, sess)
	return true
end

local function menu_options(sess)
	if sess.mode == "saving" then
		if sess.page == "root" then
			return {"deposit", "withdraw", "exit"}
		end
		if sess.page == "deposit" or sess.page == "withdraw" then
			return AMOUNT_CHOICES
		end
	else
		if sess.page == "due" then
			return {"repay", "forfeit", "exit"}
		end
		if sess.page == "manage" then
			return {"repay", "exit"}
		end
		if sess.page == "missing" then
			return {"repay", "replace", "exit"}
		end
		if sess.page == "pick" or sess.page == "replace" then
			return sess.candidates or {}
		end
		if sess.page == "empty" then
			return {"exit"}
		end
	end
	return {"exit"}
end

local function confirm_saving(player, sess)
	local opts = menu_options(sess)
	local choice = opts[sess.cursor]
	if sess.page == "root" then
		if choice == "deposit" then
			sess.page = "deposit"
			sess.cursor = 1
		elseif choice == "withdraw" then
			sess.page = "withdraw"
			sess.cursor = 1
		elseif choice == "exit" then
			branch.close_panel(player)
		end
		return
	end
	if choice == nil then return end
	local amount
	if choice == "all" then
		if sess.page == "deposit" then
			amount = player:GetNumCoins()
		else
			amount = bank_state.get_deposit()
		end
	else
		amount = tonumber(choice) or 0
	end
	if sess.page == "deposit" then
		bank_state.deposit(player, amount)
	else
		bank_state.withdraw(player, amount)
	end
	sess.page = "root"
	sess.cursor = 1
end

local function confirm_loan(player, sess)
	local opts = menu_options(sess)
	local choice = opts[sess.cursor]
	if sess.page == "pick" then
		local row = choice
		if type(row) == "table" and row.id then
			bank_state.issue_loan(player, row.id)
			branch.close_panel(player)
		end
		return
	end
	if sess.page == "replace" then
		local row = choice
		if type(row) == "table" and row.id then
			bank_state.replace_collateral(player, row.id)
			sess.page = "manage"
			sess.cursor = 1
			sess.candidates = nil
			stop_lift(player)
		end
		return
	end
	if choice == "repay" then
		local ok = bank_state.repay_loan(player)
		if ok then branch.close_panel(player) end
		return
	end
	if choice == "forfeit" then
		bank_state.forfeit_collateral(player)
		branch.close_panel(player)
		return
	end
	if choice == "replace" then
		sess.page = "replace"
		sess.candidates = bank_state.list_replacement_candidates(player)
		sess.cursor = 1
		refresh_loan_lift(player, sess)
		return
	end
	if choice == "exit" then
		branch.close_panel(player)
	end
end

local function tick_panel(player, sess)
	if Game():IsPaused() then return end
	if Game():GetFrameCount() <= (sess.opened_frame or 0) then return end
	if not selection_holder.check_select(player, branch.SELECTION_KEY) then
		branch.close_panel(player)
		return
	end
	if not sess.input_armed then
		if not panel_keys_held(player) then
			sess.input_armed = true
		end
		return
	end
	local opts = menu_options(sess)
	local n = #opts
	if n < 1 then n = 1 end

	local function move(delta)
		sess.cursor = ((sess.cursor - 1 + delta) % n) + 1
		refresh_loan_lift(player, sess)
	end

	if sess.page == "pick" or sess.page == "replace" then
		if peek_triggered(player, ButtonAction.ACTION_SHOOTLEFT)
			or peek_triggered(player, ButtonAction.ACTION_LEFT) then
			move(-1)
		elseif peek_triggered(player, ButtonAction.ACTION_SHOOTRIGHT)
			or peek_triggered(player, ButtonAction.ACTION_RIGHT) then
			move(1)
		end
	else
		if peek_triggered(player, ButtonAction.ACTION_SHOOTUP)
			or peek_triggered(player, ButtonAction.ACTION_UP) then
			move(-1)
		elseif peek_triggered(player, ButtonAction.ACTION_SHOOTDOWN)
			or peek_triggered(player, ButtonAction.ACTION_DOWN) then
			move(1)
		end
	end

	if peek_triggered(player, ButtonAction.ACTION_DROP) then
		if sess.mode == "saving" and (sess.page == "deposit" or sess.page == "withdraw") then
			sess.page = "root"
			sess.cursor = 1
			return
		end
		if sess.mode == "loan" and sess.page == "replace" then
			sess.page = "missing"
			sess.cursor = 1
			sess.candidates = nil
			stop_lift(player)
			return
		end
		branch.close_panel(player)
		return
	end

	if peek_triggered(player, ButtonAction.ACTION_ITEM)
		or peek_triggered(player, ButtonAction.ACTION_MENUCONFIRM) then
		if sess.mode == "saving" then
			confirm_saving(player, sess)
		else
			confirm_loan(player, sess)
		end
	end
end

function branch.tick_interaction(player)
	flush_player_boundary_cleanup(player)

	local sess = get_session(player)
	if sess and sess.state == "panel" then
		tick_panel(player, sess)
		return
	end

	local ent = branch.find_nearest(player)
	if not ent then
		if sess then clear_session(player) end
		return
	end

	local zone = resolve_zone(player, ent)
	if not zone then
		if sess and sess.state == "prompt" then clear_session(player) end
		return
	end

	if branch.is_closed(ent) then
		set_session(player, {
			branch_ptr = branch_ptr(ent),
			zone = zone,
			state = "closed_hint",
		})
		return
	end

	local busy = ent:GetData()[BUSY_KEY]
	local h = player_hash(player)
	if busy ~= nil and busy ~= h then
		set_session(player, {
			branch_ptr = branch_ptr(ent),
			zone = zone,
			state = "busy_hint",
		})
		return
	end

	set_session(player, {
		branch_ptr = branch_ptr(ent),
		zone = zone,
		state = "prompt",
	})

	if peek_triggered(player, ButtonAction.ACTION_ITEM) then
		open_panel(player, ent, zone)
	end
end

function branch.bank_font()
	if Options and Options.Language == "en" then
		return gui.f
	end
	return gui.f2 or gui.f
end

local function draw_rect_outline(x, y, w, h, col)
	if not Isaac.DrawLine then return end
	col = col or KColor(0.85, 0.75, 0.45, 1)
	local a = Vector(x, y)
	local b = Vector(x + w, y)
	local c = Vector(x + w, y + h)
	local d = Vector(x, y + h)
	Isaac.DrawLine(a, b, col, col, 1)
	Isaac.DrawLine(b, c, col, col, 1)
	Isaac.DrawLine(c, d, col, col, 1)
	Isaac.DrawLine(d, a, col, col, 1)
end

local function draw_zone_marker(world_pos, label, active)
	if not world_pos then return end
	local screen = Isaac.WorldToScreen(world_pos)
	local half = 16
	local col = active and KColor(1, 0.92, 0.35, 1) or KColor(0.65, 0.65, 0.7, 0.9)
	draw_rect_outline(screen.X - half, screen.Y - half, half * 2, half * 2, col)
	local font = branch.bank_font()
	if font then
		font:DrawStringScaledUTF8(label, screen.X, screen.Y - 6, 1, 1, col, 0, true)
	end
end

function branch.render_zone_markers(player, ent, active_zone)
	if not ent then return end
	draw_zone_marker(branch.get_savings_zone(ent), tr("储蓄", "Savings"), active_zone == "saving")
	draw_zone_marker(branch.get_loan_zone(ent), tr("贷款", "Loan"), active_zone == "loan")
end

function branch.render_prompt(player)
	local sess = get_session(player)
	local ent = branch.find_nearest(player, 260)
	if ent and (not sess or sess.state ~= "panel") then
		local zone = sess and sess.zone or resolve_zone(player, ent)
		branch.render_zone_markers(player, ent, zone)
	end
	if not sess then return end
	if sess.state ~= "closed_hint" and sess.state ~= "busy_hint" and sess.state ~= "prompt" then
		return
	end
	if not ent then
		ent = branch.find_nearest(player, 260)
	end
	local world
	if ent and sess.zone == "loan" then
		world = branch.get_loan_zone(ent)
	elseif ent then
		world = branch.get_savings_zone(ent)
	else
		world = player.Position
	end
	local screen = Isaac.WorldToScreen(world)
	local font = branch.bank_font()
	if not font then return end
	local text
	if sess.state == "closed_hint" then
		text = tr("支行暂停营业", "Branch closed")
	elseif sess.state == "busy_hint" then
		text = tr("正在办理", "Busy")
	elseif sess.zone == "saving" then
		text = tr("按使用键办理", "Press Item")
	else
		text = tr("按使用键办理", "Press Item")
	end
	-- World hint: scale 1 (readable with project CN font).
	font:DrawStringScaledUTF8(text, screen.X, screen.Y + 18, 1, 1, KColor(1, 1, 1, 1), 0, true)
end

local function build_panel_lines(player, sess)
	local lines = {}
	lines[#lines + 1] = "BANK OF BUM"
	if sess.mode == "saving" then
		lines[#lines + 1] = tr("储蓄", "SAVINGS")
		lines[#lines + 1] = string.format(tr("现金  %d¢", "Cash  %d¢"), player:GetNumCoins())
		lines[#lines + 1] = string.format(tr("存款  %d¢", "Deposit  %d¢"), bank_state.get_deposit())
		lines[#lines + 1] = string.format(tr("下次结算  +%d¢", "Next return  +%d¢"), bank_state.preview_interest())
		lines[#lines + 1] = "────────"
		local opts = menu_options(sess)
		local labels = {
			deposit = tr("存入", "Deposit"),
			withdraw = tr("取出", "Withdraw"),
			exit = tr("返回", "Exit"),
			all = tr("全部", "ALL"),
		}
		for i, opt in ipairs(opts) do
			local mark = (i == sess.cursor) and "> " or "  "
			local label = labels[opt] or (tostring(opt) .. "¢")
			lines[#lines + 1] = mark .. label
		end
	else
		lines[#lines + 1] = tr("贷款", "LOAN")
		local loan = bank_state.get_active_loan()
		if sess.page == "pick" or sess.page == "replace" then
			local row = (sess.candidates or {})[sess.cursor]
			if row then
				lines[#lines + 1] = tr("选择抵押物", "Choose collateral")
				lines[#lines + 1] = "< " .. tostring(row.name or row.id) .. " >"
				lines[#lines + 1] = string.format(tr("估值 %d¢", "Value %d¢"), row.value)
				lines[#lines + 1] = string.format(tr("贷款 %d¢", "Loan %d¢"), row.value)
				lines[#lines + 1] = tr("使用键确认 / RT取消", "Item confirm / Drop cancel")
			else
				lines[#lines + 1] = tr("无可抵押道具", "No collateral")
			end
		elseif sess.page == "due" and loan then
			lines[#lines + 1] = tr("还款到期", "PAYMENT DUE")
			lines[#lines + 1] = string.format("%d¢", loan.remaining or loan.principal or 0)
			local opts = menu_options(sess)
			local labels = {
				repay = tr("偿还", "Repay all"),
				forfeit = tr("放弃抵押物", "Forfeit"),
				exit = tr("返回", "Exit"),
			}
			for i, opt in ipairs(opts) do
				local mark = (i == sess.cursor) and "> " or "  "
				lines[#lines + 1] = mark .. (labels[opt] or tostring(opt))
			end
		elseif sess.page == "missing" and loan then
			lines[#lines + 1] = tr("抵押物缺失", "COLLATERAL MISSING")
			lines[#lines + 1] = string.format(tr("欠款 %d¢", "Due %d¢"), loan.remaining or 0)
			local opts = menu_options(sess)
			local labels = {
				repay = tr("偿还", "Repay"),
				replace = tr("重新抵押", "Re-collateral"),
				exit = tr("返回", "Exit"),
			}
			for i, opt in ipairs(opts) do
				local mark = (i == sess.cursor) and "> " or "  "
				lines[#lines + 1] = mark .. (labels[opt] or tostring(opt))
			end
		elseif sess.page == "manage" and loan then
			local cfg = Isaac.GetItemConfig():GetCollectible(loan.item_id)
			lines[#lines + 1] = tr("抵押：", "Collateral: ") .. tostring(cfg and cfg.Name or loan.item_id)
			lines[#lines + 1] = string.format(tr("剩余 %d¢", "Remaining %d¢"), loan.remaining or 0)
			local opts = menu_options(sess)
			local labels = {
				repay = tr("偿还", "Repay all"),
				exit = tr("返回", "Exit"),
			}
			for i, opt in ipairs(opts) do
				local mark = (i == sess.cursor) and "> " or "  "
				lines[#lines + 1] = mark .. (labels[opt] or tostring(opt))
			end
		else
			lines[#lines + 1] = tr("无可抵押道具", "No collateral items")
			lines[#lines + 1] = "> " .. tr("返回", "Exit")
		end
	end
	return lines
end

function branch.render_panel(player)
	local sess = get_session(player)
	if not sess or sess.state ~= "panel" then return end
	local font = branch.bank_font()
	if not font then return end
	local lines = build_panel_lines(player, sess)
	local line_h = (font.GetLineHeight and font:GetLineHeight() or 12) + 2
	local pad = 10
	local max_w = 180
	local panel_h = pad * 2 + #lines * line_h
	local screen = gui.GetScreenSize and gui.GetScreenSize() or Vector(480, 270)
	local x = math.floor((screen.X - max_w) * 0.5 + 0.5)
	local y = math.floor((screen.Y - panel_h) * 0.5 + 0.5)
	draw_rect_outline(x, y, max_w, panel_h, KColor(0.9, 0.8, 0.45, 1))
	-- Inner guide line (placeholder chrome).
	draw_rect_outline(x + 2, y + 2, max_w - 4, panel_h - 4, KColor(0.35, 0.3, 0.2, 0.8))
	for i, line in ipairs(lines) do
		local col = KColor(1, 1, 1, 1)
		if line:sub(1, 1) == ">" then
			col = KColor(1, 0.92, 0.35, 1)
		end
		font:DrawStringScaledUTF8(line, x + pad, y + pad + (i - 1) * line_h, 1, 1, col, 0, false)
	end
end

function branch.block_input(player, hook, action)
	if branch._reading_input then
		return nil
	end
	local sess = get_session(player)
	if not sess then return nil end
	if hook ~= InputHook.IS_ACTION_TRIGGERED and hook ~= InputHook.IS_ACTION_PRESSED then
		return nil
	end

	-- Prompt: bank consumes ACTION_ITEM to open; do not fire active item. Bomb stays free.
	if sess.state == "prompt" then
		if action == ButtonAction.ACTION_ITEM
			or action == ButtonAction.ACTION_MENUCONFIRM then
			return false
		end
		return nil
	end

	if sess.state ~= "panel" then return nil end

	-- Panel: bank owns confirm/cancel/nav; block gameplay side effects.
	if action == ButtonAction.ACTION_ITEM
		or action == ButtonAction.ACTION_DROP
		or action == ButtonAction.ACTION_MENUCONFIRM
		or action == ButtonAction.ACTION_BOMB
		or action == ButtonAction.ACTION_LEFT
		or action == ButtonAction.ACTION_RIGHT
		or action == ButtonAction.ACTION_UP
		or action == ButtonAction.ACTION_DOWN
		or action == ButtonAction.ACTION_SHOOTLEFT
		or action == ButtonAction.ACTION_SHOOTRIGHT
		or action == ButtonAction.ACTION_SHOOTUP
		or action == ButtonAction.ACTION_SHOOTDOWN
	then
		return false
	end
	return nil
end

function branch._wire_callbacks()
	local item = branch

	table.insert(item.myToCall, #item.myToCall + 1, {
		CallBack = enums.Callbacks.POST_SLOT_INIT,
		params = nil,
		Function = function(_, ent)
			if not branch.entity or ent.Variant ~= branch.entity.Variant then return end
			local s = ent:GetSprite()
			s:Play("Idle", true)
			if ent:GetData().BankClosed then
				branch.set_closed(ent, true)
			end
		end,
	})

	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE,
		params = nil,
		Function = function(_, player)
			branch.tick_interaction(player)
		end,
	})

	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_PLAYER_RENDER,
		params = nil,
		Function = function(_, player, _offset)
			branch.render_prompt(player)
			branch.render_panel(player)
		end,
	})

	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_INPUT_ACTION,
		params = nil,
		Function = function(_, ent, hook, button)
			if ent == nil then return end
			local player = ent:ToPlayer()
			if not player then return end
			return branch.block_input(player, hook, button)
		end,
	})

	table.insert(item.myToCall, #item.myToCall + 1, {
		CallBack = enums.Callbacks.POST_SLOT_KILL,
		params = nil,
		Function = function(_, ent, _killer)
			if not branch.entity or ent.Variant ~= branch.entity.Variant then return end
			-- Closed / relocated branches are traces only — never rob again.
			if branch.is_closed(ent) then
				ent:GetData().BankRobbed = true
				branch.set_closed(ent, true)
				ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL
				return
			end
			if ent:GetData().BankRobbed then return end
			ent:GetData().BankRobbed = true
			ent:GetData().BankBroken = true
			local player = Game():GetPlayer(0)
			bank_state.rob(player, ent)
			local s = ent:GetSprite()
			s:Play("Teleport", true)
			ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
			s.Color = Color(0.3, 0.3, 0.3, 1, 0, 0, 0)
		end,
	})

	-- Prefer preventing Closed Branch from taking bomb damage at all.
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG,
		params = 6,
		Function = function(_, ent, _amount, _flags, _source, _countdown)
			if not branch.entity or not ent or ent.Variant ~= branch.entity.Variant then return end
			if branch.is_closed(ent) then
				return false
			end
		end,
	})

	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_PRE_SLOT_CREATE_EXPLOSION_DROPS,
		params = nil,
		Function = function(_, slot)
			if not branch.entity or not slot or slot.Variant ~= branch.entity.Variant then return end
			if branch.is_closed(slot) then
				return false
			end
		end,
	})

	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_NEW_ROOM,
		params = nil,
		Function = function()
			branch.scrub_runtime()
			-- Unresolved due loan: leaving a bank node (no branch in this room) forfeits.
			-- Do not touch Player:GetData() on this boundary.
			local loan = bank_state.get_active_loan()
			if loan and loan.payment_due then
				local found = false
				if branch.entity then
					local list = Isaac.FindByType(branch.entity.Type, branch.entity.Variant, -1, false, false)
					found = #list > 0
				end
				if not found then
					bank_state.on_leave_unresolved_due()
				end
			end
		end,
	})

	table.insert(item.myToCall, #item.myToCall + 1, {
		CallBack = enums.Callbacks.POST_CHANGE_COLLECTIBLE,
		params = nil,
		Function = function(_, _player, _id, _diff)
			bank_state.check_collateral()
		end,
	})

	table.insert(item.myToCall, #item.myToCall + 1, {
		CallBack = enums.Callbacks.PRE_NEW_LEVEL,
		params = nil,
		Function = function()
			branch.scrub_runtime()
		end,
	})

	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_GAME_STARTED,
		params = nil,
		Function = function(_, continue)
			branch.scrub_runtime()
			if not continue then
				bank_state.reset()
			end
		end,
	})
end

return branch
