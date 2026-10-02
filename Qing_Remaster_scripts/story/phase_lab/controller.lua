-- Phase Lab room controller: lifecycle, interaction, Mom door, overlay.
-- Coordinates puzzle / materials / anchor. Does not own Interstice.

local enums = require("Qing_Remaster_scripts.core.enums")
local defs = require("Qing_Remaster_scripts.story.phase_lab.defs")
local state = require("Qing_Remaster_scripts.story.phase_lab.state")
local puzzle = require("Qing_Remaster_scripts.story.phase_lab.puzzle")
local materials = require("Qing_Remaster_scripts.story.phase_lab.materials")
local anchor = require("Qing_Remaster_scripts.story.phase_lab.anchor")
local render = require("Qing_Remaster_scripts.story.phase_lab.render")
local grid_door = require("Qing_Remaster_scripts.grids.grid_doors")
local story = require("Qing_Remaster_scripts.story.story_state")

local controller = {
	ToCall = {},
	myToCall = {},
	_active = false,
	_center = nil,
	_prompt = "",
	_door_spawned = false,
	_door_slot = nil,
	_fixtures = {}, -- PtrHash -> wrapper
}

local DATA_KEY = defs.OWN_KEY .. "fix"

local function tr(zh, en)
	return (Options and Options.Language == "en") and en or zh
end

local function marker_variant()
	return enums.Entities.Phase_Lab_Room_Marker
end

local function fixture_variant()
	return enums.Entities.Phase_Lab_Fixture
end

local function hide_ent(ent)
	if not ent then return end
	ent.Visible = false
	ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	ent:AddEntityFlags(EntityFlag.FLAG_NO_SPRITE_UPDATE | EntityFlag.FLAG_NO_TARGET)
end

function controller.is_lab_room(desc)
	desc = desc or Game():GetLevel():GetCurrentRoomDesc()
	if not desc or not desc.Data then return false end
	return defs.is_lab_variant(desc.Data.Variant)
end

function controller.is_active()
	if controller._active then return true end
	local r = state.get_run(false)
	if r and r.overlay_force then return true end
	return controller.is_lab_room()
end

function controller.room_center()
	if controller._center then return controller._center end
	local room = Game():GetRoom()
	local marker_v = marker_variant()
	if marker_v then
		for _, ent in ipairs(Isaac.FindByType(defs.MARKER_RUNTIME_TYPE, marker_v, defs.MARKER.CENTER, false, false)) do
			hide_ent(ent)
			controller._center = ent.Position
			return controller._center
		end
	end
	controller._center = room:GetCenterPos()
	return controller._center
end

local function clear_fixtures()
	local variant = fixture_variant()
	if not variant then
		controller._fixtures = {}
		return
	end
	for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, variant, -1, false, false)) do
		ent:Remove()
	end
	controller._fixtures = {}
end

local function spawn_fixture(subtype, pos, solid)
	local variant = fixture_variant()
	if not variant or not pos then return nil end
	local ent = Isaac.Spawn(EntityType.ENTITY_EFFECT, variant, subtype, pos, Vector.Zero, nil)
	if not ent then return nil end
	ent.Visible = false
	ent:AddEntityFlags(EntityFlag.FLAG_NO_SPRITE_UPDATE | EntityFlag.FLAG_NO_TARGET | EntityFlag.FLAG_NO_STATUS_EFFECTS)
	if solid then
		ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_PLAYERONLY
		ent.Size = defs.BLOCK_RADIUS
	else
		ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	end
	local d = ent:GetData()
	d[DATA_KEY] = {
		subtype = subtype,
		block_id = defs.FIX_TO_BLOCK[subtype],
	}
	local key = GetPtrHash(ent)
	controller._fixtures[key] = ent
	return ent
end

local function sync_fixture_positions()
	local center = controller.room_center()
	for _, ent in pairs(controller._fixtures) do
		if ent and ent:Exists() then
			local d = ent:GetData()[DATA_KEY]
			if d and d.block_id then
				ent.Position = puzzle.presented_pos(center, d.block_id)
			end
		end
	end
end

function controller.rebuild_entities()
	clear_fixtures()
	local center = controller.room_center()
	local r = state.get_run(true)
	-- Blocks always present while puzzle active OR solved (as static pieces).
	for _, id in ipairs(defs.BLOCK_IDS) do
		local pos = puzzle.presented_pos(center, id)
		spawn_fixture(defs.BLOCK_FIX[id], pos, not puzzle.is_solved() or puzzle.is_replay())
	end
	spawn_fixture(defs.FIX.RESET, center + defs.LAYOUT.reset, false)
	spawn_fixture(defs.FIX.TERMINAL, center + defs.LAYOUT.terminal, false)
	spawn_fixture(defs.FIX.ANCHOR, center + defs.LAYOUT.anchor, false)
	if puzzle.is_solved() and not puzzle.is_replay() then
		for _, def in pairs(defs.MATERIALS) do
			spawn_fixture(def.fix, center + def.offset, false)
		end
	end
	r.room_initialized = true
end

function controller.init_room_state()
	local r = state.get_run(true)
	local permanent = state.get_permanent(true)
	if permanent.puzzle_solved and not r.puzzle.replay_mode then
		puzzle.load_solved({permanent = false})
	elseif not r.room_initialized then
		if permanent.puzzle_solved then
			puzzle.load_solved({permanent = false})
		else
			puzzle.load_initial()
		end
	end
	-- Keep existing runtime states when re-entering mid-run.
	if not r.puzzle.solved and not permanent.puzzle_solved then
		r.puzzle.active = true
	end
	anchor.refresh_ready()
	controller.rebuild_entities()
	controller._active = true
	state.mark_discovered()
end

function controller.shutdown()
	controller._active = false
	controller._center = nil
	controller._prompt = ""
	clear_fixtures()
	local r = state.get_run(false)
	if r then r.overlay_force = false end
end

--- Debug / Story Dev: force lab overlay in the current room.
function controller.teleport_overlay()
	local r = state.get_run(true)
	r.overlay_force = true
	controller._center = nil
	controller.init_room_state()
	-- Soft clear hostiles for testing.
	for _, ent in ipairs(Isaac.GetRoomEntities()) do
		if ent:IsEnemy() and ent:IsVulnerableEnemy() then
			ent:Remove()
		end
	end
	local center = controller.room_center()
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if p then
			p.Position = center + defs.LAYOUT.entry
			p.Velocity = Vector.Zero
		end
	end
	return true
end

function controller.teleport_to_lab()
	-- Prefer dedicated room; fall back to overlay if goto fails visually.
	controller.teleport_overlay()
	Isaac.ExecuteCommand("goto " .. defs.GOTO)
	-- Overlay remains as safety if room missing from STB.
	local r = state.get_run(true)
	r.overlay_force = true
	return true
end

local function nearest_interactable(player)
	if not player then return nil, nil end
	local center = controller.room_center()
	local best, best_d, best_kind = nil, defs.PROMPT_RADIUS, nil

	local function consider(kind, pos, payload)
		if not pos then return end
		local d = player.Position:Distance(pos)
		if d < best_d then
			best_d = d
			best = payload
			best_kind = kind
		end
	end

	if puzzle.is_active() or puzzle.is_replay() then
		for _, id in ipairs(defs.BLOCK_IDS) do
			consider("block", puzzle.presented_pos(center, id), id)
		end
	end
	consider("reset", center + defs.LAYOUT.reset, true)
	if puzzle.is_solved() and not puzzle.is_replay() then
		for key, def in pairs(defs.MATERIALS) do
			consider("slot", center + def.offset, key)
		end
		consider("anchor", center + defs.LAYOUT.anchor, true)
	end
	return best_kind, best
end

local function do_interact(player)
	local kind, payload = nearest_interactable(player)
	if not kind then return false end
	local center = controller.room_center()
	if kind == "block" then
		local ok = puzzle.try_advance(payload, center)
		if ok then
			controller._prompt = tr("相位板移动", "Phase plate moved")
			sync_fixture_positions()
		end
		return ok
	end
	if kind == "reset" then
		puzzle.reset_to_initial()
		anchor.set_state("idle")
		controller.rebuild_entities()
		controller._prompt = tr("相位校准已重置", "Phase calibration reset")
		return true
	end
	if kind == "slot" then
		local ok, err = materials.insert(payload)
		if ok then
			anchor.refresh_ready()
			controller._prompt = tr("材料已安装", "Material installed")
			controller.rebuild_entities()
		elseif err == "missing" then
			controller._prompt = tr("缺少对应材料", "Missing material")
		elseif err == "already" then
			controller._prompt = tr("已安装", "Already installed")
		end
		return ok
	end
	if kind == "anchor" then
		local ok, err = anchor.try_activate()
		if ok then
			controller._prompt = tr("现实坐标锁定…", "Reality anchored…")
		elseif err == "not_ready" then
			controller._prompt = tr("相位锚尚未就绪", "Anchor not ready")
		end
		return ok
	end
	return false
end

local function update_prompt(player)
	local kind = nearest_interactable(player)
	if not kind then
		if controller._prompt and controller._prompt ~= "" then
			-- keep brief feedback
		else
			controller._prompt = ""
		end
		return
	end
	if kind == "block" then
		controller._prompt = tr("[丢弃键] 移动相位板", "[Drop] Move phase plate")
	elseif kind == "reset" then
		if state.is_puzzle_solved_permanent() and puzzle.is_solved() and not puzzle.is_replay() then
			controller._prompt = tr("[丢弃键] 重新校准相位法阵", "[Drop] Recalibrate array")
		else
			controller._prompt = tr("[丢弃键] 重置当前校准", "[Drop] Reset calibration")
		end
	elseif kind == "slot" then
		controller._prompt = tr("[丢弃键] 安装材料", "[Drop] Install material")
	elseif kind == "anchor" then
		if anchor.get_state() == "ready" then
			controller._prompt = tr("[丢弃键] 启动相位锚", "[Drop] Activate Phase Anchor")
		else
			controller._prompt = tr("相位锚未就绪", "Anchor not ready")
		end
	end
end

local function mausoleum_boss_floor()
	local level = Game():GetLevel()
	local stage = level:GetStage()
	local st = level:GetStageType()
	if stage ~= LevelStage.STAGE4_2 then return false end
	return st == StageType.STAGETYPE_REPENTANCE or st == StageType.STAGETYPE_REPENTANCE_B
end

function controller.try_spawn_lab_door()
	if controller._door_spawned then return false end
	local room = Game():GetRoom()
	if room:GetType() ~= RoomType.ROOM_BOSS then return false end
	if not mausoleum_boss_floor() then return false end
	-- Prefer a free side door; fall back to RIGHT0.
	local slot = DoorSlot.RIGHT0
	for _, s in ipairs({DoorSlot.RIGHT0, DoorSlot.LEFT0, DoorSlot.UP0, DoorSlot.DOWN0}) do
		if room:IsDoorSlotAllowed(s) and not room:GetDoor(s) then
			slot = s
			break
		end
	end
	grid_door.try_spawn_grid_door(room, slot, nil, {
		check_and_leave = defs.GOTO,
		loadname = "gfx/grid/door_mausoleum.anm2",
		playname = "Reveal",
		should_update = true,
		tp = RoomType.ROOM_DEFAULT,
		on_update = function(doorinfo)
			local door = doorinfo.door
			if not door then return end
			local s = door:GetSprite()
			local name = s:GetAnimation()
			if s:IsFinished(name) then
				if name == "Reveal" or name == "Open" then
					s:Play("Opened", true)
					door.CollisionClass = GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER
				end
			end
		end,
	})
	controller._door_spawned = true
	controller._door_slot = slot
	state.mark_discovered()
	return true
end

-- Callbacks
table.insert(controller.ToCall, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		controller._center = nil
		controller._prompt = ""
		-- Hide markers if present.
		local mv = marker_variant()
		if mv then
			for _, ent in ipairs(Isaac.FindByType(defs.MARKER_RUNTIME_TYPE, mv, -1, false, false)) do
				hide_ent(ent)
			end
		end
		if controller.is_lab_room() then
			local r = state.get_run(true)
			r.overlay_force = false
			controller.init_room_state()
			return
		end
		local r = state.get_run(false)
		if r and r.overlay_force then
			controller.init_room_state()
			return
		end
		controller._active = false
		clear_fixtures()
	end,
})

table.insert(controller.ToCall, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		if not controller.is_active() then return end
		local event = puzzle.tick()
		if event == "solved" then
			controller._prompt = tr("相位法阵已校准", "Phase array calibrated")
			-- Runtime completion: grant phase-anchor token + node.
			pcall(function()
				if not story.has_token("chapter1.material.phase_anchor") then
					story.grant_token("chapter1.material.phase_anchor")
				end
				if not story.is_node_completed("chapter1", "chapter1.phase_anchor") then
					story.complete_node("chapter1", "chapter1.phase_anchor")
				end
			end)
			controller.rebuild_entities()
			anchor.refresh_ready()
		end
		local aev = anchor.tick()
		if aev == "open" then
			controller._prompt = tr("他界通道已打开（占位）", "Interstice gate open (stub)")
		end
		sync_fixture_positions()
		anchor.refresh_ready()
	end,
})

table.insert(controller.ToCall, {
	CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE,
	params = nil,
	Function = function(_, player)
		if not controller.is_active() or not player then return end
		update_prompt(player)
		local ctrl = player.ControllerIndex
		if Input.IsActionTriggered(defs.INTERACT, ctrl) then
			do_interact(player)
		end
	end,
})

table.insert(controller.ToCall, {
	CallBack = ModCallbacks.MC_POST_RENDER,
	params = nil,
	Function = function()
		if not Game():GetRoom() then return end
		if controller.is_active() then
			render.draw_lab(controller.room_center(), {prompt = controller._prompt})
		elseif controller._door_spawned and controller._door_slot ~= nil then
			local door = Game():GetRoom():GetDoor(controller._door_slot)
			if door then
				render.draw_door_hint(door.Position)
			end
		end
	end,
})

table.insert(controller.ToCall, {
	CallBack = ModCallbacks.MC_POST_NPC_DEATH,
	params = nil,
	Function = function(_, npc)
		if not npc or not npc:IsBoss() then return end
		if not mausoleum_boss_floor() then return end
		local room = Game():GetRoom()
		if room:GetType() ~= RoomType.ROOM_BOSS then return end
		-- Mom / Mom's Heart family on Mausoleum/Gehenna II.
		local t = npc.Type
		if t == EntityType.ENTITY_MOM
			or t == EntityType.ENTITY_MOMS_HEART
			or t == EntityType.ENTITY_MOTHER
		then
			controller.try_spawn_lab_door()
		end
	end,
})

table.insert(controller.myToCall, {
	CallBack = enums.Callbacks.PRE_NEW_LEVEL,
	params = nil,
	Function = function()
		controller._door_spawned = false
		controller._door_slot = nil
		local r = state.get_run(false)
		if r then r.overlay_force = false end
	end,
})

-- Public API for tests
controller.puzzle = puzzle
controller.materials = materials
controller.anchor = anchor
controller.state = state
controller.defs = defs

return controller
