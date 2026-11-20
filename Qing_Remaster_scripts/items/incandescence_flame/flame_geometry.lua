-- V2 envelope helpers kept for comparison.
-- The live column is flame_stream + flame_regions. This file is not the V3 shape.

local geom = {}

function geom.clamp01(u)
	if u < 0 then return 0 end
	if u > 1 then return 1 end
	return u
end

function geom.smooth(u)
	u = geom.clamp01(u)
	return u * u * (3 - 2 * u)
end

function geom.width(u, mouth, half)
	return mouth + (half - mouth) * geom.smooth(u)
end

function geom.hash01(ix, iy, seed)
	local n = (ix * 73856093 + iy * 19349663 + seed * 83492791) % 2147483647
	if n < 0 then n = -n end
	n = (n * n) % 2147483647
	return (n % 10000) / 10000
end

function geom.noise(x, y, seed)
	local x0 = math.floor(x)
	local y0 = math.floor(y)
	local tx = x - x0
	local ty = y - y0
	local function h(ix, iy)
		return geom.hash01(ix, iy, seed)
	end
	local a = h(x0, y0)
	local b = h(x0 + 1, y0)
	local c = h(x0, y0 + 1)
	local d = h(x0 + 1, y0 + 1)
	local u = tx * tx * (3 - 2 * tx)
	local v = ty * ty * (3 - 2 * ty)
	return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v
end

function geom.curl(x, y, seed)
	local e = 0.35
	local dx = geom.noise(x + e, y, seed) - geom.noise(x - e, y, seed)
	local dy = geom.noise(x, y + e, seed) - geom.noise(x, y - e, seed)
	return dy, -dx
end

function geom.normal(dir)
	local len = math.sqrt(dir.x * dir.x + dir.y * dir.y)
	if len < 0.0001 then
		return 0, -1, 1, 0
	end
	local dx = dir.x / len
	local dy = dir.y / len
	return dx, dy, -dy, dx
end

function geom.u_of(s, length)
	if not length or length <= 0 then
		return 0
	end
	return geom.clamp01(s / length)
end

-- Outer half-width at actual distance s. Waves travel forward with time.
function geom.envelope_half(s, cfg, time)
	local u = geom.u_of(s, cfg.length)
	local base = geom.width(u, cfg.mouth_width, cfg.half_width)
	local curl = cfg.curl or 0
	local travel = s * 0.045 - time * 0.38
	local wave = math.sin(travel) * 0.62 + math.sin(travel * 0.51 + 1.4) * 0.38
	local amp = (0.05 + 0.2 * u) * curl
	local half = base * (1 + amp * wave)
	local floor_w = (cfg.mouth_width or 14) * 0.5
	if half < floor_w then
		half = floor_w
	end
	return half
end

-- Inner gold band, 35%–55% of the local outer half-width.
function geom.core_half(s, cfg, time)
	local outer = geom.envelope_half(s, cfg, time)
	local u = geom.u_of(s, cfg.length)
	local frac = cfg.core_frac or 0.45
	if frac < 0.35 then frac = 0.35 end
	if frac > 0.55 then frac = 0.55 end
	local shaped = frac * (1.08 - 0.18 * u)
	if shaped < 0.35 then shaped = 0.35 end
	if shaped > 0.55 then shaped = 0.55 end
	local pulse = 0.92 + 0.08 * math.sin(s * 0.07 - time * 0.28)
	return outer * shaped * pulse
end

function geom.centerline(origin, dir, s, time, curl)
	local dx, dy, nx, ny = geom.normal(dir)
	local bend = math.sin(s * 0.02 + time * 0.15) * (2 + s * 0.012) * (curl or 0)
	return {
		x = origin.x + dx * s + nx * bend,
		y = origin.y + dy * s + ny * bend,
		dx = dx,
		dy = dy,
		nx = nx,
		ny = ny,
	}
end

function geom.point_at(origin, dir, s, lateral, time, curl)
	local c = geom.centerline(origin, dir, s, time, curl)
	c.x = c.x + c.nx * lateral
	c.y = c.y + c.ny * lateral
	return c
end

function geom.sample(origin, dir, distance, lateral, time, curl_strength)
	local dx, dy, nx, ny = geom.normal(dir)
	local wobble = (geom.noise(distance * 0.04, time * 0.08, 11) - 0.5) * 10
	local bend = math.sin(distance * 0.02 + time * 0.18) * (4 + distance * 0.02)
	local cx, cy = geom.curl(origin.x * 0.02 + distance * 0.03, origin.y * 0.02 + time * 0.05, 19)
	local ox = (bend + wobble) * nx + cx * curl_strength * 18
	local oy = (bend + wobble) * ny + cy * curl_strength * 18
	return {
		x = origin.x + dx * distance + nx * lateral + ox,
		y = origin.y + dy * distance + ny * lateral + oy,
		dx = dx,
		dy = dy,
		nx = nx,
		ny = ny,
	}
end

return geom
