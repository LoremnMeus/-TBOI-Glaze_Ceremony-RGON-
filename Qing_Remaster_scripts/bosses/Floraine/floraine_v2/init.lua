-- Floraine Boss V2 public façade: sole NPC callback owner + Effect callbacks.

local enums = require("Qing_Remaster_scripts.core.enums")
local arena = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.arena")
local controller = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.controller")
local director = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.director")
local rewards = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.rewards")
local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")
local temp_piece = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.temp_piece")
local scheduler = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.scheduler")
local ante_formation = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.ante_formation")
local reserve_controller = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_controller")
local reserve_visual = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_visual")
local deployment = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.deployment")
local reserve_defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_defs")
local command_souls = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.command_souls")
local command_particles = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.command_particles")
local royal_drop = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.royal_drop")
local staff_transition = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.staff_transition")
local p2_columns = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_columns")
local p2_promotion = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_promotion")
local p2_chess_drop = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_chess_drop")
local phase_transition = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.phase_transition")
local opening_camera = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.opening_camera")

local v2 = {
	ToCall = {},
	defs = defs,
	arena = arena,
	controller = controller,
	director = director,
	rewards = rewards,
	temp_piece = temp_piece,
	scheduler = scheduler,
	ante_formation = ante_formation,
	reserve_controller = reserve_controller,
	reserve_visual = reserve_visual,
	deployment = deployment,
	reserve_defs = reserve_defs,
	command_souls = command_souls,
	command_particles = command_particles,
	royal_drop = royal_drop,
	staff_transition = staff_transition,
	p2_columns = p2_columns,
	p2_promotion = p2_promotion,
	p2_chess_drop = p2_chess_drop,
	phase_transition = phase_transition,
	opening_camera = opening_camera,
}

local FLORAINE_VARIANT = enums.Enemies.Floraine

local function is_floraine_npc(ent)
	return ent ~= nil and ent.Type == 996 and ent.Variant == FLORAINE_VARIANT
end

--- V2 owns Floraine NPCs stamped with DATA_KEY, or any Floraine inside the Stone arena room.
local function should_handle_npc(ent)
	if not is_floraine_npc(ent) then
		return false
	end
	if controller.is_owned(ent) then
		return true
	end
	return arena.is_arena_room() == true
end

function v2.is_arena_room(desc)
	return arena.is_arena_room(desc)
end

function v2.is_owned(ent)
	return controller.is_owned(ent)
end

function v2.update(ent)
	controller.update(ent)
end

function v2.on_take_damage(ent, amt, flag, source, cooldown)
	return controller.on_take_damage(ent, amt, flag, source, cooldown)
end

function v2.on_enter_room()
	arena.on_enter()
end

function v2.on_leave_room()
	arena.on_leave()
end

-- NPC Update: sole Floraine Boss tick owner.
table.insert(v2.ToCall, #v2.ToCall + 1, {
	CallBack = ModCallbacks.MC_NPC_UPDATE,
	params = 996,
	Function = function(_, ent)
		if not should_handle_npc(ent) then
			return
		end
		-- Spawn stamps DATA_KEY after Isaac.Spawn returns; Init may race, Update should not.
		if not controller.is_owned(ent) then
			return
		end
		controller.update(ent)
	end,
})

-- Damage: sole Floraine Boss damage owner.
table.insert(v2.ToCall, #v2.ToCall + 1, {
	CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG,
	params = 996,
	Function = function(_, ent, amt, flag, source, cooldown)
		if not should_handle_npc(ent) then
			return
		end
		if not controller.is_owned(ent) then
			-- Unowned Floraine in arena: block until V2 stamp (spawn frame).
			if arena.is_arena_room() then
				return false
			end
			return
		end
		return controller.on_take_damage(ent, amt, flag, source, cooldown)
	end,
})

-- Legacy tear/knife weirdness vs Floraine (Mom's Knife / certain special tears).
table.insert(v2.ToCall, #v2.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_TEAR_COLLISION,
	params = nil,
	Function = function(_, tear, col, _low)
		if not col or col.Type ~= 996 or col.Variant ~= FLORAINE_VARIANT then
			return
		end
		if not should_handle_npc(col) then
			return
		end
		if tear.Variant == 45 or tear.Variant == 9 then
			return false
		end
	end,
})

local temp_variant = enums.Entities.Floraine_Temp_Piece

table.insert(v2.ToCall, #v2.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_EFFECT_UPDATE,
	params = temp_variant,
	Function = function(_, effect)
		temp_piece.on_update(effect)
	end,
})

table.insert(v2.ToCall, #v2.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_EFFECT_RENDER,
	params = temp_variant,
	Function = function(_, effect)
		temp_piece.on_render(effect)
	end,
})

table.insert(v2.ToCall, #v2.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function(_)
		temp_piece.clear_all("new_room")
		command_particles.clear()
		royal_drop.clear("new_room")
		p2_chess_drop.clear("new_room")
		p2_promotion.clear("new_room")
		p2_columns.clear("new_room")
		staff_transition.clear(nil)
		opening_camera.clear("new_room")
	end,
})

-- RGON Camera:SetFocusPosition must be reapplied each update frame.
table.insert(v2.ToCall, #v2.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function(_)
		if opening_camera.is_active() then
			opening_camera.apply()
		end
	end,
})

-- Board cell overlays (royal-drop + P2 chess-drop) share stone_board after-tile path.
do
	local ok_b, stone_board = pcall(require, "Qing_Remaster_scripts.threads.stone.stone_board")
	if ok_b and stone_board and stone_board.set_cell_overlay_provider then
		stone_board.set_cell_overlay_provider(function(index)
			if royal_drop.get_board_cell_overlay then
				local o = royal_drop.get_board_cell_overlay(index)
				if o then
					return o
				end
			end
			if p2_chess_drop.get_board_cell_overlay then
				return p2_chess_drop.get_board_cell_overlay(index)
			end
			return nil
		end)
	end
end

-- Command-soul particles + royal air outline + staff proxy (ground mark is NOT here).
table.insert(v2.ToCall, #v2.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_RENDER,
	params = nil,
	Function = function(_)
		if command_particles.count() > 0 then
			command_particles.render()
		end
		if royal_drop.is_busy() and royal_drop.render_air_cues then
			royal_drop.render_air_cues()
		end
		if staff_transition.is_detached and staff_transition.is_detached() then
			staff_transition.render()
		end
	end,
})



-- Redundant death notify path (Enemy_chess_pawn also registers). Deduped by generation / SFX flag.
table.insert(v2.ToCall, #v2.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NPC_DEATH,
	params = 996,
	Function = function(_, ent)
		if not ent or ent.Variant ~= enums.Enemies.chess_piece then
			return
		end
		local piece_controller = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_controller")
		if piece_controller.on_combat_death then
			piece_controller.on_combat_death(ent)
		end
		command_souls.notify_npc_death(ent)
	end,
})


return v2
