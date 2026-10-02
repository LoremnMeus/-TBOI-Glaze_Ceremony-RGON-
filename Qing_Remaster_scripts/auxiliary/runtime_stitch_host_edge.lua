-- Gate2.5: FindHostEdge — host silhouette edge along a scan direction.
-- Prefer frame alpha mask (GetTexelRegion); then Sprite:GetTexel; then Size fallback.
-- Callers must retry while source == "size"; never lock forever on first-frame fallback.

local head_anchor = require("Qing_Remaster_scripts.auxiliary.entity_head_anchor")

local M = {}

local ALPHA_EPS = 0.08
local mask_cache = {}

local function byte_alpha(raw, px)
	return (string.byte(raw, px * 4 + 4) or 0) / 255
end

local function mask_opaque(mask, x, y)
	if not mask then return false end
	x = math.floor(x + 0.5)
	y = math.floor(y + 0.5)
	if x < 0 or y < 0 or x >= mask.w or y >= mask.h then return false end
	return mask.bits[y * mask.w + x] == true
end

local function get_main_layer_id(sprite)
	if not sprite then return nil end
	local count = 1
	if sprite.GetLayerCount then
		count = math.max(1, sprite:GetLayerCount())
	end
	for id = 0, count - 1 do
		local layer = sprite.GetLayer and sprite:GetLayer(id)
		if layer then
			local visible = true
			if layer.IsVisible then visible = layer:IsVisible() end
			if visible then
				return id
			end
		end
	end
	return 0
end

local function acquire_frame_mask(ent)
	if not REPENTOGON or not ent then return nil end
	local ok, result = pcall(function()
		local sprite = ent:GetSprite()
		if not sprite or not sprite.GetLayerFrameData or not sprite.GetSpritesheet then
			return nil
		end
		local layer_id = get_main_layer_id(sprite)
		if layer_id == nil then return nil end
		local frame = sprite:GetLayerFrameData(layer_id)
		local image = sprite:GetSpritesheet(layer_id)
		if not frame or not image then return nil end
		local crop = frame:GetCrop()
		local layer = sprite:GetLayer(layer_id)
		if layer and layer.GetCropOffset then
			crop = crop + layer:GetCropOffset()
		end
		local fw = math.floor(frame:GetWidth() + 0.5)
		local fh = math.floor(frame:GetHeight() + 0.5)
		if fw < 2 or fh < 2 or fw > 256 or fh > 256 then return nil end
		local cx = math.floor(crop.X + 0.5)
		local cy = math.floor(crop.Y + 0.5)
		local sheet = ""
		if layer and layer.GetSpritesheetPath then
			sheet = layer:GetSpritesheetPath() or ""
		end
		local key = sheet .. "|" .. cx .. "|" .. cy .. "|" .. fw .. "|" .. fh
		local mask = mask_cache[key]
		if not mask then
			if not image.GetTexelRegion then return nil end
			local raw = image:GetTexelRegion(cx, cy, fw, fh)
			if type(raw) ~= "string" or #raw < fw * fh * 4 then
				return nil
			end
			local bits = {}
			local samples = {}
			for y = 0, fh - 1 do
				for x = 0, fw - 1 do
					local px = y * fw + x
					if byte_alpha(raw, px) > ALPHA_EPS then
						bits[px] = true
						if (x + y) % 2 == 0 then
							samples[#samples + 1] = { x = x, y = y }
						end
					end
				end
			end
			if #samples < 4 then return nil end
			mask = { w = fw, h = fh, bits = bits, samples = samples, key = key }
			mask_cache[key] = mask
		end
		return {
			mask = mask,
			layer_id = layer_id,
			sprite = sprite,
			frame = frame,
		}
	end)
	if ok then return result end
	return nil
end

local function ray_last_opaque(mask, sx, sy, dx, dy, max_steps)
	local lx, ly = sx, sy
	local x, y = sx, sy
	if not mask_opaque(mask, sx, sy) then
		return nil, nil
	end
	for _ = 1, max_steps do
		x = x + dx
		y = y + dy
		if not mask_opaque(mask, x, y) then
			return lx, ly
		end
		lx, ly = x, y
	end
	return lx, ly
end

local function find_opaque_seed(mask, prefer_x, prefer_y)
	if mask_opaque(mask, prefer_x, prefer_y) then
		return prefer_x, prefer_y
	end
	local best, best_d2
	local samples = mask.samples or {}
	for i = 1, #samples do
		local s = samples[i]
		local dx = s.x - prefer_x
		local dy = s.y - prefer_y
		local d2 = dx * dx + dy * dy
		if not best_d2 or d2 < best_d2 then
			best, best_d2 = s, d2
		end
	end
	if best then
		return best.x, best.y
	end
	return nil, nil
end

local function normalize_dir(direction)
	local dx = 1
	local dy = 0
	if direction then
		if type(direction) == "table" and direction.X then
			dx, dy = direction.X or 0, direction.Y or 0
		elseif type(direction) == "table" then
			dx, dy = direction[1] or 0, direction[2] or 0
		end
	end
	local len = math.sqrt(dx * dx + dy * dy)
	if len < 1e-4 then
		return Vector(1, 0)
	end
	return Vector(dx / len, dy / len)
end

local function size_fallback(host, direction)
	local size = math.max(8, host.Size or 12)
	return {
		localPos = direction * (size * 0.55),
		normal = direction,
		source = "size",
	}
end

local function try_mask_edge(host, direction)
	local info = acquire_frame_mask(host)
	if not info or not info.mask then return nil end
	local mask = info.mask
	local spr = info.sprite
	local sx, sy = find_opaque_seed(mask, mask.w * 0.5, mask.h * 0.5)
	if not sx then return nil end

	-- Frame-space scan: FlipX/Y invert the sample axis so world "right" matches sprite.
	local fdx, fdy = direction.X, direction.Y
	if spr.FlipX then fdx = -fdx end
	if spr.FlipY then fdy = -fdy end
	local flen = math.sqrt(fdx * fdx + fdy * fdy)
	if flen < 1e-4 then return nil end
	fdx, fdy = fdx / flen, fdy / flen

	local max_steps = math.ceil(math.max(mask.w, mask.h) * 1.5) + 8
	local ex, ey = ray_last_opaque(mask, sx, sy, fdx, fdy, max_steps)
	if not ex then return nil end

	local localPos = head_anchor.LocalOffsetFromFramePoint(info.sprite, info.layer_id, false, ex, ey)
	if not localPos then return nil end
	return {
		localPos = localPos,
		normal = direction,
		source = "mask",
		frame_xy = { ex, ey },
	}
end

local function try_texel_edge(host, direction)
	local spr = host:GetSprite()
	if not spr or not spr.GetTexel then return nil end
	local max_r = math.max(12, (host.Size or 12) * 2.5)
	local last = nil
	for t = 0, max_r, 1 do
		local sample = direction * t
		if spr.FlipX then sample = Vector(-sample.X, sample.Y) end
		if spr.FlipY then sample = Vector(sample.X, -sample.Y) end
		local ok, texel = pcall(function()
			return spr:GetTexel(sample, Vector.Zero, ALPHA_EPS)
		end)
		if ok and texel and (texel.Alpha or 0) > ALPHA_EPS then
			last = direction * t
		elseif last and t > 3 then
			break
		end
	end
	if not last then return nil end
	local localPos = last
	local scale = spr.Scale or Vector(1, 1)
	localPos = Vector(localPos.X * (scale.X or 1), localPos.Y * (scale.Y or 1))
	if spr.FlipX then localPos = Vector(-localPos.X, localPos.Y) end
	if spr.FlipY then localPos = Vector(localPos.X, -localPos.Y) end
	if spr.Offset then
		localPos = localPos + spr.Offset
	end
	return {
		localPos = localPos,
		normal = direction,
		source = "texel",
	}
end

--- Find the last opaque pixel along direction from sprite interior.
--- @return { localPos: Vector, normal: Vector, source: "mask"|"texel"|"size" }
function M.find_host_edge(host, direction)
	direction = normalize_dir(direction)
	if not host or not host:Exists() then
		return {
			localPos = direction * 12,
			normal = direction,
			source = "size",
		}
	end
	local edge = try_mask_edge(host, direction)
	if edge then return edge end
	edge = try_texel_edge(host, direction)
	if edge then return edge end
	return size_fallback(host, direction)
end

--- Upgradeable edge cache policy for grafts.
--- Never permanently lock on first-frame Size fallback.
function M.update_edge_cache(cached, host, direction)
	local edge = M.find_host_edge(host, direction)
	if not cached then
		return edge
	end
	if cached.source == "size" then
		return edge
	end
	if edge.source ~= "size" then
		return edge
	end
	return cached
end

return M
