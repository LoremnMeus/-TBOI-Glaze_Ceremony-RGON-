-- 天外救星 / Alien Savior：SOS → 二次受伤拦截 → UFO 救援状态机。
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local g = require("Qing_Remaster_scripts.core.globals")
local state = require("Qing_Remaster_scripts.items.alien_savior.state")
local ctrl = require("Qing_Remaster_scripts.items.alien_savior.controller")
local visual = require("Qing_Remaster_scripts.items.alien_savior.visual")
local audio = require("Qing_Remaster_scripts.items.alien_savior.audio")
local player_visual_render = require("Qing_Remaster_scripts.callbacks.player_visual_render_holder")
local as_motion = require("Qing_Remaster_scripts.items.alien_savior.motion")

local item = {
	ToCall = {},
	pre_ToCall = {},
	myToCall = {},
	entity = enums.Items.Alien_Savior,
	own_key = "Item_Alien_Savior_",
	qol = 3,
}

local function holds(player)
	return player and item.entity and item.entity > 0 and player:GetCollectibleNum(item.entity) > 0
end

local function combat_room()
	local room = Game():GetRoom()
	if not room or room:IsClear() then
		return false
	end
	local kind = room:GetType()
	return kind == RoomType.ROOM_DEFAULT
		or kind == RoomType.ROOM_BOSS
		or kind == RoomType.ROOM_MINIBOSS
		or kind == RoomType.ROOM_CHALLENGE
		or kind == RoomType.ROOM_BOSSRUSH
end

local function qualifying_hit(ent, amt, flag, source, cooldown)
	if not auxi.is_damage_from_enemy(ent, amt, flag, source, cooldown) then
		return false
	end
	-- Extra: ignore pure player-sourced / slot already covered; block red-heart-only tax if flagged alone.
	if flag and (flag & DamageFlag.DAMAGE_NOKILL) ~= 0 and (flag & DamageFlag.DAMAGE_FAKE) ~= 0 then
		return false
	end
	return true
end

local function arm_sos(player, opts)
	opts = opts or {}
	local pkey = state.player_key(player)
	if not pkey then
		return false
	end
	state.set_armed(pkey, true)
	-- Connected = aliens acknowledged; flyover is the world response (no head UI).
	audio.play_sos_connected()
	if opts.skip_fx ~= true then
		local shadow_opts = opts.shadow or {}
		shadow_opts.player = shadow_opts.player or player
		visual.start_sos_shadow(shadow_opts)
	end
	return true
end

-- Probe / public helpers
function item.force_sos(player)
	player = player or Isaac.GetPlayer(0)
	if not player then
		return false
	end
	return arm_sos(player, { shadow = { force = true, player = player } })
end

function item.replay_sos_shadow()
	local player = Isaac.GetPlayer(0)
	return visual.start_sos_shadow({ force = true, player = player })
end

function item.set_sos_shadow_skip(skip)
	visual.set_sos_shadow_skip(skip)
end

function item.get_sos_shadow_audit()
	return visual.get_sos_shadow_audit()
end

function item.force_rescue(player)
	player = player or Isaac.GetPlayer(0)
	if not player then
		return false
	end
	local ok, id = ctrl.start_rescue(player, { force = true })
	if ok then
		local pkey = state.player_key(player)
		if pkey then
			state.consume_comms(pkey)
			state.set_armed(pkey, false)
		end
	end
	return ok, id
end

function item.reset_state()
	ctrl.abort("probe_reset")
	visual.clear_sos_shadow()
	state.reset_all()
	local ops = require("Qing_Remaster_scripts.items.alien_savior.ops")
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if p then
			ops.sync_alien_head_costume(p)
		end
	end
end

function item.abort_rescue()
	ctrl.abort("probe_abort")
end

function item.force_phase(name)
	return ctrl.force_phase(name)
end

function item.get_debug_summary()
	local p = Isaac.GetPlayer(0)
	local pkey = state.player_key(p)
	local snap = state.snapshot(pkey)
	return string.format(
		"comm=%s cd=%s armed=%s\n%s",
		tostring(snap.comm),
		tostring(snap.cooldown_left),
		tostring(snap.armed),
		ctrl.summary()
	)
end

-- Damage: SOS arm or rescue intercept.
table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
	CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG,
	params = EntityType.ENTITY_PLAYER,
	priority = -50,
	Function = function(_, ent, amt, flag, source, cooldown)
		local player = ent and ent:ToPlayer()
		if not player then
			return nil
		end
		-- Rescue protection must work even if the collectible is briefly missing mid-txn.
		if ctrl.protects_player(player) then
			return false
		end
		if not holds(player) then
			return nil
		end
		if not combat_room() then
			return nil
		end
		if not qualifying_hit(ent, amt, flag, source, cooldown) then
			return nil
		end
		local pkey = state.player_key(player)
		if not pkey then
			return nil
		end
		if not state.is_ready(pkey) then
			-- Cooling: no new SOS (avoid false hope).
			return nil
		end
		if not state.is_armed(pkey) then
			arm_sos(player)
			return nil -- damage applies; shadow FX is non-blocking
		end
		-- Second hit: start rescue first; only then consume + intercept.
		local ok = ctrl.start_rescue(player)
		if not ok then
			return nil
		end
		state.consume_comms(pkey)
		state.set_armed(pkey, false)
		return false
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		if not g.is_gameplay_world_active or not g.is_gameplay_world_active() then
			return
		end
		ctrl.on_update()
		visual.update_sos_shadow()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE,
	params = nil,
	Function = function(_, player)
		if not player then
			return
		end
		if holds(player) or ctrl.protects_player(player) then
			ctrl.on_player_update(player)
		end
		if holds(player) then
			-- Keep temporary Alien_Head aligned with COOLDOWN / READY (Continue-safe).
			local ops = require("Qing_Remaster_scripts.items.alien_savior.ops")
			ops.sync_alien_head_costume(player)
		end
	end,
})

local function alien_sandwich_active(player)
	local txn = ctrl.get_active and ctrl.get_active()
	if not txn or not player then
		return false
	end
	if txn.player_hash and GetPtrHash(player) ~= txn.player_hash then
		return false
	end
	return as_motion.use_player_sandwich(txn) == true
end

-- UFO sandwich: player_visual_render_holder behind/front proxies (not PRE_PLAYER_RENDER).
player_visual_render.register({
	id = "alien_savior",
	behind = {
		active = alien_sandwich_active,
		render = function(ctx)
			ctrl.on_pre_player_render(ctx.player)
		end,
	},
	front = {
		active = alien_sandwich_active,
		render = function(ctx)
			ctrl.on_post_player_render(ctx.player)
		end,
	},
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_RENDER,
	params = nil,
	Function = function()
		if not g.is_gameplay_world_active or not g.is_gameplay_world_active() then
			return
		end
		-- Flyover first so it reads as a ground/overhead pass under UI chrome.
		visual.render_sos_shadow()
		ctrl.on_render()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		ctrl.on_new_room()
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_LEVEL,
	params = nil,
	Function = function()
		ctrl.on_new_level()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD,
	params = nil,
	Function = function()
		-- Clean-award only fires after a real clear; still gate by combat room types.
		local room = Game():GetRoom()
		local kind = room:GetType()
		local ok = kind == RoomType.ROOM_DEFAULT
			or kind == RoomType.ROOM_BOSS
			or kind == RoomType.ROOM_MINIBOSS
			or kind == RoomType.ROOM_CHALLENGE
			or kind == RoomType.ROOM_BOSSRUSH
		if not ok then
			return nil
		end
		for i = 0, Game():GetNumPlayers() - 1 do
			local p = Game():GetPlayer(i)
			if p and holds(p) then
				local pkey = state.player_key(p)
				state.on_combat_clear(pkey)
			end
		end
		return nil
	end,
})

table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_GAME_EXIT,
	params = nil,
	priority = -100,
	Function = function()
		ctrl.on_game_exit()
	end,
})

return item
