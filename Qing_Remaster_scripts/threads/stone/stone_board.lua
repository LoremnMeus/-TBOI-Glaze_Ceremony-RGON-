-- Runtime chessboard floor overlay (placeholder). No STB swap.

local runtime = require("Qing_Remaster_scripts.threads.stone.stone_runtime")
local route = require("Qing_Remaster_scripts.threads.stone.stone_route")

local board = {}

local CELL = 40

function board.is_active()
	return runtime.is_board_active()
end

function board.is_current_room_on_floor()
	return runtime.has_layout() and runtime.floor_matches()
end

--- Legacy hook; map layer no longer uses Floraine board effects for navigation.
function board.start_(_pos)
end

function board.render_floor_overlay()
	if not board.is_active() then return end
	if not board.is_current_room_on_floor() then return end
	if not Isaac.DrawLine then return end
	local room = Game():GetRoom()
	local tl = room:GetTopLeftPos()
	local br = room:GetBottomRightPos()
	local on_route = route.is_route_room()
	local a = on_route and 0.35 or 0.18
	local dark = KColor(0.08, 0.08, 0.08, a)
	local light = KColor(0.85, 0.85, 0.85, a * 0.7)
	local y0 = math.floor(tl.Y / CELL) * CELL
	local x0 = math.floor(tl.X / CELL) * CELL
	for y = y0, br.Y, CELL do
		for x = x0, br.X, CELL do
			local gx = math.floor(x / CELL)
			local gy = math.floor(y / CELL)
			local col = (((gx + gy) % 2) == 0) and dark or light
			local p1 = Isaac.WorldToScreen(Vector(x, y))
			local p2 = Isaac.WorldToScreen(Vector(x + CELL, y))
			local p3 = Isaac.WorldToScreen(Vector(x, y + CELL))
			Isaac.DrawLine(p1, p2, col, col, 1)
			Isaac.DrawLine(p1, p3, col, col, 1)
		end
	end
end

return board
