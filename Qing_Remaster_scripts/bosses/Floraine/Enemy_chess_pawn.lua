-- Chess Piece entity entry. Combat / route AI lives in chess_piece_controller.

local enums = require("Qing_Remaster_scripts.core.enums")
local defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")
local controller = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_controller")

local item = {
	ToCall = {},
	enemy = enums.Enemies.chess_piece,
	own_key = "Enemies_chess_piece_",
	-- Legacy kind table kept for Boss random picks / debug.
	info = {
		[defs.KIND.QUEEN] = {sprite = defs.get(defs.KIND.QUEEN).spritesheet},
		[defs.KIND.VEHICLE] = {sprite = defs.get(defs.KIND.VEHICLE).spritesheet},
		[defs.KIND.BISHOP] = {sprite = defs.get(defs.KIND.BISHOP).spritesheet},
		[defs.KIND.KNIGHT] = {sprite = defs.get(defs.KIND.KNIGHT).spritesheet},
		[defs.KIND.PAWN] = {sprite = defs.get(defs.KIND.PAWN).spritesheet},
		[defs.KIND.KING] = {sprite = defs.get(defs.KIND.KING).spritesheet},
	},
}

--- Compatible with old 3-arg and Floraine's 4-arg calls:
--- generate_pawn(id, pos, params)
--- generate_pawn(id, pos, vel, params)
function item.generate_pawn(id, pos, vel_or_params, maybe_params)
	return controller.generate_pawn(id, pos, vel_or_params, maybe_params)
end

item.controller = controller
item.defs = defs

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function(_)
		controller.clear_room_occupancy()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	params = nil,
	Function = function(_)
		controller.clear_room_occupancy()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NPC_INIT,
	params = 996,
	Function = function(_, ent)
		if ent.Variant ~= item.enemy then return end
		-- Boss / raw Spawn path: single initialize owner (idempotent if controller.spawn already ran).
		controller.initialize(ent, {
			kind = ent.SubType,
			role = defs.ROLE.COMBAT,
			mode = defs.MODE.AUTONOMOUS,
		})
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_ENTITY_TAKE_DMG,
	params = 996,
	Function = function(_, ent, _amount, _flags, _source, _countdown)
		if ent.Variant ~= item.enemy then return end
		local data = controller.get_data(ent)
		if data and data.damageable == false then
			return false
		end
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_NPC_UPDATE,
	params = 996,
	Function = function(_, ent)
		if ent.Variant ~= item.enemy then return end
		controller.update(ent)
	end,
})

-- Afterimages under the live piece; does not mutate NPC Sprite.
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_NPC_RENDER,
	params = 996,
	Function = function(_, ent, _offset)
		if ent.Variant ~= item.enemy then return end
		controller.render_afterimages(ent)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE,
	params = 996,
	Function = function(_, ent)
		if ent.Variant ~= item.enemy then return end
		controller.on_remove(ent)
	end,
})

-- Floraine V2 P1: command-soul inheritance on true combat death only.
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NPC_DEATH,
	params = 996,
	Function = function(_, ent)
		if not ent or ent.Variant ~= item.enemy then return end
		local data = controller.get_data(ent)
		if not data or not data.floraine_command then
			return
		end
		local ok, souls = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.command_souls")
		if ok and souls and souls.notify_npc_death then
			souls.notify_npc_death(ent)
		end
	end,
})

return item
