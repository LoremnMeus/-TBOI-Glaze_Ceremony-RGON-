-- Enemy lethal/death-interception semantics.
-- current_hit_would_kill: this hit would kill.
-- has_buffered_mortal_damage: lethal damage is already queued.
-- can_intercept_current_death: this hit would kill, and no earlier mortal hit is buffered.
-- Do not OR the first two into a local is_lethal().

local M = {}

function M.has_buffered_mortal_damage(ent)
	return ent
		and ent.HasMortalDamage
		and ent:HasMortalDamage()
		or false
end

function M.current_hit_would_kill(ent, amount, flags)
	if not ent or not amount or amount <= 0 then
		return false
	end

	if flags
	and DamageFlag
	and DamageFlag.DAMAGE_NOKILL
	and flags & DamageFlag.DAMAGE_NOKILL == DamageFlag.DAMAGE_NOKILL then
		return false
	end

	return amount >= ent.HitPoints
end

function M.can_intercept_current_death(ent, amount, flags)
	if not M.current_hit_would_kill(ent, amount, flags) then
		return false
	end

	-- 已有 buffered lethal damage 时，取消“当前这一下”并不能可靠撤销此前已经排队的死亡伤害。
	if M.has_buffered_mortal_damage(ent) then
		return false
	end

	return true
end

return M
