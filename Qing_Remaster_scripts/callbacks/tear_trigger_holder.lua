-- tear_trigger_holder (M8 / M8.1 shim).
-- Generators retired: no POST_FIRE_TRIGGER* emission.
-- Do NOT bridge trigger_tear → EmitSyntheticSample (legacy API must stay dead).
-- Synthetic / existing-Attack samples: attack_trigger_holder.EmitSyntheticSample / EmitDpsSample.
local item = {
	ToCall = {},
	myToCall = {},
	post_myToCall = {},
	own_key = "tear_trigger_holder_",
}

--- Legacy pseudo-fire hook. Intentionally no-op; callers must migrate to Attack Holder APIs.
function item.trigger_tear(_tp, _ent, _pos, _player, _vel, _rate)
end

--- Superseded by attack_trigger_holder POST_ATTACK_ONCE. Kept as no-op.
function item.trigger_attack_once(_tp, _ent, _pos, _player, _vel)
end

function item.trigger_enabled(_tp)
	return false
end

function item.should_ignore_trigger(_ent)
	return true
end

function item.framecheck(_tp, _ent, _player, _params)
	return false
end

function item.check_rate(_tp, _data, _rate, _params)
	return false
end

function item.multi_check(_tp, _ent, _player)
	return false
end

--- Optional helpers still referenced by archived probes / notes.
function item.is_weapon_laser(ent)
	if not ent or ent.Type ~= EntityType.ENTITY_LASER then return false end
	local sub = ent.SubType or 0
	if sub == 1 or sub == 2 then return true end
	local v = ent.Variant or -1
	return v == 1 or v == 2 or v == 6 or v == 9 or v == 11 or v == 12 or v == 14 or v == 15
end

function item.laser_attack_once_tp(ent)
	if not ent then return nil end
	if ent.SubType == 2 then return "LaserX" end
	if ent.SubType == 1 then return "LaserLudo" end
	if ent.Variant == 2 then return "Laser" end
	return "BrimFire"
end

function item.try_laser_attack_once(_ent)
	return false
end

return item
