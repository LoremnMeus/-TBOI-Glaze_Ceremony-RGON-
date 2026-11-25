-- HP phase resolution and transition bookkeeping.

local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")

local phase = {}

function phase.ratio(ent)
	if not ent or not ent.MaxHitPoints or ent.MaxHitPoints <= 0 then
		return 1
	end
	return math.max(0, math.min(1, ent.HitPoints / ent.MaxHitPoints))
end

--- Floor HP for the next phase (P1→P2 = 70% max, P2→P3 = 35% max).
function phase.threshold_hp(ent, to_phase)
	if not ent or not ent.MaxHitPoints then
		return 0
	end
	to_phase = tonumber(to_phase) or defs.PHASE.P2
	local band = defs.PHASE_HP[to_phase - 1]
	local lo = band and band.lo or 0
	return ent.MaxHitPoints * lo
end

function phase.floor_hp_for_current(ent, current_phase)
	current_phase = tonumber(current_phase) or defs.PHASE.P1
	local band = defs.PHASE_HP[current_phase]
	if not band or not ent or not ent.MaxHitPoints then
		return 0
	end
	return ent.MaxHitPoints * (band.lo or 0)
end

--- Highest phase whose band contains current HP ratio (1/2/3).
function phase.from_hp(ent)
	local r = phase.ratio(ent)
	if r > defs.PHASE_HP[1].lo then
		return defs.PHASE.P1
	elseif r > defs.PHASE_HP[2].lo then
		return defs.PHASE.P2
	end
	return defs.PHASE.P3
end

--- Advance at most one phase per transition; never skip P2 when crossing both thresholds.
function phase.next_target(current, ent)
	current = tonumber(current) or defs.PHASE.P1
	local want = phase.from_hp(ent)
	if want > current then
		return current + 1
	end
	return current
end

function phase.guard_cap(p)
	p = tonumber(p) or 1
	if p == defs.PHASE.P1 then
		local ok, souls = pcall(require, "Qing_Remaster_scripts.bosses.Floraine.floraine_v2.command_souls")
		if ok and souls and souls.get_p1_guard_cap then
			return souls.get_p1_guard_cap()
		end
	end
	return defs.GUARD_CAP[p] or 3
end

return phase
