-- Shared soft player push for Floraine matte pieces (ante / P1 reserve / P2 columns).
-- Logic-frame only. Does not deal damage; callers decide damage separately.

local reserve_defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.reserve_defs")

local soft = {}

function soft.default_radius()
	return (reserve_defs.GRID or 40) * 0.45
end

function soft.default_strength()
	return 3.5
end

--- Push player away from a piece toward room center (horizontal).
-- Returns true if the player overlapped and received a velocity impulse.
function soft.push_player(player, piece_pos, center_x, strength, radius)
	if not player or not piece_pos then
		return false
	end
	if not player.Exists or not player:Exists() or (player.IsDead and player:IsDead()) then
		return false
	end
	radius = radius or soft.default_radius()
	strength = strength or soft.default_strength()
	local delta = player.Position - piece_pos
	if delta:Length() >= radius then
		return false
	end
	local away = Vector((center_x or 0) - player.Position.X, 0)
	if away:LengthSquared() < 1 then
		away = delta
	end
	if away:LengthSquared() < 1 then
		away = Vector(0, 1)
	end
	player.Velocity = player.Velocity + away:Resized(strength)
	return true
end

return soft
