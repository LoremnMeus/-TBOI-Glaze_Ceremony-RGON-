-- Floraine P1→P2 (and later) phase-transition executor.
-- Owned by controller; not a global phase infrastructure.

local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")
local visual = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.visual")
local director = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.director")
local reserve_controller = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_controller")
local deployment = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.deployment")
local command_souls = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.command_souls")
local command_particles = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.command_particles")
local temp_piece = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.temp_piece")
local royal_drop = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.royal_drop")
local staff_transition = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.staff_transition")
local occupancy = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_occupancy")
local piece_matte = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.piece_matte_fx")
local enums = require("Qing_Remaster_scripts.core.enums")

local pt = {}

local evac = {
	active = false,
	items = {}, -- { kind="npc"|"matte"|"proxy", ent=, start=, tilt=, elapsed= }
	session_id = 0,
}

local function piece_controller()
	local ok, mod = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.chess_piece_controller")
	if ok then return mod end
	return nil
end

local function freeze_npc(ent)
	if not ent or not ent.Exists or not ent:Exists() then
		return
	end
	local pc = piece_controller()
	if pc then
		local data = ent:GetData() and ent:GetData().QingChessPiece
		if data then
			data.action_state = "IDLE"
			data.current_command = nil
			data.attack_enabled = false
			data.frozen_evac = true
		end
		if pc.occupancy and pc.occupancy.unregister then
			pcall(function()
				pc.occupancy.unregister(GetPtrHash(ent))
			end)
		end
	end
	if ent.CollisionDamage ~= nil then
		ent.CollisionDamage = 0
	end
	ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	ent.Velocity = Vector.Zero
end

local function collect_evac_targets()
	local items = {}
	-- Active combat chess NPCs.
	for _, ent in ipairs(Isaac.FindByType(996, enums.Enemies.chess_piece, -1, false, false)) do
		if ent:Exists() and not ent:IsDead() then
			freeze_npc(ent)
			items[#items + 1] = {
				kind = "npc",
				ent = ent,
				start = Vector(ent.Position.X, ent.Position.Y),
				height0 = -(ent.PositionOffset and ent.PositionOffset.Y or 0),
				tilt = 0,
				elapsed = 0,
				alpha = 1,
			}
		end
	end
	-- Reserve matte effects still on the board.
	local ok_r, rows = pcall(function()
		return reserve_controller.list_visual_entities and reserve_controller.list_visual_entities()
	end)
	if ok_r and type(rows) == "table" then
		for _, ent in ipairs(rows) do
			if ent and ent.Exists and ent:Exists() then
				items[#items + 1] = {
					kind = "matte",
					ent = ent,
					start = Vector(ent.Position.X, ent.Position.Y),
					height0 = -(ent.PositionOffset and ent.PositionOffset.Y or 0),
					tilt = 0,
					elapsed = 0,
					alpha = 1,
				}
			end
		end
	else
		-- Sweep matte effects by variant.
		local v = enums.Entities.Floraine_Matte_Piece
		if v and v >= 0 then
			for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, v, -1, false, false)) do
				if piece_matte.is_matte(ent) then
					items[#items + 1] = {
						kind = "matte",
						ent = ent,
						start = Vector(ent.Position.X, ent.Position.Y),
						height0 = -(ent.PositionOffset and ent.PositionOffset.Y or 0),
						tilt = 0,
						elapsed = 0,
						alpha = 1,
					}
				end
			end
		end
	end
	return items
end

local function tick_evac()
	if not evac.active then
		return true
	end
	local room = Game():GetRoom()
	local bottom = room:GetBottomRightPos().Y + 80
	local keep = {}
	for i = 1, #evac.items do
		local it = evac.items[i]
		local ent = it.ent
		if not ent or not ent.Exists or not ent:Exists() then
			-- already gone
		else
			it.elapsed = (it.elapsed or 0) + 1
			local e = it.elapsed
			local height = it.height0 or 0
			local tilt = 0
			local alpha = 1
			local pos = Vector(it.start.X, it.start.Y)
			if e <= 8 then
				-- flash
				if ent.SetColor then
					ent:SetColor(Color(1, 0.4, 0.4, 1, 0.3, 0.05, 0.05), 2, 1, true, false)
				end
			elseif e <= 22 then
				local t = (e - 8) / 14
				height = (it.height0 or 0) + 24 * t
				tilt = -8 * t
			else
				local t = math.min(1, (e - 22) / 32)
				height = (it.height0 or 0) + 24 - 10 * t
				tilt = -8 - 12 * t
				pos = Vector(it.start.X, it.start.Y + (bottom - it.start.Y) * (t * t))
				alpha = 1 - t
			end
			ent.Position = pos
			ent.PositionOffset = Vector(0, -height)
			ent.Velocity = Vector.Zero
			local spr = ent.GetSprite and ent:GetSprite()
			if spr then
				spr.Rotation = tilt
				spr.Color = Color(1, 1, 1, math.max(0, alpha), 0, 0, 0)
			end
			if e > 65 or pos.Y > bottom then
				if it.kind == "npc" then
					ent:Remove()
				else
					piece_matte.remove(ent)
				end
			else
				keep[#keep + 1] = it
			end
		end
	end
	evac.items = keep
	if #keep < 1 then
		evac.active = false
		return true
	end
	return false
end

function pt.begin(session, boss_ent, to_phase, reason)
	session = session or {}
	session.state = defs.STATE.PHASE_TRANSITION
	session.frame = 0
	session.pending_phase = to_phase or defs.PHASE.P2
	session.transition_reason = reason or "hp_threshold"
	session.transition_stage = defs.TRANSITION_STAGE.LOCK
	session.transition_id = (session.transition_id or 0) + 1

	director.stop_orders()
	royal_drop.clear("phase_transition")
	temp_piece.clear_all("phase_transition")
	deployment.cancel_all("phase_transition")

	-- Capture visuals BEFORE clearing reserve / souls.
	evac.session_id = session.transition_id
	evac.items = collect_evac_targets()
	evac.active = #evac.items > 0

	-- Stop inheritance / combat ownership; keep in-flight return particles if any.
	command_souls.set_suppress_death(true)
	-- Soft-clear command table without wiping particles mid-flight for the last return.
	if command_souls.clear_logic then
		command_souls.clear_logic("phase_transition")
	else
		-- Fall through: stop_phase clears particles — only if no returning visual needed.
		command_souls.stop_phase()
	end
	command_souls.set_suppress_death(false)
	reserve_controller.clear("phase_transition")

	if boss_ent then
		local data = boss_ent:GetData()[defs.DATA_KEY]
		if data then
			data.invulnerable = true
		end
		visual.stagger(boss_ent)
		visual.flash(boss_ent, 0.55, 0.05, 0.05, 18)
		Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BLOOD_EXPLOSION, 0,
			boss_ent.Position + Vector(0, -20), Vector.Zero, boss_ent)
		-- Body recoil via PositionOffset (staff will detach separately).
		boss_ent.PositionOffset = Vector(-10, -4)
	end

	staff_transition.begin(boss_ent, session.transition_id)
	return true
end

local function stage_for_frame(f)
	local tl = defs.TRANSITION_TIMELINE or {}
	if f < (tl.LOCK_END or 4) then
		return defs.TRANSITION_STAGE.LOCK
	elseif f < (tl.STAGGER_END or 12) then
		return defs.TRANSITION_STAGE.STAGGER
	elseif f < (tl.CLEAR_END or 70) then
		return defs.TRANSITION_STAGE.CLEAR_PIECES
	elseif f < (tl.STAFF_FALL_END or 88) then
		return defs.TRANSITION_STAGE.STAFF_FALL
	elseif f < (tl.STAFF_GROUND_END or 110) then
		return defs.TRANSITION_STAGE.STAFF_GROUND
	elseif f < (tl.STAFF_RECALL_END or 148) then
		return defs.TRANSITION_STAGE.STAFF_RECALL
	elseif f < (tl.P2_SUMMON_END or 205) then
		return defs.TRANSITION_STAGE.P2_SUMMON
	end
	return defs.TRANSITION_STAGE.FINISH
end

--- Returns true when transition finished and combat may resume at pending_phase.
function pt.tick(session, boss_ent)
	if not session or session.state ~= defs.STATE.PHASE_TRANSITION then
		return false
	end
	local f = session.frame or 0
	session.transition_stage = stage_for_frame(f)

	tick_evac()
	staff_transition.tick(boss_ent)
	visual.tick_chain(boss_ent)

	-- Ease boss recoil back during stagger.
	if boss_ent and f < 30 then
		local t = f / 30
		boss_ent.PositionOffset = Vector(-10 * (1 - t), -4 * (1 - t))
	elseif boss_ent then
		boss_ent.PositionOffset = Vector.Zero
	end

	local tl = defs.TRANSITION_TIMELINE or {}
	-- Begin P2 column summon once.
	if session.transition_stage == defs.TRANSITION_STAGE.P2_SUMMON
		and not session.p2_summon_started
		and session.pending_phase == defs.PHASE.P2 then
		session.p2_summon_started = true
		local ok, cols = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_columns")
		if ok and cols and cols.begin then
			local ok2, why = cols.begin()
			if not ok2 then
				session.p2_summon_fail = why or "begin_failed"
				Isaac.DebugString("[FloraineV2] p2_columns.begin failed: " .. tostring(why))
			end
		end
		local okp, promo = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_promotion")
		if okp and promo and promo.reset then
			promo.reset()
		end
		if boss_ent and visual.command then
			visual.command(boss_ent)
		end
	end

	-- Transition owns P2 entrance: scheduler.tick (and thus p2_columns.tick) only runs
	-- after COMBAT resumes. Without this drive, is_entrance_busy waits forever.
	if session.p2_summon_started and session.pending_phase == defs.PHASE.P2 then
		local ok_drive, cols_drive = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_columns")
		if ok_drive and cols_drive and cols_drive.tick then
			cols_drive.tick()
		end
	end

	if f >= (tl.FINISH_END or 240) then
		-- Hold finish until side-entrance lands (combat must not start mid-fly-in).
		local ok_c, cols = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_columns")
		if ok_c and cols and cols.is_entrance_busy and cols.is_entrance_busy() then
			return false
		end
		-- Ensure evac leftover cleaned.
		for i = 1, #evac.items do
			local it = evac.items[i]
			if it.ent and it.ent.Exists and it.ent:Exists() then
				if it.kind == "npc" then
					it.ent:Remove()
				else
					piece_matte.remove(it.ent)
				end
			end
		end
		evac.items = {}
		evac.active = false
		-- Force staff reattach + boss Idle2 restore if proxy still out.
		if staff_transition.is_detached() then
			staff_transition.clear(boss_ent)
		elseif boss_ent and visual.idle2 then
			visual.idle2(boss_ent)
		end
		command_particles.clear()
		occupancy.clear_blockers_by_owner("floraine_reserve")
		return true
	end
	return false
end

function pt.clear(boss_ent)
	for i = 1, #evac.items do
		local it = evac.items[i]
		if it.ent and it.ent.Exists and it.ent:Exists() then
			if it.kind == "npc" then
				it.ent:Remove()
			else
				piece_matte.remove(it.ent)
			end
		end
	end
	evac.items = {}
	evac.active = false
	staff_transition.clear(boss_ent)
end

function pt.debug_play_clear_only(session, boss_ent)
	evac.session_id = (evac.session_id or 0) + 1
	evac.items = collect_evac_targets()
	evac.active = #evac.items > 0
	return true, #evac.items
end

function pt.debug_play_staff_only(boss_ent)
	return staff_transition.begin(boss_ent, (evac.session_id or 0) + 1)
end

function pt.diag()
	return {
		evac_active = evac.active,
		evac_count = #evac.items,
		staff = staff_transition.diag(),
	}
end

return pt
