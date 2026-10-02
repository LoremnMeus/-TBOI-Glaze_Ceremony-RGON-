-- Runtime Stitch selection owner (single-page three-column panel).
-- Owns movement/attack choice UI. Does not own pair AI or entity splice.
-- Navigation: ACTION_SHOOT* only (WASD / ACTION_LEFT..DOWN never used).
-- Confirm: ACTION_ITEM. Cancel: ACTION_DROP. No MENUCONFIRM.
-- Temporary presentation infrastructure — not a general selection framework.

local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local selection_holder = require("Qing_Remaster_scripts.others.selection_holder")
local profiles = require("Qing_Remaster_scripts.config.runtime_stitch_enemy_profiles")
local bestiary_visual = require("Qing_Remaster_scripts.auxiliary.runtime_stitch_bestiary_visual")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local renderer = require("Qing_Remaster_scripts.auxiliary.runtime_stitch_renderer")

local SELECT_NAME = "Runtime_Stitch_Select_"
local OWN_KEY = "Runtime_Stitch_Gameplay_"
local PENDING_ROLL_KEY = OWN_KEY .. "pending_roll"
local ITEM_ID = enums.Items.Suture_Needle
local CHOICE_COUNT = 3

local M = {
	ToCall = {},
	myToCall = {},
	own_key = OWN_KEY,
	-- Centralized layout (screen-center relative). Tunable without hunting magic numbers.
	UI = {
		center_x = 0,
		center_y = 0,
		left_x = -88,
		right_x = 88,
		first_y = -38,
		row_gap = 38,
		-- HARD RULE: selection state MUST NOT alter geometry (scale/pos). Color only.
		option_scale = 0.80,
		preview_x = 0,
		preview_y = 0,
		preview_w = 92,
		preview_h = 76,
		preview_max_scale = 1.35,
	},
}

-- selection[player_key] = panel state (pure data + UI caches; no Entity userdata)
local selection = {}

local blocked_actions = {
	[ButtonAction.ACTION_SHOOTLEFT] = true,
	[ButtonAction.ACTION_SHOOTRIGHT] = true,
	[ButtonAction.ACTION_SHOOTUP] = true,
	[ButtonAction.ACTION_SHOOTDOWN] = true,
	[ButtonAction.ACTION_DROP] = true,
	[ButtonAction.ACTION_ITEM] = true,
}

local function player_key(player)
	if not player then return nil end
	local d = player:GetData()
	if d and d.__Index ~= nil then
		return tostring(d.__Index)
	end
	return tostring(player.ControllerIndex or 0)
end

local function get_sel(player)
	local key = player_key(player)
	if not key then return nil, nil end
	return selection[key], key
end

local function destroy_option_visuals(sel)
	if not sel then return end
	if sel.movement_visuals then
		for i = 1, #sel.movement_visuals do
			bestiary_visual.destroy(sel.movement_visuals[i])
		end
		sel.movement_visuals = nil
	end
	if sel.attack_visuals then
		for i = 1, #sel.attack_visuals do
			bestiary_visual.destroy(sel.attack_visuals[i])
		end
		sel.attack_visuals = nil
	end
end

local function destroy_preview(sel)
	if not sel or not sel.preview then return end
	if renderer.destroy_profile_preview then
		renderer.destroy_profile_preview(sel.preview)
	end
	sel.preview = nil
	sel.preview_move_id = nil
	sel.preview_attack_id = nil
end

--- Sole selection teardown path. All cancel / confirm / toggle close go here.
local function close_selection(player, _opts)
	local sel, key = get_sel(player)
	if sel then
		destroy_preview(sel)
		destroy_option_visuals(sel)
	end
	if key then
		selection[key] = nil
	end
	if player then
		selection_holder.remove_select(player, SELECT_NAME)
		if player:Exists() and player:IsHoldingItem() then
			player:AnimateCollectible(ITEM_ID, "HideItem", "PlayerPickup")
		end
	end
end

local function build_option_visuals(choice_ids, getter)
	local list = {}
	for i = 1, #choice_ids do
		local p = getter(choice_ids[i])
		local vis = p and bestiary_visual.build_from_source(p.source) or nil
		list[i] = vis
	end
	return list
end

local function preview_ids(sel)
	-- While focusing a column, preview follows the cursor (not only locked).
	-- Leaving that column restores chosen_* for that side.
	local move_id
	if sel.focus == "movement" then
		move_id = sel.movement_choices[sel.movement_cursor]
	else
		move_id = sel.chosen_movement or sel.movement_choices[sel.movement_cursor]
	end
	local atk_id
	if sel.focus == "attack" then
		atk_id = sel.attack_choices[sel.attack_cursor]
	else
		atk_id = sel.chosen_attack or sel.attack_choices[sel.attack_cursor]
	end
	return move_id, atk_id
end

local function ensure_preview(sel)
	local move_id, atk_id = preview_ids(sel)
	if not move_id or not atk_id then return end
	if sel.preview and sel.preview_move_id == move_id and sel.preview_attack_id == atk_id then
		return
	end
	destroy_preview(sel)
	local mp = profiles.get_movement(move_id)
	local ap = profiles.get_attack(atk_id)
	if not mp or not ap or not renderer.create_profile_preview then return end
	sel.preview = renderer.create_profile_preview(mp, ap, {
		cut_normal = { 1, 0 },
		host_keep_sign = 1,
		donor_keep_sign = -1,
		preview_w = M.UI.preview_w,
		preview_h = M.UI.preview_h,
		preview_max_scale = M.UI.preview_max_scale,
	})
	sel.preview_move_id = move_id
	sel.preview_attack_id = atk_id
end

local function play_stitch_sound()
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_TOOTH_AND_NAIL, 1.0, 1.1, false, 0, 2)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_KNIFE_PULL, 0.75, 1.05, false, 0, 2)
end

--- Partial Fisher-Yates: first `count` unique picks from pool using item RNG.
local function sample_unique(pool, count, rng)
	local tmp = {}
	for i = 1, #pool do
		tmp[i] = pool[i]
	end
	local n = #tmp
	local take = math.min(count, n)
	if take <= 0 then
		return {}
	end
	if not rng or not rng.RandomInt then
		local out = {}
		for i = 1, take do
			out[i] = tmp[i]
		end
		return out
	end
	for i = 1, take do
		local j = i + rng:RandomInt(n - i + 1)
		tmp[i], tmp[j] = tmp[j], tmp[i]
	end
	local out = {}
	for i = 1, take do
		out[i] = tmp[i]
	end
	return out
end

local function copy_id_list(list)
	local out = {}
	if type(list) ~= "table" then
		return out
	end
	for i = 1, #list do
		out[i] = list[i]
	end
	return out
end

local function get_pending_roll(player)
	if not player or not player.GetData then
		return nil
	end
	local d = player:GetData()
	local roll = d and d[PENDING_ROLL_KEY]
	if type(roll) ~= "table" then
		return nil
	end
	if type(roll.movement) ~= "table" or type(roll.attack) ~= "table" then
		return nil
	end
	if #roll.movement < 1 or #roll.attack < 1 then
		return nil
	end
	return roll
end

local function set_pending_roll(player, movement, attack)
	if not player or not player.GetData then
		return
	end
	player:GetData()[PENDING_ROLL_KEY] = {
		movement = copy_id_list(movement),
		attack = copy_id_list(attack),
	}
end

local function clear_pending_roll(player)
	if not player or not player.GetData then
		return
	end
	player:GetData()[PENDING_ROLL_KEY] = nil
end

local function clear_all_pending_rolls()
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player then
			clear_pending_roll(player)
		end
	end
end

local function resolve_choice_lists(player, rng)
	local pending = get_pending_roll(player)
	if pending then
		return copy_id_list(pending.movement), copy_id_list(pending.attack)
	end
	local use_rng = rng
	if (not use_rng or not use_rng.RandomInt) and player and player.GetCollectibleRNG then
		use_rng = player:GetCollectibleRNG(ITEM_ID)
	end
	local movement = sample_unique(profiles.list_movement_ids(), CHOICE_COUNT, use_rng)
	local attack = sample_unique(profiles.list_attack_ids(), CHOICE_COUNT, use_rng)
	set_pending_roll(player, movement, attack)
	return movement, attack
end

local function discharge_item(player, sel)
	if not player then return end
	local slot = sel and sel.active_slot
	if slot == nil or slot < 0 then
		slot = auxi.check_slot_with_item(player, ITEM_ID, true)
	end
	if slot ~= nil and slot >= 0 then
		player:DischargeActiveItem(slot)
	end
end

local function finalize_stitch(player, sel)
	if not sel or sel.finalizing then return false end
	if not sel.chosen_movement or not sel.chosen_attack then return false end
	sel.finalizing = true
	local pair_mod = require("Qing_Remaster_scripts.others.runtime_stitch_pair")
	local ent = pair_mod.spawn_pair(player, sel.chosen_movement, sel.chosen_attack)
	if not ent then
		-- Spawn failed: keep panel open, no discharge, allow retry.
		sel.finalizing = false
		return false
	end
	play_stitch_sound()
	discharge_item(player, sel)
	clear_pending_roll(player)
	close_selection(player)
	return true
end

local function lock_current(sel)
	if not sel then
		return
	end
	if sel.focus == "movement" then
		sel.chosen_movement = sel.movement_choices[sel.movement_cursor]
		if sel.chosen_attack then
			sel.focus = "confirm"
		else
			sel.focus = "attack"
		end
	elseif sel.focus == "attack" then
		sel.chosen_attack = sel.attack_choices[sel.attack_cursor]
		if sel.chosen_movement then
			sel.focus = "confirm"
		else
			sel.focus = "movement"
		end
	end
end

local function both_locked(sel)
	return sel.chosen_movement ~= nil and sel.chosen_attack ~= nil
end

--- Dual-column navigation. Confirm focus only exists after both sides locked.
--- No wrap-around jumps (stay on edge).
local function navigate_horizontal(sel, dir)
	if not both_locked(sel) then
		if dir > 0 then
			if sel.focus == "movement" then
				sel.focus = "attack"
			end
		else
			if sel.focus == "attack" then
				sel.focus = "movement"
			end
		end
		return
	end
	if dir > 0 then
		if sel.focus == "movement" then
			sel.focus = "confirm"
		elseif sel.focus == "confirm" then
			sel.focus = "attack"
		end
	else
		if sel.focus == "attack" then
			sel.focus = "confirm"
		elseif sel.focus == "confirm" then
			sel.focus = "movement"
		end
	end
end

local function clamp_cursor(sel, which, delta)
	local list = which == "movement" and sel.movement_choices or sel.attack_choices
	local key = which == "movement" and "movement_cursor" or "attack_cursor"
	local n = #list
	if n <= 0 then return end
	local cur = sel[key] or 1
	cur = ((cur - 1 + delta) % n) + 1
	sel[key] = cur
end

function M.get_selection(player)
	return get_sel(player)
end

--- Probe: list open selection panels that currently hold a Bestiary preview.
function M.list_open_previews()
	local out = {}
	for key, sel in pairs(selection) do
		if sel and sel.preview then
			out[#out + 1] = {
				player_key = key,
				preview = sel.preview,
				move_id = sel.preview_move_id or sel.chosen_movement,
				attack_id = sel.preview_attack_id or sel.chosen_attack,
				focus = sel.focus,
			}
		end
	end
	return out
end

function M.cancel_selection(player)
	close_selection(player)
	return true
end

--- Open panel. Does NOT discharge. Pass activeSlot from MC_USE_ITEM when available.
--- Reuses pending_roll across cancel/reopen so cancel is not a free reroll.
function M.begin_selection(player, rng, activeSlot)
	if not player then
		return { Discharge = false, Remove = false, ShowAnim = false }
	end
	if get_sel(player) then
		close_selection(player)
		return { Discharge = false, Remove = false, ShowAnim = false }
	end

	local key = player_key(player)
	local movement_choices, attack_choices = resolve_choice_lists(player, rng)
	local sel = {
		movement_choices = movement_choices,
		attack_choices = attack_choices,
		movement_cursor = 1,
		attack_cursor = 1,
		chosen_movement = nil,
		chosen_attack = nil,
		focus = "movement",
		opened_frame = Game():GetFrameCount(),
		input_armed = false,
		wait_drop_release = true,
		last_open_dir = 9,
		last_open_dir_counter = 0,
		active_slot = activeSlot,
		finalizing = false,
		preview = nil,
	}
	sel.movement_visuals = build_option_visuals(sel.movement_choices, profiles.get_movement)
	sel.attack_visuals = build_option_visuals(sel.attack_choices, profiles.get_attack)
	selection[key] = sel
	selection_holder.check_and_try_select(player, SELECT_NAME)
	player:AnimateCollectible(ITEM_ID, "LiftItem", "PlayerPickup")
	ensure_preview(sel)
	return { Discharge = false, Remove = false, ShowAnim = false }
end

--- Probe / debug: current pending 3+3 for a player (or nil).
function M.get_pending_roll(player)
	return get_pending_roll(player)
end

function M.clear_pending_roll(player)
	clear_pending_roll(player)
end

local function update_panel_input(player, sel)
	if Game():IsPaused() then return end
	if sel.finalizing then return end
	local frame = Game():GetFrameCount()
	if frame <= (sel.opened_frame or 0) then return end
	local ctrlid = player.ControllerIndex or 0

	if not player:IsHoldingItem() then
		player:AnimateCollectible(ITEM_ID, "LiftItem", "PlayerPickup")
	end

	if not sel.input_armed then
		if not Input.IsActionPressed(ButtonAction.ACTION_ITEM, ctrlid) then
			sel.input_armed = true
		end
		return
	end

	if sel.wait_drop_release then
		if not Input.IsActionPressed(ButtonAction.ACTION_DROP, ctrlid) then
			sel.wait_drop_release = false
		end
	elseif Input.IsActionTriggered(ButtonAction.ACTION_DROP, ctrlid) then
		close_selection(player)
		return
	end

	-- Shoot directions only — WASD / ACTION_LEFT..DOWN never navigate the panel.
	local left = Input.IsActionTriggered(ButtonAction.ACTION_SHOOTLEFT, ctrlid)
	local right = Input.IsActionTriggered(ButtonAction.ACTION_SHOOTRIGHT, ctrlid)
	local up = Input.IsActionTriggered(ButtonAction.ACTION_SHOOTUP, ctrlid)
	local down = Input.IsActionTriggered(ButtonAction.ACTION_SHOOTDOWN, ctrlid)
	local confirm = Input.IsActionTriggered(ButtonAction.ACTION_ITEM, ctrlid)

	if left then
		navigate_horizontal(sel, -1)
	elseif right then
		navigate_horizontal(sel, 1)
	end

	if sel.focus == "movement" then
		if up then clamp_cursor(sel, "movement", -1) end
		if down then clamp_cursor(sel, "movement", 1) end
	elseif sel.focus == "attack" then
		if up then clamp_cursor(sel, "attack", -1) end
		if down then clamp_cursor(sel, "attack", 1) end
	end

	if confirm then
		if sel.focus == "confirm" then
			if both_locked(sel) then
				finalize_stitch(player, sel)
			end
		else
			lock_current(sel)
		end
	end

	if sel.focus == "confirm" and not both_locked(sel) then
		sel.focus = "movement"
	end
end

local function update_panel_visuals(sel)
	-- Advance sprites + bake on Update clock only (never from POST_RENDER).
	if sel.movement_visuals then
		for i = 1, #sel.movement_visuals do
			bestiary_visual.update(sel.movement_visuals[i])
		end
	end
	if sel.attack_visuals then
		for i = 1, #sel.attack_visuals do
			bestiary_visual.update(sel.attack_visuals[i])
		end
	end
	ensure_preview(sel)
	if sel.preview and renderer.update_profile_preview then
		renderer.update_profile_preview(sel.preview)
	end
end

local function screen_center()
	return Vector(Isaac.GetScreenWidth() * 0.5, Isaac.GetScreenHeight() * 0.5)
end

local function option_pos(c, col, row)
	local ui = M.UI
	local x = c.X + ui.center_x + ((col == "left") and ui.left_x or ui.right_x)
	local y = c.Y + ui.center_y + ui.first_y + (row - 1) * ui.row_gap
	return Vector(x, y)
end

-- Color-only selection states. Geometry stays fixed at option_scale.
local COLOR_NORMAL = Color(1, 1, 1, 1)
local COLOR_HOVER = Color(1, 1, 1, 1, 0.30, 0.30, 0.12)
local COLOR_LOCKED = Color(1, 0.88, 0.55, 1, 0.18, 0.12, 0)
local COLOR_HOVER_LOCKED = Color(1, 0.95, 0.62, 1, 0.32, 0.24, 0.05)

local function render_column(visuals, choices, cursor, chosen_id, focus_here, col, c)
	local ui = M.UI
	for i = 1, #choices do
		local pos = option_pos(c, col, i)
		local vis = visuals and visuals[i]
		local pid = choices[i]
		local hovered = focus_here and (cursor == i)
		local locked = (chosen_id == pid)
		if vis then
			local color = COLOR_NORMAL
			if hovered and locked then
				color = COLOR_HOVER_LOCKED
			elseif locked then
				color = COLOR_LOCKED
			elseif hovered then
				color = COLOR_HOVER
			end
			bestiary_visual.render(vis, pos, ui.option_scale, color)
		end
	end
end

local function render_panel(_player, sel)
	local c = screen_center()
	local ui = M.UI

	render_column(
		sel.movement_visuals,
		sel.movement_choices,
		sel.movement_cursor,
		sel.chosen_movement,
		sel.focus == "movement",
		"left",
		c
	)
	render_column(
		sel.attack_visuals,
		sel.attack_choices,
		sel.attack_cursor,
		sel.chosen_attack,
		sel.focus == "attack",
		"right",
		c
	)

	if sel.preview and renderer.render_profile_preview then
		local preview_pos = Vector(c.X + ui.center_x + ui.preview_x, c.Y + ui.center_y + ui.preview_y)
		local hl = (sel.focus == "confirm" and both_locked(sel)) and true or nil
		renderer.render_profile_preview(sel.preview, preview_pos, hl)
	end
end

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_INPUT_ACTION,
	params = nil,
	Function = function(_, ent, hook, button)
		if ent == nil then return end
		local player = ent:ToPlayer()
		if not player then return end
		if not get_sel(player) then return end
		if not blocked_actions[button] then return end
		if hook == InputHook.IS_ACTION_TRIGGERED or hook == InputHook.IS_ACTION_PRESSED then
			return false
		end
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE,
	params = nil,
	Function = function(_, player)
		if player and not player:HasCollectible(ITEM_ID, true) then
			if get_pending_roll(player) then
				clear_pending_roll(player)
			end
		end
		if not selection_holder.check_select(player, SELECT_NAME) then
			local sel = get_sel(player)
			if sel then
				-- Holder lost ownership; tear down Lua state.
				close_selection(player)
			end
			return
		end
		local sel = get_sel(player)
		if not sel then
			selection_holder.remove_select(player, SELECT_NAME)
			return
		end
		update_panel_input(player, sel)
		update_panel_visuals(sel)
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_RENDER,
	params = nil,
	Function = function()
		for i = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(i)
			if player and selection_holder.check_select(player, SELECT_NAME) then
				local sel = get_sel(player)
				if sel then
					render_panel(player, sel)
				end
			end
		end
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_GAME_EXIT,
	params = nil,
	Function = function()
		for _, sel in pairs(selection) do
			destroy_preview(sel)
			destroy_option_visuals(sel)
		end
		selection = {}
		clear_all_pending_rolls()
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	params = nil,
	Function = function(_, continued)
		if not continued then
			for _, sel in pairs(selection) do
				destroy_preview(sel)
				destroy_option_visuals(sel)
			end
			selection = {}
			clear_all_pending_rolls()
		end
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		-- Room change closes open panels without consuming charge.
		-- pending_roll is kept so reopen in the same charge cycle is not a free reroll.
		for i = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(i)
			if player and get_sel(player) then
				close_selection(player)
			end
		end
	end,
})

table.insert(M.myToCall, #M.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_LEVEL,
	params = nil,
	Function = function()
		for i = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(i)
			if player and get_sel(player) then
				close_selection(player)
			end
		end
		clear_all_pending_rolls()
	end,
})

return M
