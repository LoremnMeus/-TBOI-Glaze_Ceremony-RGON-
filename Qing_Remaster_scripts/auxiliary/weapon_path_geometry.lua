-- Pure laser / ring path geometry for Gospel carriers, Assassin checkpoints, etc.
-- No Gospel / Assassin / Attack / damage logic here.
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local M = {
	LASER_PATH_SPACING = 96,
	RING_MIN_POINTS = 4,
}

local function clear_buffer(buf)
	if not buf then return end
	for i = #buf, 1, -1 do
		buf[i] = nil
	end
end

-- Visible / collision polyline only. Prefer GetSamples(); do not append theoretical GetEndPoint tip.
function M.laser_path_world_points(laser, out)
	out = out or {}
	clear_buffer(out)
	if not laser then return out end
	local samples = nil
	if laser.GetSamples then
		local ok, list = pcall(function() return laser:GetSamples() end)
		if ok then samples = list end
	end
	if samples and #samples > 0 then
		for i = 0, #samples - 1 do
			local p = samples:Get(i)
			if p then
				out[#out + 1] = p
			end
		end
	elseif laser.Position then
		out[1] = laser.Position
		if laser.GetEndPoint then
			local ep = laser:GetEndPoint()
			if ep then
				out[2] = ep
			end
		end
	end
	return out
end

function M.path_polyline_length(path)
	local L = 0
	for i = 2, #path do
		L = L + (path[i] - path[i - 1]):Length()
	end
	return L
end

function M.point_at_path_dist(path, dist, total_len)
	if not path or #path == 0 then return nil end
	if #path == 1 or dist <= 0 then return path[1] end
	if total_len and dist >= total_len - 0.01 then return path[#path] end
	local remain = dist
	for i = 2, #path do
		local a = path[i - 1]
		local b = path[i]
		local seg = (b - a):Length()
		if seg > 0.01 then
			if remain <= seg then
				return a + (b - a) * (remain / seg)
			end
			remain = remain - seg
		end
	end
	return path[#path]
end

function M.for_each_path_bead(path, spacing, fn)
	if not path or #path == 0 then return end
	if #path == 1 then
		fn(path[1], 1)
		return
	end
	local L = M.path_polyline_length(path)
	if L < 0.01 then
		fn(path[1], 1)
		return
	end
	spacing = spacing or M.LASER_PATH_SPACING
	local gaps = math.max(1, math.floor(L / spacing + 0.5))
	local step = L / gaps
	for k = 0, gaps do
		local d = (k == gaps) and L or (k * step)
		local p = M.point_at_path_dist(path, d, L)
		if p then fn(p, k + 1) end
	end
end

local function path_tangent(path, index)
	if not path or #path == 0 then return Vector(1, 0) end
	if #path == 1 then return Vector(1, 0) end
	index = math.max(1, math.min(index or 1, #path))
	local a, b
	if index >= #path then
		a = path[#path - 1]
		b = path[#path]
	else
		a = path[index]
		b = path[index + 1]
	end
	local d = b - a
	if d:Length() < 0.01 then return Vector(1, 0) end
	return d:Normalized()
end

--- Linear / sample-based laser checkpoints along the visible path.
--- @return { {id=number, position=Vector, direction=Vector}, ... }
function M.GetLinearLaserPoints(laser, opts)
	opts = opts or {}
	local spacing = opts.spacing or M.LASER_PATH_SPACING
	local path = M.laser_path_world_points(laser, opts.path_buf)
	local out = {}
	if #path == 0 then return out end
	local fallback_dir = Vector(1, 0)
	if laser then
		local ang = laser.AngleDegrees
		if ang == nil then ang = laser.Angle end
		if type(ang) == "number" then
			fallback_dir = auxi.MakeVector(ang)
		end
	end
	M.for_each_path_bead(path, spacing, function(world, idx)
		local dir = fallback_dir
		-- Approximate tangent from nearest segment.
		local best_i, best_d = 1, 1e9
		for i = 1, #path do
			local dd = (path[i] - world):LengthSquared()
			if dd < best_d then
				best_d = dd
				best_i = i
			end
		end
		dir = path_tangent(path, best_i)
		if dir:Length() < 0.01 then dir = fallback_dir end
		out[#out + 1] = {
			id = "L" .. tostring(idx),
			position = world,
			direction = dir,
		}
	end)
	return out
end

--- Tech X / ring laser checkpoints along circumference.
function M.GetRingLaserPoints(laser, opts)
	opts = opts or {}
	local spacing = opts.spacing or M.LASER_PATH_SPACING
	local min_count = opts.min_count or M.RING_MIN_POINTS
	local out = {}
	if not laser then return out end
	local radius = tonumber(laser.Radius) or 0
	if radius < 1 then return out end
	local center = laser.Position
	if not center then return out end
	local circ = 2 * math.pi * radius
	local count = math.max(min_count, math.ceil(circ / spacing))
	for i = 0, count - 1 do
		local ang = 360 * i / count
		local dir = auxi.MakeVector(ang)
		out[#out + 1] = {
			id = "R" .. tostring(i + 1),
			position = center + dir * radius,
			direction = dir,
		}
	end
	return out
end

function M.is_ring_laser(laser)
	if not laser then return false end
	if laser.SubType == 2 then return true end
	local r = tonumber(laser.Radius) or 0
	return r > 1 and (not laser.MaxDistance or laser.MaxDistance <= 0.01)
end

return M
