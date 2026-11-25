-- P2「棋落」: staff sink → red board cells → matte fall → persist as column strays.
-- Red cells use stone_board overlay (same path as royal_drop). Fall fx adopts into demote_at.

local defs = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.defs")
local arena = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.arena")
local visual = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.visual")
local piece_defs = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_defs")
local piece_matte = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.piece_matte_fx")
local columns = require("Qing_Remaster_scripts.bosses.Floraine.floraine_v2.p2_columns")
local occupancy = require("Qing_Remaster_scripts.bosses.Floraine.chess_piece_occupancy")

local drop = {}

local PHASE = {
	IDLE = "IDLE",
	SINK = "SINK",
	WARN = "WARN",
	WAIT_CLEAR = "WAIT_CLEAR", -- warn held until column march ends
	FALL = "FALL",
	IMPACT = "IMPACT",
	SETTLE = "SETTLE",
}

local state = {
	active = false,
	phase = PHASE.IDLE,
	elapsed = 0,
	marks = {}, -- { gidx, pos, fx, height, start, landed }
	session = 0,
	last_fail = nil,
}

local function cfg()
	return defs.P2_CHESS_DROP or {}
end

local function owner()
	return cfg().OWNER or "floraine_p2_chess_drop"
end

local function blocker_id(gidx)
	return owner() .. "_" .. tostring(gidx)
end

local function rng_for(serial)
	local r = RNG()
	local seed = Game():GetRoom():GetSpawnSeed()
	r:SetSeed((seed + (serial or 0) * 97 + state.session * 13) % 2147483646 + 1, 35)
	return r
end

local function player_pos()
	local p = Game():GetPlayer(0)
	if p and p:Exists() and not p:IsDead() then
		return p.Position
	end
	return Game():GetRoom():GetCenterPos()
end

local function clear_marks(remove_fx)
	for i = 1, #state.marks do
		local m = state.marks[i]
		if m.gidx then
			occupancy.clear_blocker(blocker_id(m.gidx))
		end
		if remove_fx and m.fx then
			piece_matte.remove(m.fx)
			m.fx = nil
		end
	end
	state.marks = {}
end

local function desired_count()
	local c = cfg()
	local n = columns.count_matte and columns.count_matte() or 0
	local soft = c.MATTE_SOFT_CAP or 24
	if n >= soft then
		return 0
	elseif n >= 18 then
		return c.MIN_CELLS or 3
	elseif n >= 12 then
		return 4
	end
	return c.MAX_CELLS or 5
end

--- Pick walkable empty cells: some near player, rest scattered. Locked at warn time.
local function pick_cells(count)
	count = math.max(0, math.floor(tonumber(count) or 0))
	if count < 1 then
		return {}
	end
	local room = Game():GetRoom()
	local width = room:GetGridWidth()
	local height = room:GetGridHeight()
	local toward = player_pos()
	local taken = {}
	-- Avoid current matte / locked cells via nearest occupancy from columns demote keys.
	-- Sample walkable cells.
	local pool = {}
	for y = 0, height - 1 do
		for x = 0, width - 1 do
			local idx = y * width + x
			if room:GetGridCollision(idx) == GridCollisionClass.COLLISION_NONE
				and not occupancy.get_blocker(idx) then
				local p = room:GetGridPosition(idx)
				pool[#pool + 1] = { gidx = idx, pos = Vector(p.X, p.Y) }
			end
		end
	end
	if #pool < 1 then
		return {}
	end
	table.sort(pool, function(a, b)
		return (a.pos - toward):LengthSquared() < (b.pos - toward):LengthSquared()
	end)
	local r = rng_for(Game():GetFrameCount())
	local near_n = math.min(count, math.max(1, math.ceil(count * 0.5)))
	local picks = {}
	local function try_add(entry)
		if not entry or taken[entry.gidx] then
			return false
		end
		-- Soft reject if already blocked by column occupancy (demote would fail exact).
		taken[entry.gidx] = true
		picks[#picks + 1] = { gidx = entry.gidx, pos = Vector(entry.pos.X, entry.pos.Y) }
		return true
	end
	-- Near cluster.
	for i = 1, #pool do
		if #picks >= near_n then
			break
		end
		try_add(pool[i])
	end
	-- Scatter: pick from farther pool with RNG, skip adjacent-heavy closures crudely.
	local far = {}
	for i = near_n + 1, #pool do
		far[#far + 1] = pool[i]
	end
	while #picks < count and #far > 0 do
		local i = r:RandomInt(#far) + 1
		local entry = far[i]
		table.remove(far, i)
		try_add(entry)
	end
	return picks
end

local function reserve_mark(m)
	if m and m.gidx and m.pos then
		occupancy.set_blocker(owner(), blocker_id(m.gidx), m.pos)
	end
end

function drop.is_busy()
	return state.active == true and state.phase ~= PHASE.IDLE
end

function drop.clear(reason)
	clear_marks(true)
	state.active = false
	state.phase = PHASE.IDLE
	state.elapsed = 0
	state.last_fail = reason
	return true
end

--- Stop attack and hand any mid-air fall Effects to evacuate (ownership transfer).
function drop.take_evac_entities()
	local items = {}
	for i = 1, #state.marks do
		local m = state.marks[i]
		if m.gidx then
			occupancy.clear_blocker(blocker_id(m.gidx))
		end
		local fx = m.fx
		m.fx = nil
		if fx and fx.Exists and fx:Exists() then
			-- Prefer live Effect pose so mid-fall handoff does not snap to cell center.
			items[#items + 1] = {
				kind = "matte",
				ent = fx,
				start = Vector(fx.Position.X, fx.Position.Y),
				height0 = -(fx.PositionOffset and fx.PositionOffset.Y or 0),
				tilt = 0,
				elapsed = 0,
				alpha = 1,
			}
		end
	end
	state.marks = {}
	state.active = false
	state.phase = PHASE.IDLE
	state.elapsed = 0
	state.last_fail = "evac"
	return items
end

function drop.get_board_cell_overlay(index)
	if not drop.is_busy() then
		return nil
	end
	if state.phase ~= PHASE.WARN
		and state.phase ~= PHASE.WAIT_CLEAR
		and state.phase ~= PHASE.FALL
		and state.phase ~= PHASE.IMPACT then
		return nil
	end
	local c = cfg()
	local a = c.WARN_ALPHA or 0.42
	if state.phase == PHASE.FALL then
		a = a + 0.12
	elseif state.phase == PHASE.IMPACT then
		a = math.min(1, a + 0.25)
	end
	for i = 1, #state.marks do
		if state.marks[i].gidx == index then
			return {
				fill = c.FILL or { 1, 0.22, 0.28 },
				border = c.BORDER or { 1, 0.48, 0.5 },
				fill_alpha = a,
				border_alpha = math.min(1, a + 0.35),
				border_thickness = 2,
			}
		end
	end
	return nil
end

function drop.try_begin(boss_ent)
	if drop.is_busy() then
		return false, "busy"
	end
	if not columns.is_active or not columns.is_active() then
		return false, "no_columns"
	end
	if not columns.is_combat_ready or not columns.is_combat_ready() then
		return false, "not_ready"
	end
	local n = desired_count()
	if n < 1 then
		state.last_fail = "at_matte_cap"
		return false, state.last_fail
	end
	local cells = pick_cells(n)
	if #cells < (cfg().MIN_CELLS or 3) then
		-- Allow fewer if board is cramped.
		if #cells < 1 then
			state.last_fail = "no_cells"
			return false, state.last_fail
		end
	end
	state.session = state.session + 1
	state.active = true
	state.phase = PHASE.SINK
	state.elapsed = 0
	state.marks = {}
	for i = 1, #cells do
		local m = {
			gidx = cells[i].gidx,
			pos = cells[i].pos,
			fx = nil,
			height = 0,
			start = nil,
			landed = false,
		}
		reserve_mark(m)
		state.marks[#state.marks + 1] = m
	end
	if boss_ent and visual.release then
		visual.release(boss_ent)
	elseif boss_ent and visual.lower then
		visual.lower(boss_ent)
	end
	state.last_fail = "started"
	return true
end

local function spawn_fall_fx(m)
	if m.fx and m.fx.Exists and m.fx:Exists() then
		return m.fx
	end
	local start = arena.world_offscreen_above(m.pos.X, 48, 8)
	m.start = start
	-- Height = world distance above ground so PositionOffset lifts into screen-out.
	m.height = math.max(80, (m.pos.Y - start.Y))
	local ent = piece_matte.spawn(piece_defs.KIND.PAWN, m.pos, {
		owner = owner(),
		piece_id = "chess_drop_" .. tostring(m.gidx),
		color_progress = 0,
		outline_alpha = 0,
		visual_height = m.height,
	})
	m.fx = ent
	return ent
end

local function apply_impact_damage(boss_ent)
	local c = cfg()
	local radius = c.IMPACT_RADIUS or 22
	local dmg = c.IMPACT_DAMAGE or 2
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if p and p:Exists() and not p:IsDead() then
			for j = 1, #state.marks do
				local m = state.marks[j]
				if m.pos and (p.Position - m.pos):Length() <= radius then
					p:TakeDamage(dmg, 0, EntityRef(boss_ent), 20)
					break
				end
			end
		end
	end
end

local function commit_strays()
	for i = 1, #state.marks do
		local m = state.marks[i]
		if m.gidx then
			occupancy.clear_blocker(blocker_id(m.gidx))
		end
		local stray, why = columns.demote_at(m.pos, {
			gidx = m.gidx,
			exact = true,
			adopt_fx = m.fx,
			visual_height = 0,
		})
		if not stray then
			-- Exact cell failed: drop fx rather than leave a ghost mid-air.
			if m.fx then
				piece_matte.remove(m.fx)
				m.fx = nil
			end
			state.last_fail = why or "demote_failed"
		else
			m.fx = nil -- ownership transferred
			m.landed = true
		end
	end
	state.marks = {}
end

--- Returns true when the attack finished this frame.
function drop.tick(boss_ent)
	if not state.active then
		return false
	end
	state.elapsed = (state.elapsed or 0) + 1
	local c = cfg()

	if state.phase == PHASE.SINK then
		if state.elapsed >= (c.SINK or 10) then
			state.phase = PHASE.WARN
			state.elapsed = 0
		end
		return false
	end

	if state.phase == PHASE.WARN then
		if state.elapsed >= (c.WARN or 22) then
			if columns.is_motion_busy and columns.is_motion_busy() then
				state.phase = PHASE.WAIT_CLEAR
				state.elapsed = 0
			else
				state.phase = PHASE.FALL
				state.elapsed = 0
				for i = 1, #state.marks do
					spawn_fall_fx(state.marks[i])
				end
			end
		end
		return false
	end

	if state.phase == PHASE.WAIT_CLEAR then
		if not (columns.is_motion_busy and columns.is_motion_busy()) then
			state.phase = PHASE.FALL
			state.elapsed = 0
			for i = 1, #state.marks do
				spawn_fall_fx(state.marks[i])
			end
		end
		return false
	end

	if state.phase == PHASE.FALL then
		local dur = math.max(1, c.FALL or 10)
		local t = math.min(1, state.elapsed / dur)
		local ease = t * t
		for i = 1, #state.marks do
			local m = state.marks[i]
			local h0 = m.height or 120
			m.height = h0 * (1 - ease)
			if m.fx and m.fx.Exists and m.fx:Exists() then
				piece_matte.sync(m.fx, {
					ground_pos = m.pos,
					visual_height = m.height,
					color_progress = 0,
					outline_alpha = 0,
				})
			end
		end
		if state.elapsed >= dur then
			state.phase = PHASE.IMPACT
			state.elapsed = 0
			for i = 1, #state.marks do
				local m = state.marks[i]
				m.height = 0
				if m.fx then
					piece_matte.sync(m.fx, {
						ground_pos = m.pos,
						visual_height = 0,
						color_progress = 0,
						outline_alpha = 0,
					})
				end
			end
			apply_impact_damage(boss_ent)
		end
		return false
	end

	if state.phase == PHASE.IMPACT then
		if state.elapsed >= (c.IMPACT or 4) then
			commit_strays()
			state.phase = PHASE.SETTLE
			state.elapsed = 0
		end
		return false
	end

	if state.phase == PHASE.SETTLE then
		if state.elapsed >= (c.SETTLE or 8) then
			state.active = false
			state.phase = PHASE.IDLE
			state.elapsed = 0
			if boss_ent and visual.idle2 then
				visual.idle2(boss_ent)
			end
			return true
		end
		return false
	end

	return false
end

function drop.diag()
	return {
		active = state.active,
		phase = state.phase,
		elapsed = state.elapsed,
		marks = #state.marks,
		last_fail = state.last_fail,
		session = state.session,
	}
end

drop.PHASE = PHASE

return drop
