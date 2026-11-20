-- Floraine temp assault Effect: SUMMON → PREPARE → DASH → FADE.
-- Not a Chess Piece NPC; no occupancy / director / CanShutDoors / reinforce count.

local enums = require("Qing_Remaster_scripts.core.enums")
local piece_defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")
local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")
local visual = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.temp_piece_visual")

local temp = {}

local hit_once = {}
local active = {} -- PtrHash → effect wrapper
local serial = 0
local last_cleanup = "none"
local last_pattern = nil

local function variant()
	return enums.Entities.Floraine_Temp_Piece
end

local function data_of(ent)
	if not ent then return nil end
	local d = ent:GetData()
	local row = d[defs.TEMP_DATA_KEY]
	if type(row) ~= "table" then
		row = {}
		d[defs.TEMP_DATA_KEY] = row
	end
	return row
end

function temp.is_temp(ent)
	if not ent or not ent:Exists() then return false end
	if ent.Type ~= EntityType.ENTITY_EFFECT then return false end
	local v = variant()
	if not v or v < 0 or ent.Variant ~= v then return false end
	return ent:GetData()[defs.TEMP_DATA_KEY] ~= nil
end

local function dist_point_to_segment(p, a, b)
	local abx = b.X - a.X
	local aby = b.Y - a.Y
	local len2 = abx * abx + aby * aby
	if len2 < 1 then
		local dx = p.X - a.X
		local dy = p.Y - a.Y
		return math.sqrt(dx * dx + dy * dy)
	end
	local t = ((p.X - a.X) * abx + (p.Y - a.Y) * aby) / len2
	if t < 0 then t = 0 elseif t > 1 then t = 1 end
	local cx = a.X + abx * t
	local cy = a.Y + aby * t
	local dx = p.X - cx
	local dy = p.Y - cy
	return math.sqrt(dx * dx + dy * dy)
end

local function try_hit(ent, data, prev, cur)
	if not data or not data.damage_active then return end
	local attack_id = data.attack_id or 0
	local piece_key = tostring(GetPtrHash(ent))
	local radius = data.hit_radius or 22
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player and player:Exists() and not player:IsDead() then
			local pindex = player:GetData().__Index
			if pindex == nil then
				pindex = "ci" .. tostring(player.ControllerIndex or i)
			end
			local key = piece_key .. ":" .. tostring(attack_id) .. ":" .. tostring(pindex)
			if not hit_once[key] then
				local dist = dist_point_to_segment(player.Position, prev, cur)
				if dist <= radius then
					hit_once[key] = true
					player:TakeDamage(data.contact_damage or 1, 0, EntityRef(ent), 20)
				end
			end
		end
	end
end

local function speed_for(kind)
	local name = piece_defs.name_of(kind)
	return defs.TEMP_SPEED[name] or 24
end

--- Spawn one temp piece along a planned path.
-- path = { start=Vector, dest=Vector, kind=number, delay=number, pattern=string }
function temp.spawn(path)
	local v = variant()
	if not v or v < 0 then
		return nil, "no_variant"
	end
	if not path or not path.start or not path.dest then
		return nil, "bad_path"
	end
	local kind = path.kind or piece_defs.KIND.VEHICLE
	local ent = Isaac.Spawn(EntityType.ENTITY_EFFECT, v, kind, path.start, Vector.Zero, nil)
	if not ent then
		return nil, "spawn_failed"
	end
	ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
	ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	if ent.CollisionDamage ~= nil then
		ent.CollisionDamage = 0
	end
	serial = serial + 1
	local data = data_of(ent)
	data.kind = kind
	data.phase = defs.TEMP_PHASE.SUMMON
	data.elapsed = -(tonumber(path.delay) or 0)
	data.start = Vector(path.start.X, path.start.Y)
	data.dest = Vector(path.dest.X, path.dest.Y)
	data.speed = path.speed or speed_for(kind)
	data.attack_id = serial
	data.damage_active = false
	data.contact_damage = 1
	data.hit_radius = path.hit_radius or 22
	data.pattern = path.pattern
	data.summon = defs.TEMP_TIMING.SUMMON
	data.prepare = defs.TEMP_TIMING.PREPARE
	data.fade = defs.TEMP_TIMING.FADE
	visual.apply_sheet(ent, kind)
	visual.set_phase_tint(ent, "SUMMON")
	active[GetPtrHash(ent)] = ent
	last_pattern = path.pattern
	return ent, "ok"
end

function temp.count()
	local n = 0
	for ptr, ent in pairs(active) do
		if ent and ent:Exists() and temp.is_temp(ent) then
			n = n + 1
		else
			active[ptr] = nil
		end
	end
	return n
end

function temp.any_active()
	return temp.count() > 0
end

function temp.any_damaging()
	for _, ent in pairs(active) do
		if ent and ent:Exists() then
			local d = data_of(ent)
			if d and d.damage_active then
				return true
			end
		end
	end
	return false
end

function temp.clear_all(reason)
	last_cleanup = reason or "clear_all"
	for ptr, ent in pairs(active) do
		if ent and ent:Exists() then
			ent:Remove()
		end
		active[ptr] = nil
	end
	hit_once = {}
end

function temp.on_update(effect)
	if not temp.is_temp(effect) then return end
	local data = data_of(effect)
	if not data then return end
	active[GetPtrHash(effect)] = effect
	data.elapsed = (data.elapsed or 0) + 1
	if data.elapsed < 0 then
		-- Stagger delay: hold at entry invisible-ish.
		visual.set_phase_tint(effect, "SUMMON")
		effect.Position = data.start
		effect.Velocity = Vector.Zero
		return
	end

	local prev = Vector(effect.Position.X, effect.Position.Y)

	if data.phase == defs.TEMP_PHASE.SUMMON then
		effect.Position = data.start
		effect.Velocity = Vector.Zero
		visual.set_phase_tint(effect, "SUMMON")
		if data.elapsed >= (data.summon or 10) then
			data.phase = defs.TEMP_PHASE.PREPARE
			data.elapsed = 0
		end
		return
	end

	if data.phase == defs.TEMP_PHASE.PREPARE then
		effect.Position = data.start
		effect.Velocity = Vector.Zero
		visual.set_phase_tint(effect, "PREPARE")
		data.damage_active = false
		if data.elapsed >= (data.prepare or 14) then
			data.phase = defs.TEMP_PHASE.DASH
			data.elapsed = 0
			data.damage_active = true
			visual.set_phase_tint(effect, "DASH")
		end
		return
	end

	if data.phase == defs.TEMP_PHASE.DASH then
		local dir = data.dest - data.start
		local len = dir:Length()
		if len < 1 then
			data.phase = defs.TEMP_PHASE.FADE
			data.elapsed = 0
			data.damage_active = false
			return
		end
		local step = dir:Normalized() * (data.speed or 24)
		local next_pos = effect.Position + step
		-- Past dest along path?
		local traveled = (effect.Position - data.start):Length()
		local remaining = (data.dest - effect.Position):Length()
		if remaining <= (data.speed or 24) * 0.6 or traveled >= len then
			next_pos = data.dest
			effect.Position = next_pos
			try_hit(effect, data, prev, next_pos)
			data.damage_active = false
			data.phase = defs.TEMP_PHASE.FADE
			data.elapsed = 0
			visual.set_phase_tint(effect, "FADE")
			return
		end
		effect.Position = next_pos
		effect.Velocity = Vector.Zero
		try_hit(effect, data, prev, next_pos)
		visual.record_trail(data, next_pos)
		visual.tick_trail(data)
		return
	end

	if data.phase == defs.TEMP_PHASE.FADE then
		effect.Velocity = Vector.Zero
		data.damage_active = false
		visual.set_phase_tint(effect, "FADE")
		visual.tick_trail(data)
		if data.elapsed >= (data.fade or 8) then
			active[GetPtrHash(effect)] = nil
			last_cleanup = "fade_complete"
			effect:Remove()
		end
		return
	end

	active[GetPtrHash(effect)] = nil
	effect:Remove()
end

function temp.on_render(effect)
	if not temp.is_temp(effect) then return end
	local data = data_of(effect)
	if data then
		visual.render_trail(effect, data)
	end
end

function temp.get_diag()
	local windows = 0
	for _, ent in pairs(active) do
		if ent and ent:Exists() then
			local d = data_of(ent)
			if d and d.damage_active then
				windows = windows + 1
			end
		end
	end
	return {
		temp_count = temp.count(),
		pattern_name = last_pattern,
		active_damage_windows = windows,
		cleanup_reason = last_cleanup,
	}
end

return temp
