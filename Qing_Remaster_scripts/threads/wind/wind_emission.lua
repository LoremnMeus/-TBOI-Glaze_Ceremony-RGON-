-- Storm V7.3 visual emission / visibility bounds.
-- screen_view_rect = actual rendered playfield (fade)
-- simulation_rect = expanded activity region (spawn / recycle)
-- Cyclone paths live in cyclone_streamline.lua (analytical; no search banks).

local physics = require("Qing_Remaster_scripts.threads.wind.wind_physics")

local M = {}

local VIEW_MARGIN = 8
local SIM_MARGIN = 56
local SPRITE_HALF = 14
local TRAIL_HALF = 22
local EDGE_FADE_L = 64

local EDGE_NAME = {[0] = "top", [1] = "bottom", [2] = "left", [3] = "right"}

local function room_corners()
	local room = Game():GetRoom()
	return room:GetTopLeftPos(), room:GetBottomRightPos(), room:GetCenterPos()
end

local function make_rect_from_corners(tl, br, margin)
	margin = margin or 0
	return {
		minx = math.min(tl.X, br.X) - margin,
		miny = math.min(tl.Y, br.Y) - margin,
		maxx = math.max(tl.X, br.X) + margin,
		maxy = math.max(tl.Y, br.Y) + margin,
	}
end

local function make_rect(margin)
	local tl, br = room_corners()
	return make_rect_from_corners(tl, br, margin)
end

--- Actual rendered viewport in world space (for Alpha fade).
function M.screen_view_rect()
	local sw = (Isaac.GetScreenWidth and Isaac.GetScreenWidth()) or nil
	local sh = (Isaac.GetScreenHeight and Isaac.GetScreenHeight()) or nil
	if sw and sh and sw > 4 and sh > 4 then
		local pts = nil
		if Isaac.RenderToWorld then
			pts = {
				Isaac.RenderToWorld(Vector(2, 2)),
				Isaac.RenderToWorld(Vector(sw - 2, 2)),
				Isaac.RenderToWorld(Vector(sw - 2, sh - 2)),
				Isaac.RenderToWorld(Vector(2, sh - 2)),
			}
		elseif Isaac.ScreenToWorld then
			pts = {
				Isaac.ScreenToWorld(Vector(2, 2)),
				Isaac.ScreenToWorld(Vector(sw - 2, 2)),
				Isaac.ScreenToWorld(Vector(sw - 2, sh - 2)),
				Isaac.ScreenToWorld(Vector(2, sh - 2)),
			}
		end
		if pts then
			local minx, miny = pts[1].X, pts[1].Y
			local maxx, maxy = minx, miny
			for i = 2, 4 do
				local p = pts[i]
				if p.X < minx then minx = p.X end
				if p.Y < miny then miny = p.Y end
				if p.X > maxx then maxx = p.X end
				if p.Y > maxy then maxy = p.Y end
			end
			if (maxx - minx) > 40 and (maxy - miny) > 40 then
				return {minx = minx, miny = miny, maxx = maxx, maxy = maxy}
			end
		end
	end
	return make_rect(VIEW_MARGIN)
end

function M.view_rect()
	return make_rect(VIEW_MARGIN)
end

function M.simulation_rect()
	local scr = M.screen_view_rect()
	return {
		minx = scr.minx - SIM_MARGIN,
		miny = scr.miny - SIM_MARGIN,
		maxx = scr.maxx + SIM_MARGIN,
		maxy = scr.maxy + SIM_MARGIN,
	}
end

function M.visible_rect(margin)
	if margin then return make_rect(margin) end
	return M.simulation_rect()
end

function M.point_inside(pos, rect, half)
	half = half or 0
	return pos.X + half >= rect.minx
		and pos.X - half <= rect.maxx
		and pos.Y + half >= rect.miny
		and pos.Y - half <= rect.maxy
end

function M.bbox_fully_outside(pos, half, rect)
	half = half or SPRITE_HALF
	rect = rect or M.simulation_rect()
	return pos.X + half < rect.minx
		or pos.X - half > rect.maxx
		or pos.Y + half < rect.miny
		or pos.Y - half > rect.maxy
end

function M.intersects_view(pos, half, view)
	half = half or SPRITE_HALF
	view = view or M.screen_view_rect()
	return not M.bbox_fully_outside(pos, half, view)
end

function M.any_point_visible(points, half, rect)
	if not points or #points < 1 then return false end
	half = half or SPRITE_HALF
	rect = rect or M.screen_view_rect()
	for i = 1, #points do
		if not M.bbox_fully_outside(points[i], half, rect) then
			return true
		end
	end
	return false
end

function M.trail_fully_outside(trail, half, rect)
	if not trail or #trail < 1 then return true end
	return not M.any_point_visible(trail, half or TRAIL_HALF, rect)
end

function M.trail_draw_fully_outside(trail, half, rect)
	if not trail or #trail < 1 then return true end
	half = half or TRAIL_HALF
	rect = rect or M.simulation_rect()
	if not M.bbox_fully_outside(trail[1], half, rect) then return false end
	if not M.bbox_fully_outside(trail[#trail], half, rect) then return false end
	for i = 1, #trail - 1 do
		local mid = (trail[i] + trail[i + 1]) * 0.5
		if not M.bbox_fully_outside(mid, half, rect) then
			return false
		end
	end
	return true
end

function M.exit_target(pos, dir, rect)
	rect = rect or M.simulation_rect()
	dir = dir or Vector(0, 1)
	local len = dir:Length()
	if len < 1e-6 then dir = Vector(0, 1) else dir = dir * (1 / len) end
	local t = 0
	local p = pos
	for _ = 1, 40 do
		t = t + 24
		p = pos + dir * t
		if M.bbox_fully_outside(p, SPRITE_HALF, rect) then
			return p
		end
	end
	local cx = (rect.minx + rect.maxx) * 0.5
	local cy = (rect.miny + rect.maxy) * 0.5
	return Vector(cx, cy) + dir * 400
end

function M.spawn_upwind_rng(blow, rng01, margin)
	margin = margin or SIM_MARGIN + 12
	local tl, br, center = room_corners()
	local b = blow:Normalized()
	local side = Vector(-b.Y, b.X)
	local span_x = math.abs(br.X - tl.X)
	local span_y = math.abs(br.Y - tl.Y)
	local along = math.max(span_x, span_y) * 0.52 + margin
	local lateral = ((rng01 or 0.5) * 2 - 1) * math.max(span_x, span_y) * 0.52
	return center - b * along + side * lateral
end

function M.spawn_on_edge(edge, t, margin)
	margin = margin or SIM_MARGIN
	local rect = M.simulation_rect()
	t = t or 0.5
	if edge == 0 then
		return Vector(rect.minx + t * (rect.maxx - rect.minx), rect.miny - 8), Vector(0, 1)
	elseif edge == 1 then
		return Vector(rect.minx + t * (rect.maxx - rect.minx), rect.maxy + 8), Vector(0, -1)
	elseif edge == 2 then
		return Vector(rect.minx - 8, rect.miny + t * (rect.maxy - rect.miny)), Vector(1, 0)
	end
	return Vector(rect.maxx + 8, rect.miny + t * (rect.maxy - rect.miny)), Vector(-1, 0)
end

function M.spawn_outside_edge_rng(rng01_a, rng01_b, margin)
	local edge = math.floor((rng01_a or 0) * 4) % 4
	local pos = M.spawn_on_edge(edge, rng01_b, margin)
	return pos, edge
end

function M.downwind_edge_distance(pos, blow, rect)
	rect = rect or M.screen_view_rect()
	blow = blow or Vector(0, 1)
	local len = blow:Length()
	if len < 1e-6 then return 999 end
	local b = blow * (1 / len)
	local tx, ty = math.huge, math.huge
	if b.X > 1e-4 then
		tx = (rect.maxx - pos.X) / b.X
	elseif b.X < -1e-4 then
		tx = (rect.minx - pos.X) / b.X
	end
	if b.Y > 1e-4 then
		ty = (rect.maxy - pos.Y) / b.Y
	elseif b.Y < -1e-4 then
		ty = (rect.miny - pos.Y) / b.Y
	end
	local t = math.min(tx, ty)
	if t < 0 then return 0 end
	if t == math.huge then return 999 end
	return t
end

function M.edge_fade_alpha(pos, blow, rect, band)
	band = band or EDGE_FADE_L
	local d = M.downwind_edge_distance(pos, blow, rect or M.screen_view_rect())
	if d >= band then return 1 end
	if d <= 0 then return 0 end
	local t = d / band
	return t * t * (3 - 2 * t)
end

function M.edge_fade_band()
	return EDGE_FADE_L
end

function M.edge_name(edge)
	return EDGE_NAME[edge] or "?"
end

function M.spawn_in_column(center, radius, rng01_ang, rng01_r)
	local ang = (rng01_ang or 0) * 360
	local r = (radius or 40) * (0.25 + (rng01_r or 0.5) * 0.55)
	local rad = math.rad(ang)
	return Vector(center.X + math.cos(rad) * r, center.Y + math.sin(rad) * r)
end

function M.default_blow(ang)
	return physics.wind_blow_dir(ang or 0)
end

function M.sprite_half()
	return SPRITE_HALF
end

function M.trail_half()
	return TRAIL_HALF
end

function M.empty_edge_stats()
	return {
		[0] = {spawn_attempt = 0, spawn_success = 0, entered_view = 0, reached_cyclone = 0, captured_by_column = 0, recycled = 0},
		[1] = {spawn_attempt = 0, spawn_success = 0, entered_view = 0, reached_cyclone = 0, captured_by_column = 0, recycled = 0},
		[2] = {spawn_attempt = 0, spawn_success = 0, entered_view = 0, reached_cyclone = 0, captured_by_column = 0, recycled = 0},
		[3] = {spawn_attempt = 0, spawn_success = 0, entered_view = 0, reached_cyclone = 0, captured_by_column = 0, recycled = 0},
	}
end

return M
