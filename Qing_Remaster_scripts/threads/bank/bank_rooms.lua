-- Bank HQ room controller + Phase A branch spawn helpers.
-- Declares HQ room graph, wires grid doors, and drives room-local terminals.

local enums = require("Qing_Remaster_scripts.core.enums")
local save = require("Qing_Remaster_scripts.core.savedata")
local bank_state = require("Qing_Remaster_scripts.threads.bank.bank_state")
local bank_branch = require("Qing_Remaster_scripts.threads.bank.bank_branch")
local grid_door = require("Qing_Remaster_scripts.grids.grid_doors")
local selection_holder = require("Qing_Remaster_scripts.others.selection_holder")
local gate = require("Qing_Remaster_scripts.story.story_runtime_gate")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")

local rooms = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	_reading_input = false,
}

local SELECTION_KEY = "Bank_HQ_Terminal"
local SESSION_KEY = "BankHQSession"
local PROMPT_RADIUS = 40

rooms.MARKER = {
	MAIN = 1,
	RECORDS = 2,
	DEPOSIT = 3,
	REPOSSESSION = 4,
	SETTLEMENT = 5,
	TREASURY = 6,
	ENTRANCE = 7,
}

-- Effect room markers: room XML / BR serialize as 999; runtime is ENTITY_EFFECT (1000).
rooms.MARKER_ROOM_XML_TYPE = 999
rooms.MARKER_RUNTIME_TYPE = EntityType.ENTITY_EFFECT
rooms.ROOM_MARKER_NAME = "Bank Room Marker"

rooms.HQ = {
	entrance = { id = "entrance", variant = 23509, type = 9, shape = 1 },
	main = { id = "main", variant = 23505, type = 9, shape = 4 },
	records = { id = "records", variant = 23504, type = 9, shape = 1 },
	deposit = { id = "deposit", variant = 23506, type = 9, shape = 1 },
	repossession = { id = "repossession", variant = 23507, type = 9, shape = 4 },
	settlement = { id = "settlement", variant = 23508, type = 9, shape = 1 },
	boss = { id = "boss", variant = 23503, type = 9, shape = 4 },
	treasury = { id = "treasury", variant = 23520, type = 20, shape = 4 },
}

rooms.HQ_BY_VARIANT = {}
for _, def in pairs(rooms.HQ) do
	rooms.HQ_BY_VARIANT[def.variant] = def
end

-- Logical links. Door slots chosen for shape1 / shape4 layout.
-- north/south/west/east map to DoorSlot UP0/DOWN0/LEFT*/RIGHT*.
rooms.HQ_LINKS = {
	entrance = {
		north = "greed_return",
		south = "main",
	},
	main = {
		north = "records",
		west = "deposit",
		east = "repossession",
		south = "settlement",
	},
	records = {
		south = "main",
	},
	deposit = {
		east = "main",
	},
	repossession = {
		west = "main",
	},
	settlement = {
		north = "main",
		south = "boss",
	},
	boss = {
		north = "settlement",
		-- south → treasury is owned by Bum Emperor clear flow for now
	},
	treasury = {
		north = "boss",
		south = "greed_return",
	},
}

local DIR_SLOT = {
	-- Prefer lower side doors on tall rooms so Main feels grounded.
	north = DoorSlot.UP0,
	south = DoorSlot.DOWN0,
	west = DoorSlot.LEFT1,
	east = DoorSlot.RIGHT1,
}

local DIR_SLOT_SHAPE1 = {
	north = DoorSlot.UP0,
	south = DoorSlot.DOWN0,
	west = DoorSlot.LEFT0,
	east = DoorSlot.RIGHT0,
}

local DOOR_GFX = {
	default = { loadname = "gfx/grid/door_bankdoor2.anm2", playname = "Opened" },
	return_door = { loadname = "gfx/grid/door_bankdoor3.anm2", playname = "Opened" },
	boss = { loadname = "gfx/grid/door_bankdoor.anm2", playname = "Opened" },
}

local function tr(zh, en)
	local language = Options and Options.Language
	return (language == "en") and en or zh
end

local function change_room(room_index)
	if REPENTOGON then
		Game():ChangeRoom(room_index)
	else
		Game():GetLevel():ChangeRoom(room_index)
	end
end

local function greed_return_targ()
	return function()
		local level = Game():GetLevel()
		if level:GetStage() == LevelStage.STAGE7_GREED then
			change_room(45)
		else
			change_room(84)
		end
	end
end

local function goto_command_for(def)
	if not def then return nil end
	if def.type == 20 then
		return "s.chest." .. tostring(def.variant)
	end
	return "s.arcade." .. tostring(def.variant)
end

function rooms.make_cycle_id(stage, stage_type)
	stage = stage or (Game():GetLevel():GetStage())
	stage_type = stage_type or (Game():GetLevel():GetStageType())
	return string.format("greed_stage_%s_%s", tostring(stage), tostring(stage_type))
end

function rooms.get_current_def()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	if not desc or not desc.Data then return nil end
	local def = rooms.HQ_BY_VARIANT[desc.Data.Variant]
	if not def then return nil end
	if desc.Data.Type ~= def.type then return nil end
	return def
end

function rooms.get_current_id()
	local def = rooms.get_current_def()
	return def and def.id or nil
end

function rooms.is_hq_room()
	return rooms.get_current_def() ~= nil
end

function rooms.lookup_room_config(def)
	if not def then return nil, "unknown" end
	local holder = rawget(_G, "RoomConfig") or rawget(_G, "RoomConfigHolder")
	if not holder or not holder.GetRoomByStageTypeAndVariant then
		return nil, "no_api"
	end
	local mode = Game():IsGreedMode() and 1 or 0
	local ok, cfg = pcall(
		holder.GetRoomByStageTypeAndVariant,
		StbType.SPECIAL_ROOMS,
		def.type,
		def.variant,
		mode
	)
	if ok and cfg then return cfg, "ok" end
	ok, cfg = pcall(
		holder.GetRoomByStageTypeAndVariant,
		StbType.SPECIAL_ROOMS,
		def.type,
		def.variant,
		-1
	)
	if ok and cfg then return cfg, "ok_m1" end
	return nil, "room_not_loaded"
end

function rooms.enter(id)
	local def = rooms.HQ[id]
	if not def then return false, "unknown" end
	local cfg, reason = rooms.lookup_room_config(def)
	if not cfg then
		return false, reason or "room_not_loaded"
	end
	Isaac.ExecuteCommand("goto " .. goto_command_for(def))
	return true
end

function rooms.marker_type()
	return rooms.MARKER_RUNTIME_TYPE
end

function rooms.marker_variant()
	return enums.Entities.Bank_Room_Marker
end

function rooms.collect_markers(subtype)
	local out = {}
	local variant = rooms.marker_variant()
	if not variant then return out end
	for _, ent in ipairs(Isaac.FindByType(rooms.marker_type(), variant, subtype or -1, false, false)) do
		out[#out + 1] = ent
	end
	table.sort(out, function(a, b)
		if a.Position.Y ~= b.Position.Y then
			return a.Position.Y < b.Position.Y
		end
		return a.Position.X < b.Position.X
	end)
	return out
end

function rooms.first_marker(subtype)
	local list = rooms.collect_markers(subtype)
	return list[1]
end

local function hide_marker(ent)
	if not ent then return end
	ent.Visible = false
	ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	-- Do not set FLAG_NO_QUERY — FindByType must still see anchors.
	ent:AddEntityFlags(EntityFlag.FLAG_NO_SPRITE_UPDATE | EntityFlag.FLAG_NO_TARGET)
end

local function door_slot_for(def, dir)
	if def and def.shape == 1 then
		return DIR_SLOT_SHAPE1[dir]
	end
	-- Tall rooms: side links use lower doors; N/S use primary.
	if dir == "west" or dir == "east" then
		return DIR_SLOT[dir]
	end
	return DIR_SLOT[dir]
end

local function resolve_link_targ(link_id)
	if link_id == "greed_return" then
		return greed_return_targ(), DOOR_GFX.return_door
	end
	local def = rooms.HQ[link_id]
	if not def then return nil, nil end
	local gfx = (link_id == "boss") and DOOR_GFX.boss or DOOR_GFX.default
	return goto_command_for(def), gfx
end

function rooms.refresh_doors()
	local def = rooms.get_current_def()
	if not def then return end
	local links = rooms.HQ_LINKS[def.id]
	if not links then return end
	local room = Game():GetRoom()

	for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
		room:RemoveDoor(slot)
	end

	for dir, link_id in pairs(links) do
		if def.id == "settlement" and link_id == "boss" and not bank_state.can_enter_boss() then
			-- Boss gate stays closed until settlement completes.
		else
			local targ, gfx = resolve_link_targ(link_id)
			local slot = door_slot_for(def, dir)
			if targ and slot ~= nil then
				grid_door.try_spawn_grid_door(room, slot, nil, {
					check_and_leave = targ,
					loadname = gfx.loadname,
					playname = gfx.playname,
					tp = (type(targ) == "string" and rooms.HQ[link_id]) and rooms.HQ[link_id].type or nil,
					vr = (type(targ) == "string" and rooms.HQ[link_id]) and rooms.HQ[link_id].variant or nil,
				})
			end
		end
	end
end

-- ---- Branch spawn (Phase B: Greed exit-gated, idempotent per cycle) ----

function rooms.ensure_for_current_cycle(opts)
	opts = opts or {}
	local cycle = opts.cycle_id or rooms.make_cycle_id()
	local br = bank_state.get().branch
	if br.spawned_cycle_id == cycle then
		return nil, "already_spawned"
	end
	-- Live entity for this cycle already present → mark spawned, do not double-spawn.
	if bank_branch.entity then
		for _, ent in ipairs(Isaac.FindByType(bank_branch.entity.Type, bank_branch.entity.Variant, -1, false, false)) do
			if ent and ent:Exists() and not bank_branch.is_broken(ent) then
				local d = ent:GetData()
				if d.BankCycleId == cycle then
					br.spawned_cycle_id = cycle
					return ent, "already_present"
				end
			end
		end
	end
	local closed = bank_state.consume_branch_closure(cycle)
	bank_state.on_branch_arrival(cycle, closed)
	local pos = opts.pos
	if not pos then
		local trap = bank_branch.find_greed_trapdoor_pos and bank_branch.find_greed_trapdoor_pos()
		if trap then
			pos = Vector(trap.X, trap.Y - 80)
		else
			pos = bank_branch.find_exit_anchor()
		end
	end
	local ent = bank_branch.spawn(pos, closed and "closed" or "open")
	br.spawned_cycle_id = cycle
	return ent
end

--- Formal auto-spawn: only when Greed lower Trapdoor exists (exit unlocked).
function rooms.try_auto_spawn_branch()
	if not Game():IsGreedMode() then
		return nil, "not_greed"
	end
	if rooms.is_hq_room() then
		return nil, "hq"
	end
	local stage = Game():GetLevel():GetStage()
	-- Ultra Greed / final greed stage: HQ path owns presence; no ordinary branch.
	if stage >= LevelStage.STAGE7_GREED then
		return nil, "final_stage"
	end
	local trap = bank_branch.find_greed_trapdoor_pos and bank_branch.find_greed_trapdoor_pos()
	if not trap then
		return nil, "no_trapdoor"
	end
	local cycle = rooms.make_cycle_id()
	local br = bank_state.get().branch
	if br.spawned_cycle_id == cycle then
		return nil, "already_spawned"
	end
	local pos = Vector(trap.X, trap.Y - 80)
	return rooms.ensure_for_current_cycle({ cycle_id = cycle, pos = pos })
end

function rooms.debug_advance_cycle(closed)
	local b = bank_state.get()
	local n = (tonumber((b.branch.last_cycle_id or ""):match("debug_(%d+)")) or 0) + 1
	local cycle = "debug_" .. tostring(n)
	if closed == nil then
		closed = bank_state.consume_branch_closure(cycle)
	elseif closed then
		bank_state.consume_branch_closure(cycle)
		closed = true
	else
		closed = false
	end
	bank_state.on_branch_arrival(cycle, closed == true)
	local pos = bank_branch.find_exit_anchor()
	if bank_branch.entity then
		for _, ent in ipairs(Isaac.FindByType(bank_branch.entity.Type, bank_branch.entity.Variant, -1, false, false)) do
			ent:Remove()
		end
	end
	local ent = bank_branch.spawn(pos, closed and "closed" or "open")
	b.branch.spawned_cycle_id = cycle
	return ent, cycle, closed
end

-- ---- Terminal session (Deposit / Settlement) ----

local function get_session(player)
	if not player then return nil end
	local ok, d = pcall(function() return player:GetData() end)
	if not ok or type(d) ~= "table" then return nil end
	return d[SESSION_KEY]
end

local function set_session(player, sess)
	if not player then return end
	local ok, d = pcall(function() return player:GetData() end)
	if not ok or type(d) ~= "table" then return end
	d[SESSION_KEY] = sess
end

local function clear_session(player)
	if not player then return end
	local ok, d = pcall(function() return player:GetData() end)
	if not ok or type(d) ~= "table" then return end
	d[SESSION_KEY] = nil
end

local function close_terminal(player)
	selection_holder.remove_select(player, SELECTION_KEY)
	clear_session(player)
end

local function open_terminal(player, mode, page)
	selection_holder.try_select(player, SELECTION_KEY)
	set_session(player, {
		state = "panel",
		mode = mode,
		page = page or "root",
		cursor = 1,
		opened_frame = Game():GetFrameCount(),
		input_armed = false,
		candidates = nil,
	})
end

local function settlement_options(sess, player)
	local loan = bank_state.get_active_loan()
	if not loan then
		return { "exit" }
	end
	bank_state.check_collateral()
	loan = bank_state.get_active_loan()
	if not loan then
		return { "exit" }
	end
	if loan.secured == false then
		if sess.page == "replace" then
			return bank_state.list_replacement_candidates(player or bank_state.resolve_owner(loan), loan)
		end
		return { "repay", "replace", "exit" }
	end
	return { "repay", "forfeit", "exit" }
end

local function peek_action(player, action)
	if not player then return false, false end
	rooms._reading_input = true
	local ctrl = player.ControllerIndex or 0
	local triggered = Input.IsActionTriggered(action, ctrl)
	local pressed = Input.IsActionPressed(action, ctrl)
	rooms._reading_input = false
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

local function keys_held(player)
	return peek_pressed(player, ButtonAction.ACTION_ITEM)
		or peek_pressed(player, ButtonAction.ACTION_DROP)
		or peek_pressed(player, ButtonAction.ACTION_MENUCONFIRM)
end

local function confirm_terminal(player, sess)
	if sess.mode == "deposit" then
		local ok = bank_state.withdraw_all(player)
		if ok then
			bank_state.get().headquarters.deposit_claimed = true
		end
		close_terminal(player)
		return
	end
	if sess.mode ~= "settlement" then
		close_terminal(player)
		return
	end
	local opts = settlement_options(sess, player)
	local choice = opts[sess.cursor]
	if sess.page == "replace" and type(choice) == "table" and choice.id then
		bank_state.replace_collateral(player, choice.id)
		sess.page = "root"
		sess.cursor = 1
		sess.candidates = nil
		return
	end
	if choice == "repay" then
		local ok = bank_state.repay_loan(player)
		if ok then
			close_terminal(player)
			rooms.refresh_doors()
		end
		return
	end
	if choice == "forfeit" then
		bank_state.forfeit_collateral(player)
		close_terminal(player)
		rooms.refresh_doors()
		return
	end
	if choice == "replace" then
		sess.page = "replace"
		sess.cursor = 1
		return
	end
	close_terminal(player)
end

local function tick_terminal(player, sess)
	if Game():IsPaused() then return end
	if Game():GetFrameCount() <= (sess.opened_frame or 0) then return end
	if not selection_holder.check_select(player, SELECTION_KEY) then
		close_terminal(player)
		return
	end
	if not sess.input_armed then
		if not keys_held(player) then
			sess.input_armed = true
		end
		return
	end
	local opts = (sess.mode == "settlement") and settlement_options(sess, player) or { "withdraw", "exit" }
	if sess.mode == "deposit" then
		opts = { "withdraw", "exit" }
	end
	local n = math.max(1, #opts)
	if peek_triggered(player, ButtonAction.ACTION_SHOOTUP)
		or peek_triggered(player, ButtonAction.ACTION_UP) then
		sess.cursor = ((sess.cursor - 2) % n) + 1
	elseif peek_triggered(player, ButtonAction.ACTION_SHOOTDOWN)
		or peek_triggered(player, ButtonAction.ACTION_DOWN) then
		sess.cursor = (sess.cursor % n) + 1
	elseif peek_triggered(player, ButtonAction.ACTION_SHOOTLEFT)
		or peek_triggered(player, ButtonAction.ACTION_LEFT) then
		sess.cursor = ((sess.cursor - 2) % n) + 1
	elseif peek_triggered(player, ButtonAction.ACTION_SHOOTRIGHT)
		or peek_triggered(player, ButtonAction.ACTION_RIGHT) then
		sess.cursor = (sess.cursor % n) + 1
	end
	if peek_triggered(player, ButtonAction.ACTION_DROP) then
		if sess.mode == "settlement" and sess.page == "replace" then
			sess.page = "root"
			sess.cursor = 1
			return
		end
		close_terminal(player)
		return
	end
	if peek_triggered(player, ButtonAction.ACTION_ITEM)
		or peek_triggered(player, ButtonAction.ACTION_MENUCONFIRM) then
		if sess.mode == "deposit" then
			local choice = opts[sess.cursor]
			if choice == "withdraw" then
				confirm_terminal(player, sess)
			else
				close_terminal(player)
			end
		else
			confirm_terminal(player, sess)
		end
	end
end

local function near_marker(player, subtype)
	local markers = rooms.collect_markers(subtype)
	for _, ent in ipairs(markers) do
		if player.Position:Distance(ent.Position) <= PROMPT_RADIUS then
			return ent
		end
	end
	return nil
end

local function tick_prompt_interaction(player)
	local sess = get_session(player)
	if sess and sess.state == "panel" then
		tick_terminal(player, sess)
		return
	end

	local room_id = rooms.get_current_id()
	if not room_id then
		if sess then clear_session(player) end
		return
	end

	local mode, subtype
	if room_id == "deposit" then
		mode, subtype = "deposit", rooms.MARKER.DEPOSIT
	elseif room_id == "settlement" then
		mode, subtype = "settlement", rooms.MARKER.SETTLEMENT
	else
		if sess then clear_session(player) end
		return
	end

	local marker = near_marker(player, subtype)
	if not marker then
		if sess then clear_session(player) end
		return
	end

	set_session(player, { state = "prompt", mode = mode })
	if peek_triggered(player, ButtonAction.ACTION_ITEM) then
		if mode == "deposit" and bank_state.get().headquarters.deposit_claimed then
			return
		end
		open_terminal(player, mode, "root")
	end
end

-- ---- Room enter handlers ----

function rooms.on_enter_entrance()
	bank_state.enter_headquarters()
end

function rooms.on_enter_main()
	-- Read-only account counter; no business actions.
end

function rooms.on_enter_records()
end

function rooms.on_enter_deposit()
end

function rooms.spawn_repossessed_item(record, pos)
	if not record or not record.item_id or not pos then return nil end
	-- Avoid duplicate pedestals for the same seized record in this room.
	for _, pickup in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, -1, false, false)) do
		local d = pickup:GetData()
		if d.BankRepossession and d.BankRepossessionId == record.id then
			return pickup
		end
	end
	local p = Isaac.Spawn(
		EntityType.ENTITY_PICKUP,
		PickupVariant.PICKUP_COLLECTIBLE,
		record.item_id,
		pos,
		Vector.Zero,
		nil
	):ToPickup()
	if not p then return nil end
	p:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
	p.Touched = true
	local d = p:GetData()
	d.BankRepossession = true
	d.BankRepossessionId = record.id
	return p
end

function rooms.on_enter_repossession()
	local anchors = rooms.collect_markers(rooms.MARKER.REPOSSESSION)
	local assets = bank_state.get().seized_assets or {}
	for i, record in ipairs(assets) do
		local anchor = anchors[i]
		if anchor then
			rooms.spawn_repossessed_item(record, anchor.Position)
		end
	end
end

function rooms.on_enter_settlement()
	bank_state.check_collateral()
	if not bank_state.has_active_loan() then
		bank_state.mark_settled()
	end
end

function rooms.on_enter_treasury()
	local hq = bank_state.get().headquarters
	if not hq.treasury_spawned then
		if gate.requires_first_clear_boss("chapter1.coin") then
			-- First-clear Story token is granted after Boss path / rooms.grant_treasury_reward().
			-- Legacy Coin Shard pedestal is not spawned.
		end
	end
end

function rooms.grant_treasury_reward()
	local b = bank_state.get()
	local hq = b.headquarters
	if hq.treasury_spawned then
		return false, "already"
	end
	hq.treasury_spawned = true
	local anchor = rooms.first_marker(rooms.MARKER.TREASURY)
	local pos = anchor and anchor.Position or Game():GetRoom():GetCenterPos()
	-- Legacy Coin Shard pedestal retired: first clear grants Story token only.
	-- Do not show achievement_Coin_Shard / "Unlocked: A Shard of Coin" (item dormant).
	local first = not gate.is_event_first_cleared("chapter1.coin")
	if first then
		local ok, material_adapter = pcall(require, "Qing_Remaster_scripts.story.material_story_adapter")
		if ok and material_adapter and material_adapter.on_thread_complete then
			material_adapter.on_thread_complete("coin", {story_owned = true})
		end
		local story_ok, story_state = pcall(require, "Qing_Remaster_scripts.story.story_state")
		if story_ok and story_state and story_state.suppress_permanent_unlocks
			and story_state.suppress_permanent_unlocks()
		then
			-- Story Test: do not write permanent unlock mirrors.
		else
			local unlock = save.UnlockData and save.UnlockData.Others and save.UnlockData.Others.Coin
			if type(unlock) == "table" and unlock.Unlock ~= true then
				-- Silent permanent flag for legacy story/migration mirrors only.
				unlock.Unlock = true
			end
		end
		return true, "story"
	end
	for _ = 1, 3 do
		Isaac.Spawn(
			EntityType.ENTITY_PICKUP,
			PickupVariant.PICKUP_COIN,
			CoinSubType.COIN_PENNY,
			Game():GetRoom():FindFreePickupSpawnPosition(pos, 20, true),
			RandomVector() * 2,
			nil
		)
	end
	return true, "repeat"
end

function rooms.on_enter_boss()
	-- Boss encounter remains owned by thread_Coin / Bum Emperor.
end

local ENTER_HANDLERS = {
	entrance = rooms.on_enter_entrance,
	main = rooms.on_enter_main,
	records = rooms.on_enter_records,
	deposit = rooms.on_enter_deposit,
	repossession = rooms.on_enter_repossession,
	settlement = rooms.on_enter_settlement,
	treasury = rooms.on_enter_treasury,
	boss = rooms.on_enter_boss,
}

function rooms.on_new_room()
	local def = rooms.get_current_def()
	if not def then return end
	for _, ent in ipairs(rooms.collect_markers(-1)) do
		hide_marker(ent)
	end
	rooms.refresh_doors()
	local handler = ENTER_HANDLERS[def.id]
	if handler then
		handler()
	end
	-- Re-refresh after settlement auto-mark.
	if def.id == "settlement" or def.id == "entrance" then
		rooms.refresh_doors()
	end
end

-- ---- Render helpers ----

local function bank_font()
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

local function draw_lines(player, lines, opts)
	opts = opts or {}
	local font = bank_font()
	if not font then return end
	local scale = opts.scale or 1
	local line_h = ((font.GetLineHeight and font:GetLineHeight() or 12) + 2) * scale
	local pad = 10
	local max_w = opts.width or 200
	local panel_h = pad * 2 + #lines * line_h
	local screen = gui.GetScreenSize and gui.GetScreenSize() or Vector(480, 270)
	local x = math.floor((screen.X - max_w) * 0.5 + 0.5)
	local y = math.floor((screen.Y - panel_h) * 0.5 + 0.5)
	if opts.anchor == "player" and player then
		local p = Isaac.WorldToScreen(player.Position)
		x = math.floor(p.X - max_w * 0.5 + 0.5)
		y = math.floor(p.Y - panel_h - 20 + 0.5)
	end
	if opts.boxed ~= false then
		draw_rect_outline(x, y, max_w, panel_h, KColor(0.9, 0.8, 0.45, 1))
		draw_rect_outline(x + 2, y + 2, max_w - 4, panel_h - 4, KColor(0.35, 0.3, 0.2, 0.8))
	end
	for i, line in ipairs(lines) do
		local col = KColor(1, 1, 1, 1)
		if type(line) == "string" and line:sub(1, 1) == ">" then
			col = KColor(1, 0.92, 0.35, 1)
		end
		font:DrawStringScaledUTF8(line, x + pad, y + pad + (i - 1) * line_h, scale, scale, col, 0, false)
	end
end

local function account_lines()
	local b = bank_state.get()
	local loan = b.active_loan
	return {
		"BANK ACCOUNT",
		string.format(tr("存款  %d¢", "Deposit  %d¢"), b.deposit),
		string.format(tr("累计利息  %d¢", "Interest  %d¢"), b.interest_earned or 0),
		string.format(tr("贷款  %d¢", "Loan  %d¢"), loan and (loan.remaining or loan.principal or 0) or 0),
		string.format(tr("没收品  %d", "Seized  %d"), #(b.seized_assets or {})),
	}
end

local function records_lines()
	local s = bank_state.get().stats or {}
	return {
		"ACCOUNT HISTORY",
		string.format(tr("存入  %d¢", "Deposited  %d¢"), s.total_deposited or 0),
		string.format(tr("取出  %d¢", "Withdrawn  %d¢"), s.total_withdrawn or 0),
		string.format(tr("利息  %d¢", "Interest  %d¢"), bank_state.get().interest_earned or 0),
		string.format(tr("贷款发放  %d", "Loans issued  %d"), s.loans_issued or 0),
		string.format(tr("贷款偿还  %d", "Loans repaid  %d"), s.loans_repaid or 0),
		string.format(tr("没收  %d", "Assets seized  %d"), s.assets_seized or 0),
		string.format(tr("抢劫  %d", "Branches robbed  %d"), s.robberies or 0),
	}
end

function rooms.render_player(player)
	local room_id = rooms.get_current_id()
	if not room_id then return end

	local sess = get_session(player)
	if sess and sess.state == "panel" then
		local lines = { "BANK OF BUM" }
		if sess.mode == "deposit" then
			lines[#lines + 1] = tr("保险库", "VAULT")
			lines[#lines + 1] = string.format(tr("余额  %d¢", "Balance  %d¢"), bank_state.get_deposit())
			lines[#lines + 1] = "────────"
			local opts = { "withdraw", "exit" }
			local labels = {
				withdraw = tr("全部取出", "WITHDRAW ALL"),
				exit = tr("返回", "Exit"),
			}
			for i, opt in ipairs(opts) do
				local mark = (i == sess.cursor) and "> " or "  "
				lines[#lines + 1] = mark .. (labels[opt] or tostring(opt))
			end
		elseif sess.mode == "settlement" then
			local loan = bank_state.get_active_loan()
			lines[#lines + 1] = tr("最终结算", "FINAL SETTLEMENT")
			if not loan then
				lines[#lines + 1] = tr("账目已结清", "ACCOUNT SETTLED")
			else
				lines[#lines + 1] = string.format(tr("未偿  %d¢", "Outstanding  %d¢"), loan.remaining or loan.principal or 0)
				if loan.secured == false then
					lines[#lines + 1] = tr("抵押物缺失", "COLLATERAL MISSING")
				end
				lines[#lines + 1] = "────────"
				local opts = settlement_options(sess, player)
				for i, opt in ipairs(opts) do
					local mark = (i == sess.cursor) and "> " or "  "
					local label
					if type(opt) == "table" then
						label = string.format("%s (%d¢)", opt.name or ("#" .. opt.id), opt.value or 0)
					else
						local labels = {
							repay = tr("偿还", "REPAY"),
							forfeit = tr("放弃抵押", "FORFEIT COLLATERAL"),
							replace = tr("更换抵押", "REPLACE COLLATERAL"),
							exit = tr("返回", "Exit"),
						}
						label = labels[opt] or tostring(opt)
					end
					lines[#lines + 1] = mark .. label
				end
			end
		end
		draw_lines(player, lines)
		return
	end

	if room_id == "main" and near_marker(player, rooms.MARKER.MAIN) then
		draw_lines(player, account_lines())
		return
	end
	if room_id == "entrance" and near_marker(player, rooms.MARKER.ENTRANCE) then
		local lines = account_lines()
		table.insert(lines, 1, tr("银行总部", "BANK HQ"))
		draw_lines(player, lines)
		return
	end
	if room_id == "records" and near_marker(player, rooms.MARKER.RECORDS) then
		draw_lines(player, records_lines())
		return
	end
	if room_id == "deposit" and near_marker(player, rooms.MARKER.DEPOSIT) then
		local hq = bank_state.get().headquarters
		local lines
		if hq.deposit_claimed then
			lines = { tr("保险库已清空", "VAULT EMPTY") }
		else
			lines = {
				tr("[保险库]", "[VAULT]"),
				string.format("%d¢", bank_state.get_deposit()),
				tr("按使用键全部取出", "Press Item to withdraw"),
			}
		end
		draw_lines(player, lines)
		return
	end
	if room_id == "settlement" and near_marker(player, rooms.MARKER.SETTLEMENT) then
		local loan = bank_state.get_active_loan()
		local lines
		if not loan then
			lines = { tr("账目已结清", "ACCOUNT SETTLED"), tr("Boss 门已开放", "Boss door open") }
		else
			lines = {
				tr("[结算柜台]", "[SETTLEMENT]"),
				string.format(tr("未偿  %d¢", "Due  %d¢"), loan.remaining or loan.principal or 0),
				tr("按使用键办理", "Press Item"),
			}
		end
		draw_lines(player, lines)
		return
	end
	if room_id == "repossession" then
		local assets = bank_state.get().seized_assets or {}
		if #assets == 0 and near_marker(player, rooms.MARKER.REPOSSESSION) then
			draw_lines(player, { tr("暂无没收品", "NO PROPERTY HELD") })
		end
	end
end

function rooms.block_input(_entity, input_hook, button_action)
	if rooms._reading_input then
		return nil
	end
	if input_hook ~= InputHook.IS_ACTION_TRIGGERED and input_hook ~= InputHook.IS_ACTION_PRESSED then
		return nil
	end
	local player = nil
	-- Resolve controlling player via ControllerIndex match is unavailable here;
	-- block globally while any player holds an HQ terminal panel.
	local n = Game():GetNumPlayers()
	local any_panel = false
	local any_prompt = false
	for i = 0, n - 1 do
		local p = Game():GetPlayer(i)
		local sess = get_session(p)
		if sess and sess.state == "panel" then
			any_panel = true
			player = p
			break
		elseif sess and sess.state == "prompt" then
			any_prompt = true
		end
	end
	if any_panel then
		if button_action == ButtonAction.ACTION_ITEM
			or button_action == ButtonAction.ACTION_DROP
			or button_action == ButtonAction.ACTION_MENUCONFIRM
			or button_action == ButtonAction.ACTION_BOMB
			or (button_action >= ButtonAction.ACTION_LEFT and button_action <= ButtonAction.ACTION_DOWN)
			or (button_action >= ButtonAction.ACTION_SHOOTLEFT and button_action <= ButtonAction.ACTION_SHOOTDOWN)
		then
			return false
		end
	elseif any_prompt then
		if button_action == ButtonAction.ACTION_ITEM
			or button_action == ButtonAction.ACTION_MENUCONFIRM
		then
			return false
		end
	end
	return nil
end

-- ---- Callbacks ----

table.insert(rooms.ToCall, #rooms.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function(_)
		rooms.on_new_room()
		rooms.try_auto_spawn_branch()
	end,
})

-- Trapdoor often appears after wave clear, not on room enter.
table.insert(rooms.ToCall, #rooms.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function(_)
		if not Game():IsGreedMode() then return end
		if (Game():GetFrameCount() % 15) ~= 0 then return end
		rooms.try_auto_spawn_branch()
	end,
})

table.insert(rooms.ToCall, #rooms.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE,
	params = nil,
	Function = function(_, player)
		if not player or player.Variant ~= 0 then return end
		if not rooms.is_hq_room() then return end
		tick_prompt_interaction(player)
	end,
})

table.insert(rooms.ToCall, #rooms.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PLAYER_RENDER,
	params = nil,
	Function = function(_, player)
		if not player or player.Variant ~= 0 then return end
		if not rooms.is_hq_room() then return end
		rooms.render_player(player)
	end,
})

table.insert(rooms.ToCall, #rooms.ToCall + 1, {
	CallBack = ModCallbacks.MC_INPUT_ACTION,
	params = nil,
	Function = function(_, entity, input_hook, button_action)
		return rooms.block_input(entity, input_hook, button_action)
	end,
})

table.insert(rooms.ToCall, #rooms.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION,
	params = PickupVariant.PICKUP_COLLECTIBLE,
	Function = function(_, pickup, collider, _low)
		if not pickup then return end
		local d = pickup:GetData()
		if not d.BankRepossession then return end
		local player = collider and collider:ToPlayer()
		if not player then return end
		bank_state.claim_seized_asset(d.BankRepossessionId)
		d.BankRepossession = nil
		d.BankRepossessionId = nil
	end,
})

return rooms
