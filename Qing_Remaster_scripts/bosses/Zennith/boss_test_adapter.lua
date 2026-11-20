-- Zennith Boss Test Lab adapter (ID: zennith).
-- Practice only. Does not write Wind story materials / Zennith_end.

local boss_test_registry = require("Qing_Remaster_scripts.bosses.boss_test_registry")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local arena_room = require("Qing_Remaster_scripts.threads.wind.arena_room")
local encounter = require("Qing_Remaster_scripts.threads.wind.storm_encounter")
local Zennith = require("Qing_Remaster_scripts.bosses.Zennith.Zennith")
local combat_p1 = require("Qing_Remaster_scripts.bosses.Zennith.combat_p1")
local boss_wind = require("Qing_Remaster_scripts.bosses.Zennith.boss_wind_controller")

local TEST_REQ = "boss_test_zennith"

local function in_arena()
	return select(1, arena_room.validate_current()) == true
end

local function find_boss()
	local list = Zennith.living_bosses and Zennith.living_bosses() or {}
	return list[1]
end

local function require_boss()
	if not in_arena() then
		return nil, "not_in_zennith_arena"
	end
	local ent = find_boss()
	if not auxi.check_all_exists(ent) then
		return nil, "no_boss"
	end
	return ent
end

local function mark_practice(ent)
	if ent and ent.GetData then
		ent:GetData().qing_wind_test_request = TEST_REQ
	end
	encounter.mark_story_owned(false)
	encounter.set_test_request(TEST_REQ)
end

--- Ensure Arena + boss exist. Does NOT reset an existing P1 session.
local function ensure_battle()
	if not in_arena() then
		return false, "not_in_arena"
	end
	encounter.mark_story_owned(false)
	encounter.set_test_request(TEST_REQ)
	local ent = find_boss()
	if not auxi.check_all_exists(ent) then
		local ok, err = encounter.open_battle_now()
		if not ok and err ~= "checklist" then
			local entered = encounter.enter_arena_battle()
			ent = find_boss()
			if auxi.check_all_exists(ent) then
				Zennith.set_intro_locked(ent, false)
				if encounter.set_phase then
					encounter.set_phase(encounter.PHASE and encounter.PHASE.BATTLE or "BATTLE")
				end
			elseif not entered then
				return false, err or "enter_failed"
			end
		end
		ent = find_boss()
	end
	if not auxi.check_all_exists(ent) then
		return false, "no_boss"
	end
	mark_practice(ent)
	if Zennith.is_intro_locked(ent) then
		Zennith.set_intro_locked(ent, false)
	end
	if not combat_p1.has_session(ent) then
		combat_p1.begin(ent, {force_p1 = false, cooldown = 18})
	end
	return true, ent
end

local function reset_p1(opts)
	opts = opts or {}
	local ok, ent_or_err = ensure_battle()
	if not ok then return false, ent_or_err end
	local ent = find_boss()
	combat_p1.begin(ent, {
		force_p1 = opts.force_p1 == true,
		cooldown = opts.cooldown or 18,
	})
	return true, ent
end

local adapter = {
	id = "zennith",
	capabilities = {
		hp_control = true,
		freeze = true,
		wall_layers = true,
	},
	hp_presets = {100, 80, 66, 65, 50},
	states = {
		{id = "p1", label = "P1 · 风的号令"},
		{id = "p1_loop", label = "P1 · 强制循环"},
		{id = "p1_complete", label = "P1 · 完成态"},
	},
	attacks = combat_p1.attack_defs(),
}

function adapter.set_wall_layer(name, on)
	return combat_p1.set_wall_layer(name, on)
end

function adapter.get_wall_layers()
	return combat_p1.get_wall_layers()
end

--- Dedicated Zennith combat diagnostics (not the generic Boss Test summary).
function adapter.format_combat_diag()
	local ent = find_boss()
	local info = {
		has_session = false,
		combat_phase = "-",
		attack_state = "-",
		arena = in_arena(),
		boss = auxi.check_all_exists(ent) == true,
	}
	if auxi.check_all_exists(ent) then
		local c = combat_p1.inspect(ent)
		for k, v in pairs(c) do
			info[k] = v
		end
		info.hp_ratio = ent.HitPoints / math.max(1, ent.MaxHitPoints)
	end
	return combat_p1.format_combat_diag(info)
end

function adapter.copy_combat_diag()
	local text = adapter.format_combat_diag()
	if ImGui and ImGui.SetClipboardText then
		ImGui.SetClipboardText(text)
		return true, "copied"
	end
	if Isaac and Isaac.SetClipboard then
		Isaac.SetClipboard(text)
		return true, "copied"
	end
	return false, "no_clipboard"
end

function adapter.get_label()
	return "Zennith / 泽妮丝"
end

function adapter.spawn()
	if not in_arena() then
		encounter.set_test_request(TEST_REQ)
		encounter.mark_story_owned(false)
		local ok, err = encounter.arm_direct_battle()
		if not ok then
			return false, err or "arm_direct_failed"
		end
		return false, "goto_arena_issued_reenter_then_spawn"
	end
	local ok, why = reset_p1({force_p1 = true, cooldown = 18})
	if not ok then return false, why end
	return true, "combat_started"
end

function adapter.restart()
	if not in_arena() then
		return adapter.spawn()
	end
	local ent = find_boss()
	if auxi.check_all_exists(ent) then
		if Zennith.abort_death_fx then Zennith.abort_death_fx() end
		combat_p1.shutdown(ent)
		ent:Remove()
	end
	boss_wind.clear()
	encounter.mark_story_owned(false)
	encounter.set_test_request(TEST_REQ)
	local ok, why = reset_p1({force_p1 = true, cooldown = 12})
	if not ok then return false, why end
	local boss = find_boss()
	if boss then
		boss.HitPoints = boss.MaxHitPoints
	end
	return true, "restarted"
end

function adapter.cleanup()
	if Zennith.abort_death_fx then Zennith.abort_death_fx() end
	local ent = find_boss()
	if auxi.check_all_exists(ent) then
		combat_p1.shutdown(ent)
		ent:Remove()
	end
	boss_wind.clear()
	encounter.set_test_request(nil)
	encounter.mark_story_owned(false)
	return true, "cleaned"
end

function adapter.kill()
	local ent, why = require_boss()
	if not ent then return false, why end
	mark_practice(ent)
	combat_p1.shutdown(ent)
	ent:Kill()
	return true, "defeated_practice_no_unlock"
end

function adapter.force_state(id)
	local ok, why = ensure_battle()
	if not ok then return false, why end
	local ent = find_boss()
	if id == "p1" then
		ent.HitPoints = ent.MaxHitPoints
		return reset_p1({force_p1 = false, cooldown = 18})
	elseif id == "p1_loop" then
		ent.HitPoints = ent.MaxHitPoints * 0.8
		return reset_p1({force_p1 = true, cooldown = 12})
	elseif id == "p1_complete" then
		ent.HitPoints = ent.MaxHitPoints * 0.64
		reset_p1({force_p1 = false, cooldown = 999})
		combat_p1.tick(ent)
		return true, "p1_complete"
	end
	return false, "invalid_state"
end

function adapter.play_attack(id)
	local ok, why = ensure_battle()
	if not ok then return false, why end
	local ent = find_boss()
	return combat_p1.force_attack(ent, id)
end

function adapter.next_attack()
	local ok, why = ensure_battle()
	if not ok then return false, why end
	return combat_p1.next_attack(find_boss())
end

function adapter.reset_attack()
	local ent = find_boss()
	if not ent then return false, "no_boss" end
	return combat_p1.cancel(ent)
end

function adapter.clear_objects()
	local ent = find_boss()
	if not ent then
		combat_p1.shutdown(nil)
		boss_wind.clear()
		return true, "no_boss_cleared_global"
	end
	combat_p1.clear_objects(ent)
	return true, "cleared"
end

function adapter.set_hp_ratio(ratio)
	local ent, why = require_boss()
	if not ent then return false, why end
	ratio = math.max(0.01, math.min(1, tonumber(ratio) or 1))
	ent.HitPoints = ent.MaxHitPoints * ratio
	return true
end

function adapter.set_frozen(on)
	local ent, why = require_boss()
	if not ent then return false, why end
	return combat_p1.set_frozen(ent, on)
end

function adapter.step(n)
	local ent, why = require_boss()
	if not ent then return false, why end
	return combat_p1.step(ent, n)
end

function adapter.inspect()
	local arena_ok = in_arena()
	local ent = find_boss()
	local info = {
		arena = arena_ok,
		boss = auxi.check_all_exists(ent) == true,
		story_owned = encounter.is_story_owned and encounter.is_story_owned() or false,
		encounter_phase = encounter.get_phase and encounter.get_phase() or "-",
	}
	if auxi.check_all_exists(ent) then
		info.hp_ratio = ent.HitPoints / math.max(1, ent.MaxHitPoints)
		info.intro_locked = Zennith.is_intro_locked(ent) == true
		local c = combat_p1.inspect(ent)
		for k, v in pairs(c) do
			info[k] = v
		end
		-- Lab banner: boss combat phase, not attack sub-state.
		info.phase = info.combat_phase
		info.attack_phase = c.attack_state
	end
	return info
end

boss_test_registry.register("zennith", adapter)

return adapter
