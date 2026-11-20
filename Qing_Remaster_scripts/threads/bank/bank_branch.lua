-- Greed Bank Branch: contact-operated savings/loan panels.
-- Registered via slots/Slot_Bank_Branch.lua thin adapter.

local enums = require("Qing_Remaster_scripts.core.enums")
local selection_holder = require("Qing_Remaster_scripts.others.selection_holder")
local bank_state = require("Qing_Remaster_scripts.threads.bank.bank_state")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local pixel_ui = require("Qing_Remaster_scripts.auxiliary.pixel_ui")
local bank_panel = require("Qing_Remaster_scripts.threads.bank.bank_panel_renderer")
local slot_offer_lift = require("Qing_Remaster_scripts.slots.slot_offer_lift")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local bank_markers = require("Qing_Remaster_scripts.threads.bank.bank_branch_markers")

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
local CONTACT = {size = 32, x = 1.7, y = 0.8, grid = 24, divider = 0, deadzone = 11, release = 5, cooldown = 12, delay = 2}
local PANEL_TWEEN_FRAMES = 10
branch.debug_collision = false
local AMOUNT_CHOICES = {1, 5, 10, "all"}

local DATA_KEY = "BankBranchSession"
local BUSY_KEY = "BankBusyPlayerHash"

-- Runtime only (not BankRun): panels wiped on room/level change.
local runtime = {
	sessions = {}, -- [player_hash] = session table mirror for cleanup without GetData
	contacts = {}, -- [player_hash] = current native contact and its edge latch
	cleanup_generation = 0,
}

local CLEANUP_GEN_KEY = "BankBranchCleanupGen"

local function lang_zh()
	return Options and Options.Language ~= "en"
end

local function tr(zh, en)
	return lang_zh() and zh or en
end

local function play_ui(sfx, vol, pitch)
	if not sfx then return end
	sound_tracker.PlayStackedSound(sfx, vol or 0.45, pitch or 1, false, 0, 1)
end

local function play_scroll()
	play_ui(SoundEffect.SOUND_MENU_SCROLL, 0.45, 1)
end

local function play_open()
	play_ui(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.5, 1)
end

local function play_cancel()
	play_ui(SoundEffect.SOUND_MENU_FLIP_DARK, 0.4, 1)
end

local function play_confirm()
	play_ui(SoundEffect.SOUND_BUTTON_PRESS, 0.55, 1.05)
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
	runtime.contacts = {}
	runtime.cleanup_generation = (runtime.cleanup_generation or 0) + 1
	branch._coin_fly = nil
	branch._resource_fly = nil
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

function branch.contact_settings()
	return CONTACT
end

function branch.contact_debug_text()
	local lines = {}
	for h, c in pairs(runtime.contacts) do
		lines[#lines + 1] = string.format("P%s: %s / %s / %s", tostring(h),
			tostring(c.zone or "center"), c.armed and "ready" or "latched", tostring(c.ptr))
	end
	if #lines == 0 then return "当前无玩家接触 / No contact" end
	return table.concat(lines, "\n")
end

function branch.apply_collision_size(ent)
	if not ent then return end
	ent:SetSize(CONTACT.size, Vector(CONTACT.x, CONTACT.y), CONTACT.grid)
	ent:GetSprite().Offset = Vector(0, 12)
	if ent.SetShadowSize then ent:SetShadowSize(34) end
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
	s.Color = Color(1, 1, 1, 1, 0, 0, 0)
	if closed then
		if s:GetAnimation() ~= "Closed" then s:Play("Closed", true) end
	else
		if s:GetAnimation() ~= "Idle" then s:Play("Idle", true) end
	end
end

function branch.is_broken(ent)
	return ent and ent:GetData().BankBroken == true
end

local function update_broken_branch(ent)
	local data = ent:GetData()
	if not data.BankBroken then return end
	if data.BankBreakPosition then ent.Position = data.BankBreakPosition end
	ent.Velocity = Vector.Zero
	ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	local sprite = ent:GetSprite()
	local age = Game():GetFrameCount() - (data.BankBreakFrame or 0)
	local flash = age < 16 and math.floor(age / 2) % 2 == 0
	for _, name in ipairs({"red", "green"}) do
		local layer = sprite:GetLayer(name)
		if layer then
			layer:SetColor(flash and Color(1, 0.3, 0.2, 1, 0, 0, 0)
				or Color(0.2, 0.12, 0.12, 1, 0, 0, 0))
		end
	end
	for _, name in ipairs({"clerk02", "left_hand", "right_hand"}) do
		local layer = sprite:GetLayer(name)
		if layer then layer:SetColor(Color(1, 1, 1, math.max(0, 1 - age / 8), 0, 0, 0)) end
	end
	local back = sprite:GetLayer("inner_back")
	if back then back:SetColor(Color(0.02, 0.02, 0.02, 1, 0, 0, 0)) end
	local speaker = sprite:GetLayer("speaker")
	if speaker then speaker:SetColor(Color(0.02, 0.02, 0.02, 1, 0, 0, 0)) end
end

local function update_clerk_hands(ent)
	if branch.is_broken(ent) or branch.is_closed(ent) then return end
	local sprite = ent:GetSprite()
	local data = ent:GetData()
	data.BankHandBase = data.BankHandBase or {}
	local frame = Game():GetFrameCount()
	local function smooth(t)
		t = math.max(0, math.min(1, t))
		return t * t * (3 - 2 * t)
	end
	local left = sprite:GetLayer("left_hand")
	if left then
		data.BankHandBase.left = data.BankHandBase.left or left:GetPos()
		local motion = data.BankLeftMotion
		if not motion then
			motion = {from = Vector.Zero, target = Vector.Zero, start = frame, duration = 1}
			data.BankLeftMotion = motion
		end
		local t = smooth((frame - motion.start) / motion.duration)
		local current = motion.from * (1 - t) + motion.target * t
		if frame - motion.start >= motion.duration then
			motion.from = current
			motion.target = Vector((math.random() * 2 - 1) * 1.2, -0.4 - math.random() * 0.9)
			motion.start = frame
			motion.duration = math.random(18, 36)
		end
		left:SetPos(data.BankHandBase.left + current)
	end
	local right = sprite:GetLayer("right_hand")
	if right then
		data.BankHandBase.right = data.BankHandBase.right or right:GetPos()
		local cycle = math.floor(frame / 56)
		if data.BankRightCycle ~= cycle then
			data.BankRightCycle = cycle
			data.BankRightHeight = (math.random() * 2 - 1) * 0.5
			data.BankRightReach = 1.1 + math.random() * 0.5
		end
		local phase = frame % 56
		local reach = data.BankRightReach or 1.3
		local height = data.BankRightHeight or 0
		local x, y
		if phase < 12 then
			local t = smooth(phase / 12)
			x, y = -reach * t, height - 0.7 * t
		elseif phase < 35 then
			local t = smooth((phase - 12) / 23)
			x, y = -reach + 2 * reach * t, height - 0.7
		elseif phase < 44 then
			local t = smooth((phase - 35) / 9)
			x, y = reach * (1 - t), height - 0.7 - 0.8 * t
		else
			local t = smooth((phase - 44) / 12)
			x, y = 0, (height - 1.5) * (1 - t)
		end
		right:SetPos(data.BankHandBase.right + Vector(x, y))
	end
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

function branch.describe_room()
	local out = {}
	if not branch.entity then return out end
	for _, ent in ipairs(Isaac.FindByType(branch.entity.Type, branch.entity.Variant, -1, false, false)) do
		if ent and ent:Exists() then
			local d = ent:GetData()
			out[#out + 1] = {
				ptr = GetPtrHash(ent),
				x = ent.Position.X,
				y = ent.Position.Y,
				closed = branch.is_closed(ent),
				broken = branch.is_broken(ent),
				busy = d.BankBusyPlayerHash ~= nil,
				debug_spawn = d.BankDebugSpawn == true,
				ent = ent,
			}
		end
	end
	return out
end

function branch.mark_debug_spawn(ent)
	if ent then ent:GetData().BankDebugSpawn = true end
	return ent
end

function branch.remove_debug_spawns()
	local n = 0
	for _, row in ipairs(branch.describe_room()) do
		if row.debug_spawn and row.ent and row.ent:Exists() then
			row.ent:Remove()
			n = n + 1
		end
	end
	return n
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
	return ent
end

local function contact_zone(player, ent)
	local dx = player.Position.X - ent.Position.X - CONTACT.divider
	if dx < -CONTACT.deadzone then return "saving" end
	if dx > CONTACT.deadzone then return "loan" end
	return "center"
end

function branch.record_contact(player, ent)
	if not player or not ent or not branch.entity or ent.Variant ~= branch.entity.Variant then return end
	if branch.is_broken(ent) then return end
	local h, ptr = player_hash(player), branch_ptr(ent)
	if not h or not ptr then return end
	local c = runtime.contacts[h]
	if not c or c.ptr ~= ptr then
		c = {ptr = ptr, armed = true, entered = Game():GetFrameCount(), last = -100, zone = nil}
		runtime.contacts[h] = c
	end
	c.last = Game():GetFrameCount()
	c.ent = ent
	c.zone = contact_zone(player, ent)
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

local function close_keys_held(player)
	return peek_pressed(player, ButtonAction.ACTION_ITEM)
		or peek_pressed(player, ButtonAction.ACTION_DROP)
		or peek_pressed(player, ButtonAction.ACTION_MENUCONFIRM)
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

local function play_branch_state(ptr, name)
	if not ptr or not branch.entity then return end
	for _, ent in ipairs(Isaac.FindByType(branch.entity.Type, branch.entity.Variant, -1, false, false)) do
		if branch_ptr(ent) == ptr then
			if branch.is_broken(ent) then name = "Broken"
			elseif branch.is_closed(ent) then name = "Closed" end
			local sprite = ent:GetSprite()
			if sprite:GetAnimation() ~= name then sprite:Play(name, true) end
			return
		end
	end
end

local start_resource_fly

function branch.close_panel(player, silent)
	local sess = get_session(player)
	if not sess then return end
	if sess.state == "closing" then return end
	if not silent and sess.state == "panel" then
		play_cancel()
	end
	selection_holder.remove_select(player, branch.SELECTION_KEY)
	if sess.state == "panel" then
		sess.state = "closing"
		sess.closed_frame = Game():GetFrameCount()
		return
	end
	branch.finish_close(player, sess)
end

function branch.finish_close(player, sess)
	if sess.mode == "saving" and (sess.coin_delta or 0) ~= 0 then
		local delta = sess.coin_delta
		start_resource_fly(player, sess, "coin", delta < 0, nil, math.abs(delta))
		sess.coin_delta = 0
	end
	for _, fly in ipairs(branch._resource_fly or {}) do
		if fly.pending and fly.owner == player_hash(player) then fly.pending = false end
	end
	if sess.branch_ptr then
		play_branch_state(sess.branch_ptr, "Idle")
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
	play_branch_state(branch_ptr(ent), mode == "saving" and "Saving" or "Loan")
	bank_state.check_collateral()
	local loan = bank_state.get_active_loan()
	local sess = {
		branch_ptr = branch_ptr(ent),
		zone = mode,
		state = "panel",
		opened_frame = Game():GetFrameCount(),
		mode = mode == "saving" and "saving" or "loan",
		page = "root",
		cursor = 1,
		input_armed = false,
		coin_delta = 0,
		candidates = nil,
		loan_ui = nil,
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
			sess.loan_ui = {
				phase = "browse",
				focus_index = 1,
				selected_item_id = nil,
				page = 1,
				confirm_cursor = 1,
			}
			if #sess.candidates == 0 then
				sess.page = "empty"
				sess.loan_ui = nil
			end
		end
	end
	set_session(player, sess)
	selection_holder.try_select(player, branch.SELECTION_KEY)
	play_open()
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
			local loan = bank_state.get_active_loan()
			-- LEGACY-SAVE-008: old loans still allow the original same-floor repayment menu.
			return loan and not loan.held_by_bank and {"repay", "exit"} or {"exit"}
		end
		if sess.page == "missing" then
			return {"repay", "replace", "exit"}
		end
		if sess.page == "pick" or sess.page == "replace" then
			return {"confirm_loan", "reselect", "back"}
		end
		if sess.page == "empty" then
			return {"exit"}
		end
	end
	return {"exit"}
end

local SUCCESS_FRAMES = 8
local FLY_STEPS = 36

local function set_feedback(sess, kind, message, then_mode, silent)
	if kind == "error" then
		play_ui(SoundEffect.SOUND_THUMBS_DOWN, 0.5, 0.95)
		return
	end
	sess.feedback = {
		kind = kind,
		message = message,
		started_frame = Game():GetFrameCount(),
	}
	sess.feedback_then = then_mode
	sess.input_armed = false
	if silent then return end
	play_ui(SoundEffect.SOUND_CASH_REGISTER, 0.55, 1)
end

local function finish_feedback(player, sess)
	local then_mode = sess.feedback_then
	sess.feedback = nil
	sess.feedback_then = nil
	sess.input_armed = false
	if then_mode == "close" then
		branch.close_panel(player, true)
		return
	end
	if then_mode == "root" then
		sess.page = "root"
		sess.cursor = 1
	elseif then_mode == "manage" then
		sess.page = "manage"
		sess.cursor = 1
		sess.candidates = nil
	end
end

local function money_message(page, all, amount, reason)
	if reason == nil then
		if page == "deposit" then
			if all then return tr(string.format("已存入全部 %d¢", amount), string.format("Deposited all %d¢", amount)) end
			return tr(string.format("已存入 %d¢", amount), string.format("Deposited %d¢", amount))
		end
		if all then return tr(string.format("已取出全部 %d¢", amount), string.format("Withdrew all %d¢", amount)) end
		return tr(string.format("已取出 %d¢", amount), string.format("Withdrew %d¢", amount))
	end
	if reason == "coin_cap" then
		return tr("硬币已达上限，无法足额取出", "Not enough room for the full withdrawal")
	end
	if page == "deposit" then
		if all or reason == "bad_amount" then
			return tr("没有可存入的硬币", "No coins to deposit")
		end
		return tr("硬币不足", "Not enough coins")
	end
	if all or reason == "bad_amount" then
		return tr("银行没有存款", "The bank has no deposit")
	end
	return tr("存款不足", "Not enough in the bank")
end

local function loan_fail_message(reason)
	if reason == "coin_cap" then
		return tr("硬币已达上限，无法足额发放贷款", "Not enough room for the full loan")
	end
	if reason == "loan_exists" then
		return tr("已有贷款", "A loan is already open")
	end
	if reason == "headquarters" then
		return tr("此处无法办理贷款", "Loans are not issued here")
	end
	return tr("无有效抵押品", "No valid collateral")
end

local function spawn_loan_fly(player)
	local metrics = bank_panel.metrics and bank_panel.metrics() or nil
	local start = Vector(240, 96)
	if metrics and metrics.x and metrics.y then
		start = Vector(metrics.x + 36, metrics.y + 56)
	end
	local target = slot_offer_lift.get_pickup_hud_screen_pos(player, "coin", 0)
	branch._coin_fly = {
		sprite = slot_offer_lift.make_creditor_hud_fly_sprite("coin"),
		start = start,
		target = target,
		step = 0,
	}
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_PENNYPICKUP, 0.9, 1, false, 0, 1)
end

local function branch_marker_screen(sess, kind)
	local marker = bank_markers[kind]
	if not marker or not sess or not sess.branch_ptr then return nil end
	for _, ent in ipairs(Isaac.FindByType(branch.entity.Type, branch.entity.Variant, -1, false, false)) do
		if branch_ptr(ent) == sess.branch_ptr then
			-- PSD marker offsets are sprite-local render pixels, not world units.
			return Isaac.WorldToScreen(ent.Position + ent.PositionOffset)
				+ ent:GetSprite().Offset + Vector(marker.x, marker.y)
		end
	end
	return nil
end

local function coin_fly_sprite(value)
	if value >= 25 then
		local sprite = Sprite()
		sprite:Load("gfx/ui/collectible_icon_centered.anm2", true)
		sprite:ReplaceSpritesheet(0, value == 100
			and "gfx/items/collectibles/collectibles_018_adollar.png"
			or "gfx/items/collectibles/collectibles_074_aquarter.png")
		sprite:LoadGraphics()
		sprite:Play("Idle", true)
		sprite.Scale = Vector(0.55, 0.55)
		return sprite
	end
	local path = value == 10 and "gfx/005.023_dime.anm2"
		or value == 5 and "gfx/005.022_nickel.anm2" or "gfx/005.021_penny.anm2"
	local sprite = Sprite()
	sprite:Load(path, true)
	sprite:Play("Idle", true)
	sprite:SetFrame(0)
	sprite.Scale = Vector(0.5, 0.5)
	return sprite
end

local function coin_denominations(amount)
	local values = {}
	local remaining = math.floor(math.max(0, amount or 0))
	for _, value in ipairs({100, 25, 10, 5, 1}) do
		while remaining >= value do
			values[#values + 1] = value
			remaining = remaining - value
		end
	end
	return values
end

start_resource_fly = function(player, sess, kind, outward, item_id, coin_count)
	local marker = branch_marker_screen(sess, kind)
	if not marker then return end
	local player_screen = Isaac.WorldToScreen(player.Position + Vector(0, -20))
	local hud = Game():GetHUD()
	local coin_target = hud and hud:IsVisible()
		and slot_offer_lift.get_pickup_hud_screen_pos(player, "coin", 0) or nil
	local target = coin_target or player_screen
	local coins = kind == "coin" and coin_denominations(coin_count or 1) or nil
	local visible = coins and #coins or 1
	if visible == 0 then return end
	branch._resource_fly = branch._resource_fly or {}
	for i = 1, visible do
		local sprite
		if kind == "coin" then
			sprite = coin_fly_sprite(coins[i])
		elseif item_id then
			local cfg = Isaac.GetItemConfig():GetCollectible(item_id)
			if cfg and cfg.GfxFileName and cfg.GfxFileName ~= "" then
				sprite = Sprite()
				sprite:Load("gfx/ui/collectible_icon_centered.anm2", true)
				sprite:ReplaceSpritesheet(0, cfg.GfxFileName)
				sprite:LoadGraphics()
				sprite:Play("Idle", true)
				sprite.Scale = Vector(0.7, 0.7)
			end
		end
		if not sprite then return end
		local spread = visible > 1 and (i - (visible + 1) / 2) or 0
		branch._resource_fly[#branch._resource_fly + 1] = {
			sprite = sprite, start = outward and marker + Vector(spread * 3, -math.abs(spread) * 1.5) or player_screen,
			target = outward and (kind == "coin" and target or player_screen) or marker,
			outward = outward,
			step = -(i - 1) * 2,
			pending = true, owner = player_hash(player),
		}
	end
end

local function fly_ease(t)
	t = math.max(0, math.min(1, t))
	return t * t * (3 - 2 * t)
end

local function resource_fly_position(fly)
	local age = math.max(0, fly.step)
	if fly.outward then
		local raised = fly.start + Vector(0, -29)
		if age < 12 then return fly.start + (raised - fly.start) * fly_ease(age / 12) end
		if age < 20 then return raised end
		return raised + (fly.target - raised) * fly_ease((age - 20) / 22)
	end
	local raised = fly.start + Vector(0, -31)
	local above_target = fly.target + Vector(0, -27)
	if age < 12 then return fly.start + (raised - fly.start) * fly_ease(age / 12) end
	if age < 19 then return raised end
	if age < 35 then return raised + (above_target - raised) * fly_ease((age - 19) / 16) end
	if age < 42 then return above_target end
	return above_target + (fly.target - above_target) * fly_ease((age - 42) / 11)
end

local function tick_coin_fly()
	for i = #(branch._resource_fly or {}), 1, -1 do
		local fly = branch._resource_fly[i]
		if not fly.pending then
			fly.step = fly.step + 1
			if fly.step > (fly.outward and 42 or 53) then table.remove(branch._resource_fly, i) end
		end
	end
	local fly = branch._coin_fly
	if not fly then return end
	fly.step = (fly.step or 0) + 1
	if fly.step >= FLY_STEPS then
		branch._coin_fly = nil
	end
end

local function render_coin_fly()
	for _, fly in ipairs(branch._resource_fly or {}) do
		if not fly.pending and fly.step >= 0 then
			fly.sprite:Render(resource_fly_position(fly), Vector.Zero, Vector.Zero)
		end
	end
	local fly = branch._coin_fly
	if not fly or not fly.sprite or not fly.start or not fly.target then return end
	local t = math.min(1, (fly.step or 0) / FLY_STEPS)
	local eased = 1 - (1 - t) ^ 3
	local pos = fly.start * (1 - eased) + fly.target * eased
	fly.sprite:Render(pos, Vector(0, 0), Vector(0, 0))
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
	local ok, reason
	if sess.page == "deposit" then
		ok, reason = bank_state.deposit(player, amount)
	else
		ok, reason = bank_state.withdraw(player, amount)
	end
	if not ok then
		sess.inline_error = {message = money_message(sess.page, choice == "all", amount, reason or "bad_amount"), started_frame = Game():GetFrameCount()}
		sess.input_armed = false
		play_ui(SoundEffect.SOUND_THUMBS_DOWN, 0.5, 0.95)
		return
	end
	sess.inline_error = nil
	sess.input_armed = false
	sess.coin_delta = (sess.coin_delta or 0) + (sess.page == "withdraw" and -amount or amount)
	play_ui(sess.page == "deposit" and SoundEffect.SOUND_COIN_INSERT
		or SoundEffect.SOUND_PENNYPICKUP, 0.65, 1)
end

local GRID_COLS = 4
local GRID_PAGE = 16

local function ensure_loan_ui(sess)
	local count = #(sess.candidates or {})
	local ui = sess.loan_ui
	if type(ui) ~= "table" then
		ui = {
			phase = "browse",
			focus_index = 1,
			selected_item_id = nil,
			page = 1,
			confirm_cursor = 1,
		}
		sess.loan_ui = ui
	end
	if count < 1 then
		ui.focus_index = 1
	elseif ui.focus_index < 1 then
		ui.focus_index = 1
	elseif ui.focus_index > count then
		ui.focus_index = count
	end
	ui.page = math.floor((ui.focus_index - 1) / GRID_PAGE) + 1
	if ui.phase ~= "confirm" then ui.phase = "browse" end
	if (ui.confirm_cursor or 1) < 1 then ui.confirm_cursor = 1 end
	if ui.confirm_cursor > 3 then ui.confirm_cursor = 3 end
	return ui
end

local function find_candidate(list, item_id)
	if not item_id then return nil end
	for _, row in ipairs(list or {}) do
		if row.id == item_id then return row end
	end
	return nil
end

local function move_collateral_focus(ui, count, dx, dy)
	if count < 1 then return end
	local old = ui.focus_index or 1
	local index = old
	local local_i = (index - 1) % GRID_PAGE
	local col = local_i % GRID_COLS
	local row = math.floor(local_i / GRID_COLS)
	local page0 = math.floor((index - 1) / GRID_PAGE)
	if dx < 0 then
		if col > 0 then
			index = index - 1
		elseif page0 > 0 then
			index = (page0 - 1) * GRID_PAGE + row * GRID_COLS + GRID_COLS
		end
	elseif dx > 0 then
		if col < GRID_COLS - 1 and index < count then
			index = index + 1
		elseif col == GRID_COLS - 1 then
			local next_index = (page0 + 1) * GRID_PAGE + row * GRID_COLS + 1
			local next_page_first = (page0 + 1) * GRID_PAGE + 1
			if next_index <= count then
				index = next_index
			elseif next_page_first <= count then
				index = next_page_first
			end
		end
	end
	if dy < 0 and row > 0 then
		index = index - GRID_COLS
	elseif dy > 0 then
		local below = index + GRID_COLS
		local page_end = (page0 + 1) * GRID_PAGE
		if row < 3 and below <= count and below <= page_end then
			index = below
		end
	end
	if index < 1 then index = 1 end
	if index > count then index = count end
	ui.focus_index = index
	ui.page = math.floor((index - 1) / GRID_PAGE) + 1
	if index ~= old then play_scroll() end
end

local function leave_collateral(player, sess)
	if sess.page == "replace" then
		sess.page = "missing"
		sess.cursor = 1
		sess.candidates = nil
		sess.loan_ui = nil
		play_cancel()
		return
	end
	branch.close_panel(player)
end

local function replace_fail_message(reason, loan)
	if reason == "value_too_low" then
		local need = loan and (loan.remaining or loan.principal or 0) or 0
		return tr(
			string.format("抵押物价值不足，需至少 %d¢", need),
			string.format("Collateral is too low; at least %d¢ is required", need)
		)
	end
	if reason == "ineligible" then
		return tr("道具不符合抵押资格", "This item cannot be pledged")
	end
	if reason == "no_loan" or reason == "no_player" then
		return tr("当前没有有效贷款", "There is no open loan")
	end
	return tr("交易状态失效", "The trade is no longer valid")
end

local function confirm_selected_collateral(player, sess)
	local ui = ensure_loan_ui(sess)
	local row = find_candidate(sess.candidates, ui.selected_item_id)
	if not row then
		set_feedback(sess, "error", loan_fail_message("ineligible"), nil)
		return
	end
	if sess.page == "replace" then
		local loan_before = bank_state.get_active_loan()
		local ok, reason = bank_state.replace_collateral(player, row.id)
		local loan = bank_state.get_active_loan()
		if not ok then
			set_feedback(sess, "error", replace_fail_message(reason, loan_before), nil)
			return
		end
		if not loan or loan.item_id ~= row.id then
			set_feedback(sess, "error", replace_fail_message("state", loan), nil)
			return
		end
		set_feedback(sess, "success", tr("已更换抵押物", "Collateral replaced"), "manage")
		return
	end
	local ok, reason = bank_state.issue_loan(player, row.id)
	if not ok then
		set_feedback(sess, "error", loan_fail_message(reason), nil)
		return
	end
	start_resource_fly(player, sess, "pact", false, row.id)
	start_resource_fly(player, sess, "coin", true, nil, row.value)
	play_ui(SoundEffect.SOUND_PENNYPICKUP, 0.7, 1)
	set_feedback(sess, "success", tr(string.format("获得贷款 %d¢", row.value or 0), string.format("Loan received %d¢", row.value or 0)), "close", true)
end

local function tick_collateral(player, sess)
	local ui = ensure_loan_ui(sess)
	local count = #(sess.candidates or {})
	local function pressed(a, b)
		return peek_triggered(player, a) or (b and peek_triggered(player, b))
	end
	if ui.phase == "confirm" then
		if pressed(ButtonAction.ACTION_SHOOTUP, ButtonAction.ACTION_UP) then
			local old = ui.confirm_cursor
			ui.confirm_cursor = ((ui.confirm_cursor - 2) % 3) + 1
			if ui.confirm_cursor ~= old then play_scroll() end
		elseif pressed(ButtonAction.ACTION_SHOOTDOWN, ButtonAction.ACTION_DOWN) then
			local old = ui.confirm_cursor
			ui.confirm_cursor = (ui.confirm_cursor % 3) + 1
			if ui.confirm_cursor ~= old then play_scroll() end
		end
		if peek_triggered(player, ButtonAction.ACTION_DROP) then
			ui.phase = "browse"
			ui.selected_item_id = nil
			play_cancel()
			return
		end
		if peek_triggered(player, ButtonAction.ACTION_ITEM)
			or peek_triggered(player, ButtonAction.ACTION_MENUCONFIRM) then
			if ui.confirm_cursor == 2 then
				ui.phase = "browse"
				ui.selected_item_id = nil
				play_cancel()
				return
			end
			if ui.confirm_cursor == 3 then
				leave_collateral(player, sess)
				return
			end
			confirm_selected_collateral(player, sess)
		end
		return
	end
	if pressed(ButtonAction.ACTION_SHOOTLEFT, ButtonAction.ACTION_LEFT) then
		move_collateral_focus(ui, count, -1, 0)
	elseif pressed(ButtonAction.ACTION_SHOOTRIGHT, ButtonAction.ACTION_RIGHT) then
		move_collateral_focus(ui, count, 1, 0)
	elseif pressed(ButtonAction.ACTION_SHOOTUP, ButtonAction.ACTION_UP) then
		move_collateral_focus(ui, count, 0, -1)
	elseif pressed(ButtonAction.ACTION_SHOOTDOWN, ButtonAction.ACTION_DOWN) then
		move_collateral_focus(ui, count, 0, 1)
	end
	if peek_triggered(player, ButtonAction.ACTION_DROP) then
		leave_collateral(player, sess)
		return
	end
	if peek_triggered(player, ButtonAction.ACTION_ITEM)
		or peek_triggered(player, ButtonAction.ACTION_MENUCONFIRM) then
		local row = (sess.candidates or {})[ui.focus_index]
		if not row then return end
		ui.selected_item_id = row.id
		ui.phase = "confirm"
		ui.confirm_cursor = 1
		play_confirm()
	end
end

local function confirm_loan(player, sess)
	local opts = menu_options(sess)
	local choice = opts[sess.cursor]
	if sess.page == "pick" or sess.page == "replace" then
		return
	end
	if choice == "repay" then
		local loan = bank_state.get_active_loan()
		local due = loan and (loan.remaining or loan.principal or 0) or 0
		local ok, reason = bank_state.repay_loan(player)
		if not ok then
			local message = tr("硬币不足", "Not enough coins")
			if reason == "no_loan" or reason == "no_player" then
				message = tr("当前没有有效贷款", "There is no open loan")
			end
			set_feedback(sess, "error", message, nil)
			return
		end
		start_resource_fly(player, sess, "coin", false, nil, due)
		if loan and loan.held_by_bank then
			start_resource_fly(player, sess, "pact", true, loan.item_id)
		end
		set_feedback(sess, "success", tr(string.format("已偿还 %d¢", due), string.format("Repaid %d¢", due)), "close")
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
		sess.loan_ui = {
			phase = "browse",
			focus_index = 1,
			selected_item_id = nil,
			page = 1,
			confirm_cursor = 1,
		}
		return
	end
	if choice == "exit" then
		branch.close_panel(player)
	end
end

local function feedback_limit(sess)
	return SUCCESS_FRAMES
end

local function tick_feedback(player, sess)
	local age = Game():GetFrameCount() - (sess.feedback.started_frame or 0)
	local expired = age >= feedback_limit(sess)
	if not sess.input_armed then
		if panel_keys_held(player) then return end
		sess.input_armed = true
		if expired then finish_feedback(player, sess) end
		return
	end
	local dismiss = peek_triggered(player, ButtonAction.ACTION_ITEM)
		or peek_triggered(player, ButtonAction.ACTION_MENUCONFIRM)
		or peek_triggered(player, ButtonAction.ACTION_DROP)
	if expired or dismiss then
		finish_feedback(player, sess)
	end
end

local function tick_panel(player, sess)
	if Game():IsPaused() then return end
	if Game():GetFrameCount() <= (sess.opened_frame or 0) then return end
	if Game():GetFrameCount() - (sess.opened_frame or 0) < PANEL_TWEEN_FRAMES then return end
	if not selection_holder.check_select(player, branch.SELECTION_KEY) then
		branch.close_panel(player)
		return
	end
	if sess.feedback then
		tick_feedback(player, sess)
		return
	end
	if sess.inline_error and Game():GetFrameCount() - sess.inline_error.started_frame >= 24 then
		sess.inline_error = nil
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
		local old = sess.cursor
		sess.cursor = ((sess.cursor - 1 + delta) % n) + 1
		if sess.cursor ~= old then play_scroll() end
	end

	if sess.page == "pick" or sess.page == "replace" then
		tick_collateral(player, sess)
		return
	end
	if peek_triggered(player, ButtonAction.ACTION_SHOOTUP)
		or peek_triggered(player, ButtonAction.ACTION_UP) then
		move(-1)
	elseif peek_triggered(player, ButtonAction.ACTION_SHOOTDOWN)
		or peek_triggered(player, ButtonAction.ACTION_DOWN) then
		move(1)
	end

	if peek_triggered(player, ButtonAction.ACTION_DROP) then
		if sess.mode == "saving" and (sess.page == "deposit" or sess.page == "withdraw") then
			sess.page = "root"
			sess.cursor = 1
			play_cancel()
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
	local main = Game():GetPlayer(0)
	if player and main and GetPtrHash(player) == GetPtrHash(main) then
		tick_coin_fly()
	end
	flush_player_boundary_cleanup(player)

	local sess = get_session(player)
	if sess and sess.state == "closing" then
		if Game():GetFrameCount() - (sess.closed_frame or 0) >= PANEL_TWEEN_FRAMES
			and not close_keys_held(player) then
			branch.finish_close(player, sess)
		end
		return
	end
	if sess and sess.state == "panel" then
		tick_panel(player, sess)
		return
	end
	local h = player_hash(player)
	local c = h and runtime.contacts[h]
	if not c then return end
	local ent = c.ent
	local frame = Game():GetFrameCount()
	local expired = frame - c.last > 2
	if ent and ent:Exists() then
		local dx = (player.Position.X - ent.Position.X) / CONTACT.x
		local dy = (player.Position.Y - ent.Position.Y) / CONTACT.y
		local distance = math.sqrt(dx * dx + dy * dy)
		if expired and distance > CONTACT.size + player.Size + CONTACT.release then
			runtime.contacts[h] = nil
			if sess and sess.state ~= "panel" then clear_session(player) end
			return
		end
	else
		runtime.contacts[h] = nil
		return
	end
	-- The collision callback can report only the entry contact. Keep that pending
	-- contact until the player actually moves clear of the release boundary.
	if not c.armed or not c.zone or (c.zone == "center" and c.center_greeted)
		or frame - (c.entered or frame) < CONTACT.delay
		or frame - (c.triggered or -100) < CONTACT.cooldown then return end
	if branch.is_closed(ent) then
		c.armed = false
		c.triggered = frame
		set_session(player, {branch_ptr = c.ptr, zone = c.zone, state = "closed_hint"})
	elseif ent:GetData()[BUSY_KEY] and ent:GetData()[BUSY_KEY] ~= h then
		c.armed = false
		c.triggered = frame
		set_session(player, {branch_ptr = c.ptr, zone = c.zone, state = "busy_hint"})
	elseif c.zone == "center" then
		c.center_greeted = true
		gui.draw_ch_with_time_to_dispair(ent.Position + Vector(-54, -50), Vector(0, -28),
			tr("欢迎光临！储蓄请往左，贷款请往右。", "Welcome! Savings left, loans right."), 75)
	else
		if open_panel(player, ent, c.zone) then
			c.armed = false
			c.triggered = frame
		end
	end
end

function branch.bank_font()
	if Options and Options.Language == "en" then
		return gui.f
	end
	return gui.f2 or gui.f
end

local function draw_zone_marker(world_pos, kind, label, active)
	if not world_pos then return end
	-- World point only. Do not add the player render offset or PositionOffset.
	local screen = Isaac.WorldToScreen(world_pos)
	bank_panel.draw_zone_icon(screen, kind, active)
	local font = branch.bank_font()
	if not font then return end
	local col = active and KColor(1, 0.92, 0.55, 1) or KColor(0.85, 0.78, 0.62, 1)
	pixel_ui.draw_text_centered(screen.X, screen.Y + 4, label, 1, col, {font = font, context = "bank_zone"})
end

function branch.render_zone_markers(player, ent, active_zone)
	if not ent then return end
	draw_zone_marker(branch.get_savings_zone(ent), "saving", tr("储蓄", "Savings"), active_zone == "saving")
	draw_zone_marker(branch.get_loan_zone(ent), "loan", tr("贷款", "Loan"), active_zone == "loan")
end

function branch.render_prompt(player)
	local sess = get_session(player)
	if not sess then return end
	if sess.state ~= "closed_hint" and sess.state ~= "busy_hint" then
		return
	end
	local ent = branch.find_nearest(player, 260)
	if not ent then
		ent = branch.find_nearest(player, 260)
	end
	local world
	if ent and sess.zone == "center" then
		world = ent.Position + Vector(0, -35)
	elseif ent and sess.zone == "loan" then
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
	end
	-- World hint: scale 1 (readable with project CN font).
	font:DrawStringScaledUTF8(text, screen.X, screen.Y + 18, 1, 1, KColor(1, 1, 1, 1), 0, true)
end

function branch.render_terminal_ui()
	if branch.debug_collision and Isaac.DrawLine then
		for _, row in ipairs(branch.describe_room()) do
			local ent = row.ent
			local color = row.broken and KColor(0.8, 0.2, 0.2, 0.8)
				or KColor(0.3, 1, 0.45, 0.8)
			local previous
			for i = 0, 32 do
				local a = i * math.pi / 16
				local world = ent.Position + Vector(math.cos(a) * CONTACT.size * CONTACT.x,
					math.sin(a) * CONTACT.size * CONTACT.y)
				local screen = Isaac.WorldToScreen(world)
				if previous then Isaac.DrawLine(previous, screen, color, color, 1) end
				previous = screen
			end
		end
	end
	local font = branch.bank_font()
	if not font then return end
	if bank_panel.preview_active() then
		bank_panel.render_preview(font)
		return
	end
	local count = Game():GetNumPlayers()
	for i = 0, count - 1 do
		local player = Isaac.GetPlayer(i)
		local sess = player and get_session(player)
		if sess and (sess.state == "panel" or sess.state == "closing") then
			bank_panel.render(player, sess, font)
			render_coin_fly()
			return
		end
	end
	render_coin_fly()
end

function branch.block_input(player, hook, action)
	if branch._reading_input then
		return nil
	end
	local sess = get_session(player)
	if not sess then return nil end
	if hook ~= InputHook.IS_ACTION_TRIGGERED
		and hook ~= InputHook.IS_ACTION_PRESSED
		and hook ~= InputHook.GET_ACTION_VALUE then
		return nil
	end

	local function deny()
		if hook == InputHook.GET_ACTION_VALUE then return 0 end
		return false
	end

	if sess.state ~= "panel" and sess.state ~= "closing" then return nil end

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
		return deny()
	end
	return nil
end

function branch.debug_sample_item_block(player)
	if not player then return nil end
	local prev = get_session(player)
	local planted = false
	if not prev or prev.state ~= "panel" then
		set_session(player, {state = "panel", mode = "saving", page = "root", cursor = 1, input_armed = false})
		planted = true
	end
	local sample = {
		active = player:GetActiveItem(0),
		planted = planted,
		triggered = branch.block_input(player, InputHook.IS_ACTION_TRIGGERED, ButtonAction.ACTION_ITEM),
		pressed = branch.block_input(player, InputHook.IS_ACTION_PRESSED, ButtonAction.ACTION_ITEM),
		value = branch.block_input(player, InputHook.GET_ACTION_VALUE, ButtonAction.ACTION_ITEM),
	}
	if planted then
		if prev then set_session(player, prev) else clear_session(player) end
	end
	return sample
end

function branch._wire_callbacks()
	local item = branch

	table.insert(item.myToCall, #item.myToCall + 1, {
		CallBack = enums.Callbacks.POST_SLOT_INIT,
		params = nil,
		Function = function(_, ent)
			if not branch.entity or ent.Variant ~= branch.entity.Variant then return end
			branch.apply_collision_size(ent)
			local s = ent:GetSprite()
			s:Play("Idle", true)
			if ent:GetData().BankClosed then
				branch.set_closed(ent, true)
			end
		end,
	})

	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_PLAYER_COLLISION,
		params = nil,
		Function = function(_, player, collider, _low)
			branch.record_contact(player, collider)
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
		end,
	})

	local terminal_render_cb = (REPENTOGON and ModCallbacks.MC_POST_HUD_RENDER) or ModCallbacks.MC_POST_RENDER
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = terminal_render_cb,
		params = nil,
		Function = function(_)
			branch.render_terminal_ui()
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
			ent:GetData().BankBreakPosition = Vector(ent.Position.X, ent.Position.Y)
			ent:GetData().BankBreakFrame = Game():GetFrameCount()
			local player = Game():GetPlayer(0)
			bank_state.rob(player, ent)
			local s = ent:GetSprite()
			s:Play("Broken", true)
			ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
			s.Color = Color(1, 1, 1, 1, 0, 0, 0)
			update_broken_branch(ent)
		end,
	})

	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_UPDATE,
		params = nil,
		Function = function()
			if not branch.entity then return end
			for _, ent in ipairs(Isaac.FindByType(branch.entity.Type, branch.entity.Variant, -1, false, false)) do
				if branch.is_broken(ent) then update_broken_branch(ent) else update_clerk_hands(ent) end
			end
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
			bank_panel.clear_item_sprites()
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
