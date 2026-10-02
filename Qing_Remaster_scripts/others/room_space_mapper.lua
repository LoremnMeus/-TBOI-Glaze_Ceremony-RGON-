-- Shared room usable-space mapping (Death Field / Aeon? / future consumers).
-- norm = position identity inside room usable bounds (0..1), not pixel deltas.
local Mapper = {}

Mapper.DEFAULT_MARGIN = 48

local function clamp01(x)
	x = tonumber(x) or 0
	if x < 0 then return 0 end
	if x > 1 then return 1 end
	return x
end

--- opts.margin: inset from Room TopLeft/BottomRight (default 48)
function Mapper.get_usable_bounds(opts)
	opts = opts or {}
	local margin = tonumber(opts.margin)
	if margin == nil then
		margin = Mapper.DEFAULT_MARGIN
	end
	local room = Game():GetRoom()
	local tl = room:GetTopLeftPos()
	local br = room:GetBottomRightPos()
	local left = tl.X + margin
	local right = br.X - margin
	local top = tl.Y + margin
	local bottom = br.Y - margin
	if right < left then
		left, right = tl.X, br.X
	end
	if bottom < top then
		top, bottom = tl.Y, br.Y
	end
	return left, right, top, bottom
end

function Mapper.norm_to_world(norm_x, norm_y, opts)
	local left, right, top, bottom = Mapper.get_usable_bounds(opts)
	return Vector(
		left + clamp01(norm_x) * (right - left),
		top + clamp01(norm_y) * (bottom - top)
	)
end

function Mapper.world_to_norm(pos, opts)
	if not pos then
		return 0.5, 0.5
	end
	local left, right, top, bottom = Mapper.get_usable_bounds(opts)
	local w = math.max(1, right - left)
	local h = math.max(1, bottom - top)
	return clamp01((pos.X - left) / w), clamp01((pos.Y - top) / h)
end

-- Destiny Anchor 同源：标准 13×7 snapshot 窗口（墙内可玩格）
Mapper.STANDARD_GRID_W = 13
Mapper.STANDARD_GRID_H = 7
Mapper.GRID_TILE = 40

local function playable_axis_center_grid(room_size)
	-- 墙格约在 0 与 size-1；可玩 1 .. size-2
	local lo = 1
	local hi = math.max(1, (tonumber(room_size) or 1) - 2)
	return math.floor((lo + hi) / 2)
end

--- 与 Destiny Anchor compute_snapshot_origin 同一套 ox/oy 钳制。
--- 某轴无法完整容纳标准窗口时：该轴 center 退化为房间可玩中心（不缩放轨迹）。
--- @return table canvas
function Mapper.select_standard_canvas(pos, opts)
	opts = opts or {}
	local snap_w = tonumber(opts.grid_w) or Mapper.STANDARD_GRID_W
	local snap_h = tonumber(opts.grid_h) or Mapper.STANDARD_GRID_H
	local room = Game():GetRoom()
	local wd = room:GetGridWidth()
	local ht = room:GetGridHeight()
	pos = pos or Vector.Zero

	local pidx = room:GetGridIndex(pos)
	local px = pidx % wd
	local py = math.floor(pidx / wd)

	-- 与 Destiny 一致：ox ∈ [1, max(1, wd-1-SNAP_W)]
	local ox = px - math.floor(snap_w / 2)
	local oy = py - math.floor(snap_h / 2)
	ox = math.max(1, math.min(ox, math.max(1, wd - 1 - snap_w)))
	oy = math.max(1, math.min(oy, math.max(1, ht - 1 - snap_h)))

	-- wd >= SNAP_W+2 时窗口可完整落在墙内侧
	local full_width = (wd - 1 - snap_w) >= 1
	local full_height = (ht - 1 - snap_h) >= 1

	local center_gx
	local center_gy
	if full_width then
		center_gx = ox + math.floor(snap_w / 2)
	else
		center_gx = playable_axis_center_grid(wd)
	end
	if full_height then
		center_gy = oy + math.floor(snap_h / 2)
	else
		center_gy = playable_axis_center_grid(ht)
	end

	local center_index = center_gx + center_gy * wd
	local center = room:GetGridPosition(center_index)
	local tl = room:GetGridPosition(ox + oy * wd)
	local br = room:GetGridPosition((ox + snap_w - 1) + (oy + snap_h - 1) * wd)
	local tile = Mapper.GRID_TILE

	return {
		grid_origin_x = ox,
		grid_origin_y = oy,
		grid_w = snap_w,
		grid_h = snap_h,
		room_grid_w = wd,
		room_grid_h = ht,
		left = tl.X,
		top = tl.Y,
		right = br.X,
		bottom = br.Y,
		center = center,
		width = snap_w * tile,
		height = snap_h * tile,
		full_width = full_width,
		full_height = full_height,
	}
end

return Mapper
