-- Floraine P1→P2 (and later) phase-transition executor.
-- Owned by controller; not a global phase infrastructure.

local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")
local arena = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.arena")
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

local function append_evac(dst, src)
	if type(src) ~= "table" then
		return
	end
	for i = 1, #src do
		dst[#dst + 1] = src[i]
	end
end

local function dedupe_evac_items(items)
	local out = {}
	local seen = {}
	for i = 1, #items do
		local it = items[i]
		local ent = it and it.ent
		if ent and ent.Exists and ent:Exists() then
			local h = GetPtrHash(ent)
			if not seen[h] then
				seen[h] = true
				out[#out + 1] = it
			end
		end
	end
	return out
end

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
	local half = 24
	local keep = {}
	for i = 1, #evac.items do
		local it = evac.items[i]
		local ent = it.ent
		if not ent or not ent.Exists or not ent:Exists() then
			-- already gone
		else
			it.elapsed = (it.elapsed or 0) + 1
			local e = it.elapsed
			-- Stagger each piece slightly so the scatter is not a single sheet.
			local delay = it.delay or ((i - 1) % 5)
			local height = it.height0 or 0
			local tilt = it.tilt or 0
			local pos = Vector(it.start.X, it.start.Y)
			if e <= 8 then
				if ent.SetColor then
					ent:SetColor(Color(1, 0.4, 0.4, 1, 0.3, 0.05, 0.05), 2, 1, true, false)
				end
				height = it.height0 or 0
			elseif e <= (8 + delay) then
				-- hold height while neighbors start lifting
				height = it.height0 or 0
			elseif e <= 24 + delay then
				local t = (e - 8 - delay) / math.max(1, 16)
				height = (it.height0 or 0) + 24 * t
				tilt = (it.tilt or 0) - 8 * t
			else
				local fly = e - 24 - delay
				local dest = it.fly_dest
				if not dest then
					dest = arena.world_offscreen_below(it.start.X, half, 16)
					it.fly_dest = dest
				end
				local t = math.min(1, fly / 36)
				local ease = t * t
				height = (it.height0 or 0) + 24 - 8 * t
				tilt = (it.tilt or 0) - 8 - 14 * t
				pos = Vector(it.start.X, it.start.Y + (dest.Y - it.start.Y) * ease)
			end
			ent.Position = pos
			ent.PositionOffset = Vector(0, -height)
			ent.Velocity = Vector.Zero
			local spr = ent.GetSprite and ent:GetSprite()
			if spr then
				spr.Rotation = tilt
				-- Keep full alpha until the sprite clears the camera (no premature fade).
				spr.Color = Color(1, 1, 1, 1, 0, 0, 0)
			end
			-- Normal exit: full sprite below camera. e>=300 is failsafe only.
			local done = arena.is_sprite_fully_below_screen(pos, height, half, 48)
			if (not done) and e >= 300 then
				done = true
			end
			if done then
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
	session.transition_kind = "p1_to_p2"
	session.transition_stage = defs.TRANSITION_STAGE.LOCK
	session.transition_id = (session.transition_id or 0) + 1
	session.p2_systems_cleared = false

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
		-- No SetColor phase filter here — P2 identity is columns/staff, not a white tint.
		Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BLOOD_EXPLOSION, 0,
			boss_ent.Position + Vector(0, -20), Vector.Zero, boss_ent)
		-- Body recoil via PositionOffset (staff will detach separately).
		boss_ent.PositionOffset = Vector(-10, -4)
	end

	staff_transition.begin(boss_ent, session.transition_id)
	return true
end

--- P2→P3: take ownership of visible P2 pieces, evacuate, then allow clear_p2_systems.
function pt.begin_p2_to_p3(session, boss_ent, reason)
	session = session or {}
	session.state = defs.STATE.PHASE_TRANSITION
	session.frame = 0
	session.pending_phase = defs.PHASE.P3
	session.transition_reason = reason or "hp_threshold"
	session.transition_kind = "p2_to_p3"
	session.transition_stage = defs.TRANSITION_STAGE.LOCK
	session.transition_id = (session.transition_id or 0) + 1
	session.p2_summon_started = false
	session.p2_systems_cleared = false

	director.stop_orders()
	royal_drop.clear("phase_transition")
	temp_piece.clear_all("phase_transition")
	command_souls.stop_phase()

	local items = {}
	local claimed = {}
	local n_drop, n_promo, n_cols = 0, 0, 0

	local ok_cd, chess_drop = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_chess_drop")
	if ok_cd and chess_drop and chess_drop.take_evac_entities then
		local drop_items = chess_drop.take_evac_entities() or {}
		n_drop = #drop_items
		append_evac(items, drop_items)
	end

	local ok_p, promo = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_promotion")
	if ok_p and promo and promo.take_evac_entities then
		local promo_items, claimed_slots = promo.take_evac_entities()
		promo_items = promo_items or {}
		n_promo = #promo_items
		append_evac(items, promo_items)
		claimed = claimed_slots or {}
	end

	local ok_c, cols = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_columns")
	if ok_c and cols and cols.take_evac_entities then
		local col_items = cols.take_evac_entities(claimed) or {}
		n_cols = #col_items
		append_evac(items, col_items)
	end

	evac.session_id = session.transition_id
	evac.items = dedupe_evac_items(items)
	evac.active = #evac.items > 0
	session.p2_evac_handoff = {
		drop = n_drop,
		promo = n_promo,
		columns = n_cols,
		total = #evac.items,
	}
	Isaac.DebugString(string.format(
		"[Floraine P2→P3] handoff: drop=%d, promo=%d, columns=%d, total=%d",
		n_drop, n_promo, n_cols, #evac.items
	))

	if boss_ent then
		local data = boss_ent:GetData()[defs.DATA_KEY]
		if data then
			data.invulnerable = true
		end
		Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BLOOD_EXPLOSION, 0,
			boss_ent.Position + Vector(0, -20), Vector.Zero, boss_ent)
		boss_ent.PositionOffset = Vector(-8, -3)
		if visual.command then
			visual.command(boss_ent)
		end
		if visual.phase_tint then
			visual.phase_tint(boss_ent, defs.PHASE.P3)
		end
	end
	return true
end

local function stage_for_frame(f)
	local tl = defs.TRANSITION_TIMELINE or {}
	local fall0 = tl.STAFF_FALL_START or 0
	-- Staff windows overlap piece clear; column summon begins at STAFF_FLOAT_END.
	if f < (tl.LOCK_END or 6) and f < fall0 then
		return defs.TRANSITION_STAGE.LOCK
	elseif f < (tl.STAGGER_END or 6) and f < fall0 then
		return defs.TRANSITION_STAGE.STAGGER
	elseif f < fall0 then
		return defs.TRANSITION_STAGE.CLEAR_PIECES
	elseif f < (tl.STAFF_FALL_END or 30) then
		-- Fall overlaps early lock/stagger when FALL_START=0.
		if f < (tl.LOCK_END or 6) then
			return defs.TRANSITION_STAGE.LOCK
		end
		return defs.TRANSITION_STAGE.STAFF_FALL
	elseif f < (tl.STAFF_GROUND_END or 66) then
		return defs.TRANSITION_STAGE.STAFF_GROUND
	elseif f < (tl.STAFF_FLOAT_END or 96) then
		return defs.TRANSITION_STAGE.STAFF_RECALL -- float / glow rise
	elseif f < (tl.STAFF_HOVER_END or 108) then
		return defs.TRANSITION_STAGE.STAFF_RECALL -- hover pause
	elseif f < (tl.STAFF_RECALL_END or 132) then
		return defs.TRANSITION_STAGE.STAFF_RECALL -- fly back
	elseif f < (tl.P2_SUMMON_END or 180) then
		return defs.TRANSITION_STAGE.P2_SUMMON
	end
	return defs.TRANSITION_STAGE.FINISH
end

local function force_clear_evac()
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
end

--- Returns true when transition finished and combat may resume at pending_phase.
function pt.tick(session, boss_ent)
	if not session or session.state ~= defs.STATE.PHASE_TRANSITION then
		return false
	end
	local f = session.frame or 0

	-- P2→P3: evacuate only (no staff show). Clear system tables after visuals leave.
	if session.transition_kind == "p2_to_p3" then
		session.transition_stage = defs.TRANSITION_STAGE.CLEAR_PIECES
		local evac_done = tick_evac()
		visual.tick_chain(boss_ent)
		if boss_ent and f < 20 then
			local t = f / 20
			boss_ent.PositionOffset = Vector(-8 * (1 - t), -3 * (1 - t))
		elseif boss_ent then
			boss_ent.PositionOffset = Vector.Zero
		end
		local tl3 = defs.P2_TO_P3_TIMELINE or {}
		local min_finish = tl3.MIN_FINISH or 28
		if evac_done and f >= min_finish then
			if not session.p2_systems_cleared then
				session.p2_systems_cleared = true
				Isaac.DebugString(string.format(
					"[Floraine P2→P3] evac_done: frames=%d, remaining=0, handoff_total=%s",
					f,
					tostring(session.p2_evac_handoff and session.p2_evac_handoff.total)
				))
				local ok_cd, chess_drop = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_chess_drop")
				if ok_cd and chess_drop and chess_drop.clear then
					chess_drop.clear("to_p3")
				end
				local ok_p, promo = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_promotion")
				if ok_p and promo and promo.clear then
					promo.clear("to_p3")
				end
				local ok_c, cols = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_columns")
				if ok_c and cols and cols.clear then
					cols.clear("to_p3")
				end
			end
			force_clear_evac()
			return true
		end
		return false
	end

	session.transition_stage = stage_for_frame(f)

	tick_evac()
	-- Staff pose follows absolute transition frame (TRANSITION_TIMELINE sole clock).
	staff_transition.tick(boss_ent, f)
	visual.tick_chain(boss_ent)

	-- Ease boss recoil back during stagger.
	if boss_ent and f < 30 then
		local t = f / 30
		boss_ent.PositionOffset = Vector(-10 * (1 - t), -4 * (1 - t))
	elseif boss_ent then
		boss_ent.PositionOffset = Vector.Zero
	end

	local tl = defs.TRANSITION_TIMELINE or {}
	-- Begin P2 column summon during staff float/hover (overlaps recall fly-back).
	if not session.p2_summon_started
		and session.pending_phase == defs.PHASE.P2
		and f >= (tl.STAFF_FLOAT_END or 96) then
		session.p2_summon_started = true
		session.transition_stage = defs.TRANSITION_STAGE.P2_SUMMON
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

	if f >= (tl.FINISH_END or 200) then
		-- Hold finish until side-entrance lands (combat must not start mid-fly-in).
		local ok_c, cols = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_columns")
		if ok_c and cols and cols.is_entrance_busy and cols.is_entrance_busy() then
			return false
		end
		-- Also wait for P1 evacuate leftovers (screen-exit based).
		if evac.active and not tick_evac() then
			return false
		end
		force_clear_evac()
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
	-- Standalone clock maps onto the same STAFF_* windows (no full phase transition).
	return staff_transition.begin(boss_ent, (evac.session_id or 0) + 1, { standalone = true })
end

function pt.diag()
	return {
		evac_active = evac.active,
		evac_count = #evac.items,
		staff = staff_transition.diag(),
	}
end

return pt
