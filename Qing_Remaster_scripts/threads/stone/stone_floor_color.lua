-- Stone burial ground color from Backdrop floor image (not Room:GetFloorColor alone).
-- Decode: RGBA8 via string.byte/255 — see codex_work/notes/repentogon_item_color_analysis.md
--   and Item_color_holder.lua (same convention).
-- UV: Candidate B — world offset from room TL, tiled into GetFloorImage with wrap
--   (verified in-game 2026-10-24 vs A_room_linear; FloorImage corners often transparent).
-- Call only on init / room-relevant refresh; never every PRE_NPC_RENDER.

local floor_color = {}

local BYTES_PER_PIXEL = 4
local ALPHA_MIN = 0.05
-- Grid cell size in world units (Isaac); used as tiling period reference for B.
local GRID_CELL = 40

local function read_modulation(room)
	room = room or Game():GetRoom()
	if room and room.GetFloorColor then
		local ok, c = pcall(function() return room:GetFloorColor() end)
		if ok and c then
			return {
				r = c.R or 1,
				g = c.G or 1,
				b = c.B or 1,
				a = c.A or 1,
				ro = c.RO or 0,
				go = c.GO or 0,
				bo = c.BO or 0,
				source = "modulation",
			}
		end
	end
	return {r = 1, g = 1, b = 1, a = 1, ro = 0, go = 0, bo = 0, source = "neutral"}
end

local function unpack_rgba8(blob, pixel_index)
	if type(blob) ~= "string" then
		return nil, "invalid_blob"
	end
	local offset = (pixel_index or 0) * BYTES_PER_PIXEL + 1
	if #blob < offset + 3 then
		return nil, "short_blob"
	end
	local r, g, b, a = string.byte(blob, offset, offset + 3)
	if not r then
		return nil, "byte_nil"
	end
	return {
		r = r / 255,
		g = (g or 0) / 255,
		b = (b or 0) / 255,
		a = (a or 0) / 255,
	}, nil
end

--- Candidate B: treat floor image as repeating tiles from room TL (world % image size).
-- In-game locked 2026-10-24 (A_room_linear hit letterboxed transparent regions).
local function world_to_texel_grid_tiled(room, world, img_w, img_h)
	local tl = room:GetTopLeftPos()
	local local_x = world.X - tl.X
	local local_y = world.Y - tl.Y
	local tw = math.max(1, img_w)
	local th = math.max(1, img_h)
	local tx = math.floor(local_x % tw)
	local ty = math.floor(local_y % th)
	if tx < 0 then tx = tx + tw end
	if ty < 0 then ty = ty + th end
	tx = math.max(0, math.min(img_w - 1, tx))
	ty = math.max(0, math.min(img_h - 1, ty))
	local u = tx / math.max(1, img_w - 1)
	local v = ty / math.max(1, img_h - 1)
	return tx, ty, u, v
end

local function sample_pixel(image, x, y)
	local ok, raw = pcall(function()
		return image:GetTexelRegion(x, y, 1, 1)
	end)
	if not ok then
		return nil, "get_failed"
	end
	return unpack_rgba8(raw, 0)
end

--- Sample burial ground color at world_pos (prefer grid center of that cell).
-- Returns {r,g,b,a[,ro,go,bo], source, texel?, uv?}.
-- source: "texture" | "modulation" | "neutral"
-- Does not multiply texture RGB by Room:GetFloorColor (buffer already composed).
function floor_color.sample_burial_ground(room, world_pos)
	room = room or Game():GetRoom()
	local fallback = read_modulation(room)
	if not world_pos then
		return fallback
	end
	if not (room.GetBackdrop and REPENTOGON) then
		return fallback
	end
	local ok_bd, backdrop = pcall(function() return room:GetBackdrop() end)
	if not ok_bd or not backdrop or not backdrop.GetFloorImage then
		return fallback
	end
	local ok_img, image = pcall(function() return backdrop:GetFloorImage() end)
	if not ok_img or not image then
		return fallback
	end
	local w, h = 0, 0
	if image.GetWidth then
		local ok, v = pcall(function() return image:GetWidth() end)
		if ok then w = v end
	end
	if image.GetHeight then
		local ok, v = pcall(function() return image:GetHeight() end)
		if ok then h = v end
	end
	if w < 1 or h < 1 or not image.GetTexelRegion then
		return fallback
	end

	-- Snap to grid center for stable burial feet color.
	local gidx = room:GetGridIndex(world_pos)
	local sample_pos = room:GetGridPosition(gidx)
	local tx, ty, u, v = world_to_texel_grid_tiled(room, sample_pos, w, h)
	local rgba, err = sample_pixel(image, tx, ty)
	if not rgba or err then
		return fallback
	end
	if (rgba.a or 0) < ALPHA_MIN then
		-- Transparent texel: try a 3×3 neighborhood, then modulation fallback.
		local sum_r, sum_g, sum_b, sum_a, n = 0, 0, 0, 0, 0
		for dy = -1, 1 do
			for dx = -1, 1 do
				local px = math.max(0, math.min(w - 1, tx + dx))
				local py = math.max(0, math.min(h - 1, ty + dy))
				local c = sample_pixel(image, px, py)
				if c and (c.a or 0) >= ALPHA_MIN then
					sum_r = sum_r + c.r
					sum_g = sum_g + c.g
					sum_b = sum_b + c.b
					sum_a = sum_a + c.a
					n = n + 1
				end
			end
		end
		if n < 1 then
			return fallback
		end
		rgba = {r = sum_r / n, g = sum_g / n, b = sum_b / n, a = sum_a / n}
	end

	return {
		r = rgba.r,
		g = rgba.g,
		b = rgba.b,
		a = 1,
		ro = 0,
		go = 0,
		bo = 0,
		source = "texture",
		mapping = "B_grid_tiled",
		cell = GRID_CELL,
		texel = {x = tx, y = ty},
		uv = {u = u, v = v},
		image = {width = w, height = h},
		grid_index = gidx,
	}
end

function floor_color.read_modulation(room)
	return read_modulation(room)
end

return floor_color
