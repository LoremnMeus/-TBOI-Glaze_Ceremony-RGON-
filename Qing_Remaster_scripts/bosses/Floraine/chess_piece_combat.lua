-- Attack active window + player hit. No warning-tile / impact-ring telegraphs.
-- Windup duration and piece motion provide the only attack telegraph for now.

local defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")

local combat = {}

local hit_once = {}

function combat.clear_room()
	hit_once = {}
end

-- Stubs kept so older callers (stone_rooms / interrupt) do not error.
function combat.set_telegraph(_id, _cells, _ttl) end
function combat.clear_telegraph(_id) end
function combat.tick_telegraphs() end
function combat.render_telegraphs() end
function combat.spawn_impact(_pos) end

function combat.line_cells(from, to, step)
	step = step or defs.GRID
	local out = {}
	local delta = to - from
	local len = delta:Length()
	if len < 1 then
		out[1] = from
		return out
	end
	local n = math.max(1, math.floor(len / step + 0.5))
	for i = 0, n do
		out[#out + 1] = from + delta * (i / n)
	end
	return out
end

function combat.adjacent_cells(center)
	local g = defs.GRID
	return {
		center,
		center + Vector(g, 0),
		center + Vector(-g, 0),
		center + Vector(0, g),
		center + Vector(0, -g),
	}
end

--- Deal contact-style damage once per (piece lifetime × attack serial × player).
function combat.try_hit_players(piece, data, radius)
	if not data or not data.attack_active then return end
	local attack_id = data.attack_id or 0
	local piece_key = tostring(GetPtrHash(piece))
	radius = radius or 22
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player and player:Exists() and not player:IsDead() then
			local pindex = player:GetData().__Index
			if pindex == nil then
				pindex = "ci" .. tostring(player.ControllerIndex or i)
			end
			local key = piece_key .. ":" .. tostring(attack_id) .. ":" .. tostring(pindex)
			if not hit_once[key] and player.Position:Distance(piece.Position) <= radius then
				hit_once[key] = true
				player:TakeDamage(data.contact_damage or 1, 0, EntityRef(piece), 20)
			end
		end
	end
end

function combat.begin_attack(data)
	data.attack_id = (data.attack_id or 0) + 1
	data.attack_active = false
end

function combat.set_active(data, active)
	data.attack_active = active == true
end

return combat
