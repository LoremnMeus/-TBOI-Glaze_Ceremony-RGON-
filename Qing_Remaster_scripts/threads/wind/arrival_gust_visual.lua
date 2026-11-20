-- Arrival-only sky gusts. Screen-space trails for the Zennith descent.
-- Does not open a wind session, change airflow budgets, or reset wind_visual.

local M = {
	ANM2 = "gfx/boss/Zennith/storm/storm_v63.anm2",
	CAP = {primary = 42, secondary = 28, debris = 16},
	RAMP_FRAMES = 20,
}

local active = false
local spawning = false
local age = 0
local seed = 1
local focus_x, focus_y = nil, nil
local lines = {}
local sprite = nil

local function rnd()
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

local function screen_size()
	local w = Isaac.GetScreenWidth()
	local h = Isaac.GetScreenHeight()
	if not w or w < 8 then w = 480 end
	if not h or h < 8 then h = 270 end
	return w, h
end

local function player_screen()
	local player = Game():GetPlayer(0)
	local room = Game():GetRoom()
	local w, h = screen_size()
	if not player or not room then
		return w * 0.5, h * 0.55
	end
	local pos = player.Position + (player.PositionOffset or Vector(0, 0))
	local screen = room:WorldToScreenPosition(pos)
	return screen.X, screen.Y
end

local function ensure_sprite()
	if sprite then return sprite end
	local s = Sprite()
	local ok = pcall(function()
		s:Load(M.ANM2, true)
		s:Play("Body1", true)
	end)
	if not ok then return nil end
	sprite = s
	return sprite
end

function M.clear()
	active = false
	spawning = false
	age = 0
	focus_x, focus_y = nil, nil
	lines = {}
end

function M.is_active()
	return active == true
end

function M.alive_count()
	return #lines
end

function M.begin()
	M.clear()
	active = true
	spawning = true
	seed = 20261115
	ensure_sprite()
	local x, y = player_screen()
	focus_x, focus_y = x, y
	return true
end

function M.wind_down()
	spawning = false
end

local function count_kind(kind)
	local n = 0
	for i = 1, #lines do
		if lines[i].kind == kind then n = n + 1 end
	end
	return n
end

local function spawn_one(kind)
	local w, h = screen_size()
	local px, py = player_screen()
	if not focus_x then
		focus_x, focus_y = px, py
	else
		focus_x = focus_x + (px - focus_x) * 0.06
		focus_y = focus_y + (py - focus_y) * 0.06
	end
	local x0 = -40 + rnd() * (w + 80)
	local y0 = -20 - rnd() * 70
	local drift = (rnd() * 2 - 1) * (kind == "primary" and 28 or 14)
	local side = (x0 + drift) < focus_x and -1 or 1
	if math.abs((x0 + drift) - focus_x) < 12 then
		side = (rnd() < 0.5) and -1 or 1
	end
	local spread = 20 + rnd() * 35
	local ax = focus_x + side * spread * (0.45 + rnd() * 0.55)
	local ay = focus_y - 6 + rnd() * 22
	local deg = side * (8 + rnd() * 42)
	if rnd() < 0.1 then
		deg = side * (50 + rnd() * 18)
	end
	if deg > 68 then deg = 68 end
	if deg < -68 then deg = -68 end
	local exit_len = 100 + rnd() * 50
	if kind == "debris" then exit_len = exit_len * 0.7 end
	local ex = math.sin(math.rad(deg)) * exit_len
	local ey = math.cos(math.rad(deg)) * exit_len
	local elen = math.sqrt(ex * ex + ey * ey)
	if elen < 1 then elen = 1 end
	local ux, uy = ex / elen, ey / elen
	local lead = 34 + rnd() * 16
	local cx = ax - ux * lead
	local cy = ay - uy * lead
	local fx = x0 + drift
	local fy = cy - (24 + rnd() * 18)
	local fall = fy - y0
	if fall < 20 then
		y0 = fy - 20
		fall = 20
	end
	local life = 34
	local thick, alpha, samples = 0.9, 0.78, 7
	if kind == "secondary" then
		life = 28
		thick, alpha, samples = 0.58, 0.55, 5
	elseif kind == "debris" then
		life = 20
		thick, alpha, samples = 0.4, 0.42, 3
	end
	life = life + math.floor(rnd() * 8)
	lines[#lines + 1] = {
		kind = kind,
		age = 0,
		life = life,
		x0 = x0,
		y0 = y0,
		drift = drift,
		fall = fall,
		fx = fx,
		fy = fy,
		cx = cx,
		cy = cy,
		ax = ax,
		ay = ay,
		ex = ex,
		ey = ey,
		ux = ux,
		uy = uy,
		thick = thick * (0.85 + rnd() * 0.3),
		alpha = alpha,
		samples = samples,
		body = (rnd() < 0.5) and "Body1" or "Body2",
		tip = "Tip1",
		tail = "Tail1",
	}
end

local function sample(g, u)
	if u < 0 then u = 0 end
	if u > 1 then u = 1 end
	if u <= 0.34 then
		local t = u / 0.34
		return g.x0 + (g.fx - g.x0) * t, g.y0 + (g.fy - g.y0) * t
	elseif u <= 0.68 then
		local t = (u - 0.34) / 0.34
		local o = 1 - t
		return o * o * g.fx + 2 * o * t * g.cx + t * t * g.ax,
			o * o * g.fy + 2 * o * t * g.cy + t * t * g.ay
	end
	local t = (u - 0.68) / 0.32
	local o = 1 - t
	local mx = g.ax + g.ux * 28
	local my = g.ay + g.uy * 28
	local dx = g.ax + g.ex
	local dy = g.ay + g.ey
	return o * o * g.ax + 2 * o * t * mx + t * t * dx,
		o * o * g.ay + 2 * o * t * my + t * t * dy
end

function M.update()
	if not active then return end
	age = age + 1
	local ramp = math.min(1, age / M.RAMP_FRAMES)
	if spawning then
		local order = {"primary", "secondary", "debris"}
		local made = 0
		for i = 1, #order do
			local kind = order[i]
			local want = math.floor(M.CAP[kind] * ramp + 0.5)
			while count_kind(kind) < want and made < 6 do
				spawn_one(kind)
				made = made + 1
			end
		end
	end
	local keep = {}
	local w, h = screen_size()
	for i = 1, #lines do
		local g = lines[i]
		g.age = g.age + 1
		local u = g.age / math.max(1, g.life)
		local x, y = sample(g, u)
		local outside = x < -80 or y < -80 or x > w + 80 or y > h + 80
		if u < 1 and not (u > 0.72 and outside) then
			keep[#keep + 1] = g
		end
	end
	lines = keep
	if not spawning and #lines == 0 then
		active = false
	end
end

local function draw_seg(anim, ax, ay, bx, by, thick, alpha)
	local spr = ensure_sprite()
	if not spr then return end
	local dx, dy = bx - ax, by - ay
	local dist = math.sqrt(dx * dx + dy * dy)
	if dist < 2 then return end
	pcall(function()
		spr:Play(anim, true)
		spr:SetFrame(anim, 0)
		spr.Rotation = Vector(dx, dy):GetAngleDegrees()
		spr.Scale = Vector(math.min(1.35, dist / 16), thick)
		spr.Color = Color(1, 1, 1, alpha)
		spr:Render(Vector((ax + bx) * 0.5, (ay + by) * 0.5), Vector(0, 0), Vector(0, 0))
	end)
end

function M.render()
	if not active then return end
	for i = 1, #lines do
		local g = lines[i]
		local u = g.age / math.max(1, g.life)
		local fade = 1
		if u > 0.82 then fade = math.max(0, 1 - (u - 0.82) / 0.18) end
		local n = g.samples or 5
		local span = (g.kind == "debris") and 0.1 or 0.16
		local prev_x, prev_y = nil, nil
		for s = 0, n - 1 do
			local su = u - span * (n - 1 - s) / math.max(1, n - 1)
			if su < 0 then su = 0 end
			local x, y = sample(g, su)
			if prev_x then
				local along = s / math.max(1, n - 1)
				local anim = g.body
				if s == 1 then anim = g.tail end
				if s == n - 1 then anim = g.tip end
				draw_seg(anim, prev_x, prev_y, x, y, g.thick, g.alpha * fade * (0.45 + 0.55 * along))
			end
			prev_x, prev_y = x, y
		end
	end
end

return M
