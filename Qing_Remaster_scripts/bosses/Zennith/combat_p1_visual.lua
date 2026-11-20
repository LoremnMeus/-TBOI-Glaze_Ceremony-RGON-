-- Zennith P1 wind-wall visuals (V1.6).
-- Continuous flowing streaks only — no Front/Tail vertical light columns.
-- Spatial alpha by world X; staggered birth/death along X so no shared cutoff line.
-- Render-only; gaps / damage owned by combat_p1.

local M = {
	ANM2 = "gfx/boss/Zennith/zennith_wind_wall.anm2",
	SEG_W = 48,
	SEG_H = 28,
	SEG_WORLD = 11,
	-- Front/Tail columns disabled by default (V1.6). Toggles remain for isolation tests.
	layers = {front = false, tail = false, seg = true, mist = true},
}

function M.set_layer(name, on)
	if M.layers[name] == nil then return false end
	M.layers[name] = on == true
	return true
end

function M.get_layers()
	return {
		front = M.layers.front == true,
		tail = M.layers.tail == true,
		seg = M.layers.seg == true,
		mist = M.layers.mist == true,
	}
end

local spr = {seg = nil}

local function load_one(anim)
	local s = Sprite()
	s:Load(M.ANM2, true)
	s:Play(anim, true)
	return s
end

local function ensure_sprites()
	if spr.seg then return true end
	local ok, s = pcall(load_one, "Seg")
	if ok and s then spr.seg = s end
	return spr.seg ~= nil
end

local function clamp01(x)
	if x < 0 then return 0 end
	if x > 1 then return 1 end
	return x
end

local function smoothstep(e0, e1, x)
	if e1 <= e0 then
		if x < e0 then return 0 end
		return 1
	end
	local t = (x - e0) / (e1 - e0)
	t = clamp01(t)
	return t * t * (3 - 2 * t)
end

local function world_to_screen(pos)
	local room = Game():GetRoom()
	if room and room.WorldToScreenPosition then
		return room:WorldToScreenPosition(pos)
	end
	return Isaac.WorldToScreen(pos)
end

local function draw(anim_spr, anim, mid, rot, scale_x, scale_y, color)
	if not anim_spr or not mid then return end
	pcall(function()
		anim_spr:Play(anim, true)
		anim_spr:SetFrame(anim, 0)
		anim_spr.Rotation = rot or 0
		anim_spr.Scale = Vector(scale_x or 1, scale_y or 1)
		anim_spr.Color = color or Color(1, 1, 1, 0.4)
		anim_spr:Render(world_to_screen(mid), Vector(0, 0), Vector(0, 0))
	end)
end

--- Spatial wall opacity at world X. along grows from trailing toward leading.
function M.wall_alpha_at_x(x, wall)
	if not wall then return 0 end
	local dir = wall.travel_dir or wall.dir or 1
	local trailing = wall.trailing
	local leading = wall.leading
	if not trailing or not leading then return 0 end
	local along = (x - trailing) * dir
	local trail = wall.trail_len or math.max(28, (wall.thickness or 100) * 0.34)
	local thick = math.abs(leading - trailing)
	if along <= 0 then
		return 0
	end
	if along < trail then
		return smoothstep(0, trail, along)
	end
	if along <= thick then
		-- Slight brightness rise toward the leading half (density, not a tip sprite).
		local u = (along - trail) / math.max(1, thick - trail)
		return 0.82 + 0.18 * smoothstep(0.35, 1.0, u)
	end
	-- Soft exit past leading — streaks do not share one hard X kill line.
	return clamp01(1 - smoothstep(0, 48, along - thick))
end

local function in_gap_y(wall, y)
	local gaps = wall.gaps or {}
	for i = 1, #gaps do
		local g = gaps[i]
		if y >= g.y0 and y <= g.y1 then return true, 0 end
		local curl = 14
		if y >= g.y0 - curl and y < g.y0 then
			return false, (g.y0 - y) / curl
		end
		if y > g.y1 and y <= g.y1 + curl then
			return false, (y - g.y1) / curl
		end
	end
	return false, 1
end

local function ribbon_max_alpha(wall, center_x, length, dir)
	local half = length * 0.5
	local best = 0
	local n = math.max(2, math.floor(length / M.SEG_WORLD + 0.5))
	for i = 0, n - 1 do
		local ox = -half + (i + 0.5) * (length / n)
		local x = center_x + dir * ox
		local a = M.wall_alpha_at_x(x, wall)
		if a > best then best = a end
	end
	return best
end

-- Active wind-cut streaks for wind_split (pure visual records from combat_p1_split).
local cut_list = {}

function M.clear()
	cut_list = {}
end

function M.set_cuts(list)
	cut_list = list or {}
end

function M.render_cuts(list)
	list = list or cut_list
	if not list or #list == 0 then return end
	if not ensure_sprites() then return end
	local sx = (M.SEG_WORLD * 1.35) / M.SEG_W
	local sy = 0.42
	for i = 1, #list do
		local cut = list[i]
		if cut and cut.target and cut.dir then
			local dur = math.max(1, cut.duration or 5)
			local age = cut.age or 0
			local u = math.min(1, age / dur)
			local approach = cut.approach or 72
			local exit = cut.exit or 80
			local mid = cut.target - cut.dir * approach + cut.dir * ((approach + exit) * u)
			local blade = cut.blade_len or 38
			local rot = cut.ang or cut.dir:GetAngleDegrees()
			local life = dur + (cut.trail_life or 4)
			-- Bright tip while body flies; after duration only trails remain.
			local body_a = 0
			if age <= dur then
				body_a = cut.hit and 0.95 or (0.55 + 0.45 * clamp01(u * 1.4))
				if age >= dur - 0.5 then
					body_a = body_a * 0.75
				end
			end
			body_a = clamp01(body_a)
			-- Short leading blade (clear motion front), not a 120u ribbon.
			if body_a > 0.04 then
				local n = math.max(3, math.floor(blade / (M.SEG_WORLD * 0.55) + 0.5))
				local half = blade * 0.5
				local step = blade / n
				for k = 0, n - 1 do
					local ox = -half + (k + 0.5) * step
					-- Brighter toward the tip (leading edge).
					local tip_w = 0.35 + 0.65 * clamp01((ox + half) / math.max(1, blade))
					local pa = body_a * tip_w
					if pa > 0.04 then
						local pos = mid + cut.dir * ox
						local glow = cut.hit and 0.35 or 0.18
						draw(
							spr.seg, "Seg", pos, rot,
							sx * (0.85 + 0.35 * tip_w), sy,
							Color(0.92, 0.98, 1.0, pa, glow, glow * 1.2, glow * 1.6)
						)
					end
				end
			end
			-- Afterimage samples behind the tip.
			local trail = cut.trail or {}
			local trail_fade = clamp01(1 - (age - dur) / math.max(1, cut.trail_life or 4))
			if age <= life then
				for t = 1, #trail do
					local sample = trail[t]
					local ta = (sample.a or 1) * 0.28 * trail_fade * (t / #trail)
					if age <= dur then
						ta = (sample.a or 1) * 0.22 * (t / #trail)
					end
					if ta > 0.03 then
						draw(
							spr.seg, "Seg", Vector(sample.x, sample.y), rot,
							sx * 0.7, sy * 0.85,
							Color(0.75, 0.9, 1.0, ta, 0.04, 0.1, 0.2)
						)
					end
				end
			end
		end
	end
end

local function can_recycle(wall)
	-- DISSOLVE: stop feeding new streaks; existing ones fly out and fade.
	if wall.phase == "dissolve" or wall.phase == "rest" or wall.phase == "idle" then
		return false
	end
	return wall.spawn_enabled ~= false
end

function M.update_wall(wall, dt)
	if not wall then return end
	dt = dt or 1
	local dir = wall.travel_dir or wall.dir or 1
	local thick = math.max(12, wall.thickness or 110)
	local flow = (wall.flow_speed or 10) * dt / thick

	local function tick_list(list)
		if not list then return end
		for i = 1, #list do
			local s = list[i]
			if s.dead then
				-- keep dead
			elseif (s.delay or 0) > 0 then
				if can_recycle(wall) then
					s.delay = s.delay - dt
				end
			else
				s.along_u = (s.along_u or -0.1) + flow * (s.speed or 1)
				-- Slight vertical drift so rows don't form a lattice.
				s.y = (s.y or 0) + (s.vy or 0) * dt
				local center = wall.trailing + dir * (s.along_u or 0) * thick
				local len = s.length or 64
				local visible = ribbon_max_alpha(wall, center, len, dir)
				if (s.along_u or 0) > 1.08 and visible <= 0.03 then
					if can_recycle(wall) then
						s.along_u = -0.18 - (s.seed or 0.3) * 0.2
						s.delay = 1 + (s.seed or 0.3) * 10
						s.y = s.y0 or s.y
					else
						s.dead = true
					end
				elseif (s.along_u or 0) > 1.65 then
					if can_recycle(wall) then
						s.along_u = -0.12
						s.delay = 3
					else
						s.dead = true
					end
				end
			end
		end
	end

	tick_list(wall.streaks)
	tick_list(wall.mist)
end

local function draw_ribbon_segments(wall, center_x, y, length, dir, rot, base_a, bend, tint)
	if base_a <= 0.02 then return end
	local n = math.max(3, math.floor(length / M.SEG_WORLD + 0.5))
	local step = length / n
	local half = length * 0.5
	local sx = (M.SEG_WORLD * 1.08) / M.SEG_W
	local sy = 0.62 + (tint and tint.sy or 0)
	for i = 0, n - 1 do
		local ox = -half + (i + 0.5) * step
		local x = center_x + dir * ox
		local sa = M.wall_alpha_at_x(x, wall)
		local a = base_a * sa
		if a > 0.022 then
			local b = (bend or 0) * (ox / math.max(1, half))
			local r = (tint and tint.r) or 0.88
			local g = (tint and tint.g) or 0.96
			local bl = (tint and tint.b) or 1.0
			local ro = (tint and tint.ro) or 0.05
			local go = (tint and tint.go) or 0.12
			local bo = (tint and tint.bo) or 0.24
			draw(
				spr.seg, "Seg", Vector(x, y), rot + b,
				sx, sy,
				Color(r, g, bl, a, ro, go, bo)
			)
		end
	end
end

function M.render_wall(wall)
	if not wall or not wall.visible then return end
	if not ensure_sprites() then return end
	local alpha = wall.alpha or 0
	if alpha <= 0.02 then return end
	local dir = wall.travel_dir or wall.dir or 1
	local rot = (dir > 0) and 0 or 180
	local leading = wall.leading
	local trailing = wall.trailing
	if not leading or not trailing then return end
	local thickness = math.max(8, math.abs(leading - trailing))
	local density = clamp01(wall.density or 1)
	local front_boost = wall.front_glow or 0

	local show_seg = M.layers.seg ~= false
	local show_mist = M.layers.mist ~= false
	-- Front/Tail column draws intentionally omitted in V1.6 even if toggled on
	-- (toggles kept for future isolation; columns were the hard vertical artifact).

	-- Soft mist: sparse short washes at staggered along_u (never one shared X column).
	if show_mist then
		local mist = wall.mist or wall.soft_slots or {}
		local n_mist = math.floor(#mist * (0.4 + 0.6 * density) + 0.5)
		for i = 1, math.min(n_mist, #mist) do
			local m = mist[i]
			if m and not m.in_gap and not m.dead and (m.delay or 0) <= 0 then
				local along_u = m.along_u
				if not along_u then
					along_u = 0.08 + 0.84 * ((m.phase or 0) % 1)
				end
				local cx = trailing + dir * along_u * thickness
				local sa = M.wall_alpha_at_x(cx, wall)
				local a = alpha * 0.11 * density * (m.curl or 1) * sa
				if a > 0.02 and spr.seg then
					draw(
						spr.seg, "Seg", Vector(cx, m.y), rot,
						1.35, 1.4,
						Color(0.65, 0.85, 1.0, a, 0.02, 0.06, 0.14)
					)
				end
			end
		end
	end

	-- Continuous flow ribbons.
	if show_seg then
		local streaks = wall.streaks or {}
		local n_draw = #streaks
		for i = 1, n_draw do
			local s = streaks[i]
			if s and not s.in_gap and not s.dead and (s.delay or 0) <= 0 then
				local along_u = s.along_u or 0
				local cx = trailing + dir * along_u * thickness
				local len = s.length or 70
				-- Density by role / position: brighter near leading without a tip column.
				local role_a = 0.30
				if s.role == "front" then
					role_a = 0.42 + 0.2 * front_boost
				elseif s.role == "tail" then
					role_a = 0.22
				elseif s.role == "bright" then
					role_a = 0.38 + 0.12 * front_boost
				end
				local base = alpha * role_a * (0.5 + 0.5 * density) * (s.curl or 1)
				local tint = nil
				if s.role == "front" or s.role == "bright" then
					tint = {r = 0.95, g = 0.98, b = 1, ro = 0.1, go = 0.18, bo = 0.32, sy = 0.08}
				elseif s.role == "tail" then
					tint = {r = 0.7, g = 0.88, b = 1, ro = 0.03, go = 0.08, bo = 0.18, sy = -0.05}
				end
				draw_ribbon_segments(wall, cx, s.y, len, dir, rot, base, s.bend or 0, tint)
			end
		end
	end
end

return M
