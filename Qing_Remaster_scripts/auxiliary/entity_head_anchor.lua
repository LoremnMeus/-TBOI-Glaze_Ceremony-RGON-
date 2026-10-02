-- 实体头部 / 脸部 Sprite 局部锚点（runtime owner）：
-- 找头图层 → 当前帧 Pivot/Pos/Scale/Rotation → 顶部不透明 texel Y（缓存）
-- → OverlayEffect 回退 → Size 回退。
-- OverlayEffect 只是 head/face 几何的 fallback，不是真正的头皮或脸顶。
-- LocalOffsetFromFramePoint 只含 Sprite/ANM2 geometry。
-- GetEntity*Anchor 再叠加 Entity.SpriteRotation + Entity.SpriteOffset。
-- 返回值供 WorldToRenderPosition(Position+PositionOffset)+callbackOffset+anchor 使用。

local M = {}

local HEAD_HELPER_ANM2 = "gfx/mimics/Gospel/gospel_head_helper.anm2"
--- Formal ScanScalpY alpha gate. Included in scalp_cache key.
local SCALP_ALPHA_THRESHOLD = 0.1

local function make_head_helper()
	local spr = Sprite()
	spr:Load(HEAD_HELPER_ANM2, true)
	spr:Play("Idle", true)
	return spr
end

-- Production and debug use separate helper Sprites because texel analysis
-- mutates spritesheet/crop state.
-- This is an isolation rule for diagnostics, not part of scalp visibility semantics.
local production_head_helper = make_head_helper()
local debug_head_helper = make_head_helper()

local head_layer_cache = {}
-- Scalp geometry cache from complete center-column scans.
-- Policy: cache hit and empty; never cache unavailable.
local scalp_cache = {}

-- Last spritesheet bound per helper Sprite (weak keys).
local helper_bound_sheet = setmetatable({}, { __mode = "k" })

-- Dev counters for ScanScalpY cost (not saved).
local scalp_stats = {
	cache_hits = 0,
	scans = 0,
	texel_samples = 0,
	hit_scans = 0,
	empty_scans = 0,
}

local HEAD_LAYER_NAMES = {
	"head", "skull", "face", "brain", "hair", "helmet", "hat", "top", "main", "body",
}
local HEAD_LAYER_IGNORE = {
	"glow", "shadow", "dirt", "hole", "effect", "fx", "particle",
	"darkness", "ray", "wing", "halo", "rag", "rope", "noose",
	"overlay", "tear",
}

-- Face region as a fraction of the visible head (below scalp). Owner params, not consumer constants.
local FACE_TOP_RATIO = 0.12
local FACE_BOTTOM_RATIO = 0.72
local FACE_WIDTH_RATIO = 0.78

local function size_radius(ent)
	local multi = ent.SizeMulti or Vector(1, 1)
	return (ent.Size or 13) * (0.5 * ((multi.X or 1) + (multi.Y or 1)))
end

local function layer_name_ignored(name)
	for i = 1, #HEAD_LAYER_IGNORE do
		if string.find(name, HEAD_LAYER_IGNORE[i], 1, true) then
			return true
		end
	end
	return false
end

local function layer_name_priority(name)
	local best = 9999
	for i = 1, #HEAD_LAYER_NAMES do
		if string.find(name, HEAD_LAYER_NAMES[i], 1, true) and i < best then
			best = i
		end
	end
	return best
end

local function is_layer_valid(sprite, layer_id, ignore_state, ignore_overlay)
	local layer_state = sprite:GetLayer(layer_id)
	if not layer_state then return false, false end
	if not ignore_state and layer_state.IsVisible and not layer_state:IsVisible() then
		return false, false
	end
	local overlay_name = sprite.GetOverlayAnimation and sprite:GetOverlayAnimation() or ""
	for pass = 1, 2 do
		local use_overlay = pass == 2
		if use_overlay and (ignore_overlay or overlay_name == "") then
			-- skip
		else
			local anim_data
			if use_overlay then
				anim_data = sprite.GetOverlayAnimationData and sprite:GetOverlayAnimationData()
			else
				anim_data = sprite.GetCurrentAnimationData and sprite:GetCurrentAnimationData()
			end
			local layer_data = anim_data and anim_data.GetLayer and anim_data:GetLayer(layer_id)
			if layer_data and layer_data.IsVisible and layer_data:IsVisible() then
				local frame_id = 0
				if use_overlay then
					frame_id = sprite.GetOverlayFrame and sprite:GetOverlayFrame() or 0
				else
					frame_id = sprite.GetFrame and sprite:GetFrame() or 0
				end
				local frame_data = layer_data.GetFrame and layer_data:GetFrame(frame_id)
				if frame_data and frame_data.IsVisible and frame_data:IsVisible() then
					return true, use_overlay
				end
			end
		end
	end
	return false, false
end

function M.FindHeadLayer(sprite)
	if not sprite or not sprite.GetLayerCount or not sprite.GetLayer then return nil, false end
	local overlay_name = sprite.GetOverlayAnimation and sprite:GetOverlayAnimation() or ""
	local anim_name = sprite.GetAnimation and sprite:GetAnimation() or ""
	local key = (sprite:GetFilename() or "") .. "|" .. overlay_name .. "|" .. anim_name
	if not head_layer_cache[key] then
		local ranked = {}
		for layer_id = 0, sprite:GetLayerCount() - 1 do
			local ok = is_layer_valid(sprite, layer_id, true, false)
			if ok then
				local layer_state = sprite:GetLayer(layer_id)
				local name = string.lower(layer_state and layer_state.GetName and layer_state:GetName() or "")
				local prio = layer_name_priority(name)
				-- Ignore decorative names, but never drop a layer that also matches a head keyword
				-- (e.g. "HeadOverlay" contains both "head" and "overlay").
				if prio < 9999 or not layer_name_ignored(name) then
					ranked[#ranked + 1] = {
						id = layer_id,
						priority = prio + layer_id * 0.01,
					}
				end
			end
		end
		table.sort(ranked, function(a, b)
			return a.priority < b.priority
		end)
		head_layer_cache[key] = ranked
	end
	local ranked = head_layer_cache[key]
	for i = 1, #ranked do
		local ok, from_overlay = is_layer_valid(sprite, ranked[i].id, false, false)
		if ok then
			return ranked[i].id, from_overlay
		end
	end
	return nil, false
end

function M.LockHeadLayer(data, layer_id, from_overlay)
	if not data then return layer_id, from_overlay end
	if data.head_layer == nil then
		data.head_layer = layer_id
		data.head_overlay = from_overlay
		data.head_pending = nil
		data.head_pending_n = 0
		return layer_id, from_overlay
	end
	if not layer_id then
		return data.head_layer, data.head_overlay
	end
	if data.head_layer == layer_id and data.head_overlay == from_overlay then
		data.head_pending = nil
		data.head_pending_n = 0
		return data.head_layer, data.head_overlay
	end
	local pend = tostring(layer_id) .. "|" .. tostring(from_overlay)
	if data.head_pending ~= pend then
		data.head_pending = pend
		data.head_pending_n = 1
		return data.head_layer, data.head_overlay
	end
	data.head_pending_n = (data.head_pending_n or 0) + 1
	if data.head_pending_n >= 2 then
		data.head_layer = layer_id
		data.head_overlay = from_overlay
		data.head_pending = nil
		data.head_pending_n = 0
	end
	return data.head_layer, data.head_overlay
end

local function get_helper_layer(helper)
	if helper and helper.GetLayer then
		return helper:GetLayer(0)
	end
	return nil
end

local function prepare_helper_sheet(helper, sheet)
	if helper_bound_sheet[helper] == sheet then
		helper.FlipY = false
		return
	end
	local replaced = pcall(function()
		helper:ReplaceSpritesheet(0, sheet, true)
	end)
	if not replaced then
		helper:ReplaceSpritesheet(0, sheet)
		if helper.LoadGraphics then
			helper:LoadGraphics()
		end
	end
	helper_bound_sheet[helper] = sheet
	helper.FlipY = false
end

--- Load sheet + SetCropOffset, run fn(helper), always restore previous crop
--- (even when fn / ReplaceSpritesheet fails).
local function with_helper_sheet_crop(helper, sheet, crop, fn)
	local layer = get_helper_layer(helper)
	local old_crop = Vector.Zero
	if layer and layer.GetCropOffset then
		local ok_old, cur = pcall(function()
			return layer:GetCropOffset()
		end)
		if ok_old and cur then
			old_crop = Vector(cur.X, cur.Y)
		end
	end

	local ok, r1, r2, r3 = pcall(function()
		prepare_helper_sheet(helper, sheet)
		if layer and layer.SetCropOffset then
			layer:SetCropOffset(crop or Vector.Zero)
		end
		return fn(helper)
	end)

	if layer and layer.SetCropOffset then
		pcall(function()
			layer:SetCropOffset(old_crop)
		end)
	end

	if not ok then
		return nil, nil, r1
	end
	return r1, r2, r3
end

local function resolve_layer_crop_sheet(sprite, layer_id, from_overlay)
	if not sprite or layer_id == nil then
		return nil, "bad_args"
	end
	local frame_data
	if from_overlay and sprite.GetOverlayLayerFrameData then
		frame_data = sprite:GetOverlayLayerFrameData(layer_id)
	elseif sprite.GetLayerFrameData then
		frame_data = sprite:GetLayerFrameData(layer_id)
	end
	local layer_state = sprite.GetLayer and sprite:GetLayer(layer_id) or nil
	if not frame_data or not layer_state then
		return nil, "no_frame"
	end
	local width = frame_data:GetWidth()
	local height = frame_data:GetHeight()
	local crop = frame_data:GetCrop()
	if layer_state.GetCropOffset then
		crop = crop + layer_state:GetCropOffset()
	end
	local sheet = layer_state.GetSpritesheetPath and layer_state:GetSpritesheetPath() or ""
	return {
		frame_data = frame_data,
		layer_state = layer_state,
		crop = crop,
		width = width,
		height = height,
		sheet = sheet,
	}
end

local function build_scalp_cache_key(sheet, crop, size_x, size_y)
	return sheet
		.. "|"
		.. tostring(crop.X)
		.. "|"
		.. tostring(crop.Y)
		.. "|"
		.. tostring(size_x)
		.. "|"
		.. tostring(size_y)
		.. "|"
		.. tostring(SCALP_ALPHA_THRESHOLD)
end

--- Scan the complete center column of the selected frame crop.
---
--- States:
---   hit
---     At least one opaque texel exists on the center column.
---
---   empty
---     The complete center column was scanned successfully and contains
---     no texel above SCALP_ALPHA_THRESHOLD.
---
---   unavailable
---     The scan could not be performed.
---
--- IMPORTANT:
--- Never infer "empty" from sparse/coarse sampling.
--- Empty is a statement about the COMPLETE center column.
---
--- Cache policy: cache both hit and empty (complete-column facts).
--- unavailable is never cached.
function M.ScanScalpY(sprite, layer_id, frame_data, layer_state)
	if not frame_data or not layer_state or not production_head_helper.GetTexel then
		return nil, "unavailable"
	end
	local crop = frame_data:GetCrop()
	if layer_state.GetCropOffset then
		crop = crop + layer_state:GetCropOffset()
	end
	local size = Vector(frame_data:GetWidth(), frame_data:GetHeight())
	if size.X < 2 or size.Y < 2 then
		return nil, "unavailable"
	end
	size = Vector(math.min(size.X, 512), math.min(size.Y, 512))
	local sheet = layer_state.GetSpritesheetPath and layer_state:GetSpritesheetPath() or ""
	local key = build_scalp_cache_key(sheet, crop, size.X, size.Y)
	local cached = scalp_cache[key]
	if cached then
		scalp_stats.cache_hits = scalp_stats.cache_hits + 1
		return cached.y, cached.state
	end
	if sheet == "" then
		return nil, "unavailable"
	end

	local image = sprite and sprite.GetSpritesheet and sprite:GetSpritesheet(layer_id) or nil
	-- Outer with_helper_sheet_crop already pcall-wraps fn; do not pcall per texel.
	local found, samples, scan_err = with_helper_sheet_crop(
		production_head_helper,
		sheet,
		crop,
		function(helper)
			local start_x = size.X * 0.5
			local result = nil
			local sample_count = 0
			for y = 0, size.Y - 1 do
				sample_count = sample_count + 1
				local texel = helper:GetTexel(
					Vector(start_x, y),
					Vector.Zero,
					SCALP_ALPHA_THRESHOLD
				)
				if texel and (texel.Alpha or 0) > 0 then
					local sheet_pos = Vector(crop.X + start_x, crop.Y + y)
					local in_sheet = true
					if image and image.GetWidth and image.GetHeight then
						if sheet_pos.X < 0
							or sheet_pos.X >= image:GetWidth()
							or sheet_pos.Y < 0
							or sheet_pos.Y >= image:GetHeight()
						then
							in_sheet = false
						end
					end
					if in_sheet then
						result = y
						break
					end
				end
			end
			return result, sample_count
		end
	)

	if scan_err ~= nil or samples == nil then
		return nil, "unavailable"
	end

	scalp_stats.scans = scalp_stats.scans + 1
	scalp_stats.texel_samples = scalp_stats.texel_samples + (tonumber(samples) or 0)

	local state = found ~= nil and "hit" or "empty"
	if state == "hit" then
		scalp_stats.hit_scans = scalp_stats.hit_scans + 1
	else
		scalp_stats.empty_scans = scalp_stats.empty_scans + 1
	end
	scalp_cache[key] = { y = found, state = state }
	return found, state
end

--- Dev-only: peek production scalp_cache for the current layer crop (no scan).
function M.DebugPeekScalpCache(sprite, layer_id, from_overlay)
	local resolved, err = resolve_layer_crop_sheet(sprite, layer_id, from_overlay)
	if not resolved then
		return {
			cached = false,
			state = nil,
			y = nil,
			key = nil,
			error = err,
		}
	end
	if resolved.width < 2 or resolved.height < 2 then
		return {
			cached = false,
			state = nil,
			y = nil,
			key = nil,
			error = "bad_size",
		}
	end
	local size_x = math.min(resolved.width, 512)
	local size_y = math.min(resolved.height, 512)
	local key = build_scalp_cache_key(resolved.sheet, resolved.crop, size_x, size_y)
	local cached = scalp_cache[key]
	if cached then
		return {
			cached = true,
			state = cached.state,
			y = cached.y,
			key = key,
			crop = { resolved.crop.X, resolved.crop.Y },
			size = { size_x, size_y },
			sheet = resolved.sheet,
		}
	end
	return {
		cached = false,
		state = nil,
		y = nil,
		key = key,
		crop = { resolved.crop.X, resolved.crop.Y },
		size = { size_x, size_y },
		sheet = resolved.sheet,
	}
end

function M.DebugPeekScalpCacheForEntity(ent, options)
	options = options or {}
	if not ent then
		return { cached = false, error = "nil_ent" }
	end
	local sprite = ent.GetSprite and ent:GetSprite() or nil
	if not sprite then
		return { cached = false, error = "no_sprite" }
	end
	local layer_id, from_overlay = M.FindHeadLayer(sprite)
	if options.skipOverlay then
		from_overlay = false
	end
	if layer_id == nil then
		return { cached = false, error = "no_head_layer" }
	end
	return M.DebugPeekScalpCache(sprite, layer_id, from_overlay == true)
end

local function apply_sprite_transform(local_off, sprite)
	local spr_scale = sprite.Scale or Vector(1, 1)

	-- 1. Sprite scale
	local_off = Vector(
		local_off.X * spr_scale.X,
		local_off.Y * spr_scale.Y
	)

	-- 2. Sprite rotation
	local rotation = tonumber(sprite.Rotation) or 0
	if math.abs(rotation) > 0.001 then
		local_off = local_off:Rotated(rotation)
	end

	-- 3. Sprite mirror is applied in render space AFTER rotation.
	-- Rotation → Flip confirmed by Type 304 wall-state probe; do NOT restore
	-- the common "Flip then Rotation" math intuition.
	if sprite.FlipX then
		local_off = Vector(-local_off.X, local_off.Y)
	end
	if sprite.FlipY then
		local_off = Vector(local_off.X, -local_off.Y)
	end

	-- 4. Sprite render offset
	if sprite.Offset then
		local_off = local_off + sprite.Offset
	end

	return local_off
end

-- Some vanilla NPCs mirror the same visual rotation into Sprite.Rotation and
-- Entity.SpriteRotation. LocalOffsetFromFramePoint already applies Sprite.Rotation;
-- do not apply an equivalent Entity.SpriteRotation again.
local function effective_entity_extra_rotation(ent, sprite)
	local er = tonumber(ent and ent.SpriteRotation) or 0
	local sr = tonumber(sprite and sprite.Rotation) or 0
	local delta = math.abs(((er - sr + 180) % 360) - 180)
	if delta < 0.01 then
		return 0
	end
	return er
end

-- Full attachment rotation used by HeadPose / wearables (Sprite.Rotation + extra only).
local function get_attachment_rotation(ent, sprite)
	local sr = tonumber(sprite and sprite.Rotation) or 0
	return sr + effective_entity_extra_rotation(ent, sprite)
end

-- Entity-level render transform after Sprite/ANM2 local geometry.
-- Order: Sprite-local → effective Entity.SpriteRotation → Entity.SpriteOffset.
local function apply_entity_render_transform(ent, sprite, local_off)
	if not ent or not local_off then
		return local_off
	end
	local result = local_off
	local rotation = effective_entity_extra_rotation(ent, sprite)
	if math.abs(rotation) > 0.001 then
		result = result:Rotated(rotation)
	end
	if ent.SpriteOffset then
		result = result + ent.SpriteOffset
	end
	return result
end

local function transform_face_result(ent, sprite, face)
	if not face then
		return face
	end
	if face.center then
		face.center = apply_entity_render_transform(ent, sprite, face.center)
	end
	if face.top then
		face.top = apply_entity_render_transform(ent, sprite, face.top)
	end
	if face.bottom then
		face.bottom = apply_entity_render_transform(ent, sprite, face.bottom)
	end
	if face.rotation == nil then
		face.rotation = get_attachment_rotation(ent, sprite)
	end
	return face
end

-- Derive wearable rotation from two scalp-axis frame points (includes Flip/Scale/ANM2).
local function rotation_from_scalp_axis(ent, sprite, info)
	if not (info and info.source == "head_layer" and sprite and info.layer_id) then
		return nil
	end
	if info.scalp_y == nil or info.visual_present == false then
		return nil
	end
	local cx = (info.width or 0) * 0.5
	local scalp = info.scalp_y
	local p0 = M.LocalOffsetFromFramePoint(sprite, info.layer_id, info.from_overlay, cx, scalp)
	local p1 = M.LocalOffsetFromFramePoint(sprite, info.layer_id, info.from_overlay, cx, scalp + 1)
	if not p0 or not p1 then
		return nil
	end
	local down = p1 - p0
	local extra = effective_entity_extra_rotation(ent, sprite)
	if math.abs(extra) > 0.001 then
		down = down:Rotated(extra)
	end
	if down:Length() <= 1e-6 then
		return nil
	end
	-- Isaac: GetAngleDegrees 0 = +X, 90 = +Y (screen down). Upright head → down≈(0,1) → 0°.
	return down:GetAngleDegrees() - 90
end

-- 帧像素点 (fx, fy)：相对帧裁剪左上；(0,0)=帧顶左。返回 Sprite 局部偏移。
function M.LocalOffsetFromFramePoint(sprite, layer_id, from_overlay, fx, fy)
	if not sprite or not layer_id or not sprite.GetLayerFrameData then return nil end
	local frame_data
	if from_overlay and sprite.GetOverlayLayerFrameData then
		frame_data = sprite:GetOverlayLayerFrameData(layer_id)
	else
		frame_data = sprite:GetLayerFrameData(layer_id)
	end
	local layer_state = sprite:GetLayer(layer_id)
	if not frame_data or not layer_state then return nil end

	local scale_multi = frame_data:GetScale()
	if layer_state.GetSize then
		scale_multi = scale_multi * layer_state:GetSize()
	end
	local rotation = frame_data:GetRotation()
	if layer_state.GetRotation then
		rotation = rotation + layer_state:GetRotation()
	end
	local base = frame_data:GetPos()
	if layer_state.GetPos then
		base = base + layer_state:GetPos()
	end
	local pivot = (frame_data:GetPivot() * scale_multi):Rotated(rotation)
	local point = Vector(fx * scale_multi.X, fy * scale_multi.Y):Rotated(rotation)
	return apply_sprite_transform(base - pivot + point, sprite)
end

local function overlay_fallback(ent, options)
	local y_mul = (options and options.overlayYMul) or 1
	if ent.GetNullOffset then
		local ov = ent:GetNullOffset("OverlayEffect")
		if ov and ov:Length() > 0.5 then
			return Vector(ov.X, ov.Y * y_mul)
		end
	end
	local spr = ent:GetSprite()
	if spr and spr.GetNullFrame then
		local nf = spr:GetNullFrame("OverlayEffect")
		if nf and nf.IsVisible and nf:IsVisible() and nf.GetPos then
			local p = nf:GetPos()
			if p and p:Length() > 0.5 then
				return Vector(p.X, p.Y * y_mul)
			end
		end
	end
	return nil
end

local function size_fallback(ent, paddingY)
	return Vector(0, -(size_radius(ent) + 16 + (paddingY or 0)))
end

local function empty_size_info()
	return {
		sprite = nil,
		width = 26,
		height = 26,
		scalp_y = 0,
		source = "size",
		scalp_scan_state = "unavailable",
		visual_present = true,
	}
end

--- 当前头层 / overlay / size 几何快照。Consumer 不要自己 FindHeadLayer + ScanScalpY。
--- options: lockData, useTexel, skipOverlay, overlayYMul
--- scalp_scan_state:
---   hit         → real scalp_y, visual_present=true
---   empty       → scan ok but no center-line alpha; scalp_y=nil, visual_present=false
---   unavailable → scan could not run; height*0.15 fallback, visual_present=true
function M.GetEntityHeadFrameInfo(ent, options)
	options = options or {}
	if not ent then
		return empty_size_info()
	end
	local sprite = ent.GetSprite and ent:GetSprite() or nil
	local skip_overlay = options.skipOverlay == true
	local use_texel = options.useTexel ~= false

	if sprite and sprite.GetLayerCount then
		local layer_id, from_overlay = M.FindHeadLayer(sprite)
		if options.lockData then
			layer_id, from_overlay = M.LockHeadLayer(options.lockData, layer_id, from_overlay)
		end
		if layer_id and sprite.GetLayerFrameData then
			local frame_data
			if from_overlay and sprite.GetOverlayLayerFrameData then
				frame_data = sprite:GetOverlayLayerFrameData(layer_id)
			else
				frame_data = sprite:GetLayerFrameData(layer_id)
			end
			local layer_state = sprite.GetLayer and sprite:GetLayer(layer_id) or nil
			if frame_data and layer_state then
				local width = frame_data:GetWidth()
				local height = frame_data:GetHeight()
				local scalp = nil
				local scalp_scan_state = "unavailable"
				if use_texel then
					scalp, scalp_scan_state = M.ScanScalpY(sprite, layer_id, frame_data, layer_state)
				end
				if scalp_scan_state == "empty" then
					-- Successful scan, no mountable head surface. Do NOT invent scalp_y.
					return {
						sprite = sprite,
						layer_id = layer_id,
						from_overlay = from_overlay,
						frame_data = frame_data,
						layer_state = layer_state,
						width = width,
						height = height,
						scalp_y = nil,
						scalp_scan_state = "empty",
						visual_present = false,
						hidden_reason = "empty_scalp_scan",
						source = "head_layer",
					}
				end
				if scalp_scan_state == "unavailable" then
					scalp = height * 0.15
				end
				return {
					sprite = sprite,
					layer_id = layer_id,
					from_overlay = from_overlay,
					frame_data = frame_data,
					layer_state = layer_state,
					width = width,
					height = height,
					scalp_y = scalp,
					scalp_scan_state = scalp_scan_state,
					visual_present = true,
					source = "head_layer",
				}
			end
		end
	end

	if not skip_overlay then
		local ov = overlay_fallback(ent, options)
		if ov then
			local r = size_radius(ent)
			return {
				sprite = sprite,
				overlay_offset = ov,
				width = r * 2,
				height = r * 2,
				scalp_y = 0,
				scalp_scan_state = "unavailable",
				visual_present = true,
				source = "overlay",
			}
		end
	end

	local r = size_radius(ent)
	return {
		sprite = sprite,
		width = r * 2,
		height = r * 2,
		scalp_y = 0,
		scalp_scan_state = "unavailable",
		visual_present = true,
		source = "size",
	}
end

local function face_from_overlay_offset(ov, info, top_ratio, bottom_ratio, width_ratio, rotation)
	local visible = math.max(12, math.abs(ov.Y) * 0.9)
	local top = Vector(ov.X, ov.Y + visible * top_ratio)
	local bottom = Vector(ov.X, ov.Y + visible * bottom_ratio)
	local center = Vector(ov.X, (top.Y + bottom.Y) * 0.5)
	local height = math.abs(bottom.Y - top.Y)
	local width = math.max((info.width or 26) * width_ratio, height * 0.9)
	return {
		center = center,
		width = width,
		height = height,
		top = top,
		bottom = bottom,
		rotation = rotation,
		source = "overlay",
	}
end

local function face_from_size(ent, info, top_ratio, bottom_ratio, width_ratio, rotation)
	local r = math.max(8, ((info and info.width) or (size_radius(ent) * 2) or 26) * 0.5)
	local scalp = Vector(0, -(r + 16))
	local visible = r * 1.1
	local top = Vector(0, scalp.Y + visible * top_ratio)
	local bottom = Vector(0, scalp.Y + visible * bottom_ratio)
	local center = Vector(0, (top.Y + bottom.Y) * 0.5)
	local height = math.abs(bottom.Y - top.Y)
	return {
		center = center,
		width = math.max(r * 2 * width_ratio, height * 0.9),
		height = height,
		top = top,
		bottom = bottom,
		rotation = rotation,
		source = "size",
	}
end

--- 脸部矩形（Sprite-local render geometry，不是 screen/world）。
--- OverlayEffect 只用于估算，不当作 face top。
--- options: lockData, faceTopRatio, faceBottomRatio, faceWidthRatio, useTexel
function M.GetEntityFaceAnchor(ent, options)
	options = options or {}
	local top_ratio = options.faceTopRatio or FACE_TOP_RATIO
	local bottom_ratio = options.faceBottomRatio or FACE_BOTTOM_RATIO
	local width_ratio = options.faceWidthRatio or FACE_WIDTH_RATIO
	if not ent then
		return face_from_size(nil, empty_size_info(), top_ratio, bottom_ratio, width_ratio, 0)
	end

	local info = M.GetEntityHeadFrameInfo(ent, options)
	if info.visual_present == false then
		return nil
	end
	local sprite = info.sprite
	local rotation = get_attachment_rotation(ent, sprite)

	if info.source == "head_layer" and info.frame_data and sprite and info.layer_id then
		local w = info.width
		local h = info.height
		local scalp = info.scalp_y
		if scalp == nil then
			return nil
		end
		local visible = math.max(1, h - scalp)
		local face_top_y = scalp + visible * top_ratio
		local face_bottom_y = scalp + visible * bottom_ratio
		local face_center_y = (face_top_y + face_bottom_y) * 0.5
		local cx = w * 0.5
		local half_w = w * width_ratio * 0.5
		local top = M.LocalOffsetFromFramePoint(sprite, info.layer_id, info.from_overlay, cx, face_top_y)
		local bottom = M.LocalOffsetFromFramePoint(sprite, info.layer_id, info.from_overlay, cx, face_bottom_y)
		local center = M.LocalOffsetFromFramePoint(sprite, info.layer_id, info.from_overlay, cx, face_center_y)
		local left = M.LocalOffsetFromFramePoint(sprite, info.layer_id, info.from_overlay, cx - half_w, face_center_y)
		local right = M.LocalOffsetFromFramePoint(sprite, info.layer_id, info.from_overlay, cx + half_w, face_center_y)
		if top and bottom and center then
			local face_w = w * width_ratio
			if left and right then
				face_w = (right - left):Length()
			end
			local axis_rot = rotation_from_scalp_axis(ent, sprite, info)
			return transform_face_result(ent, sprite, {
				center = center,
				width = face_w,
				height = (bottom - top):Length(),
				top = top,
				bottom = bottom,
				rotation = axis_rot or rotation,
				source = "head_layer",
			})
		end
	end

	local ov = info.overlay_offset
	if not ov then
		ov = overlay_fallback(ent, options)
	end
	if ov then
		return transform_face_result(ent, sprite, face_from_overlay_offset(ov, info, top_ratio, bottom_ratio, width_ratio, rotation))
	end
	return transform_face_result(ent, sprite, face_from_size(ent, info, top_ratio, bottom_ratio, width_ratio, rotation))
end

--- 返回 Sprite 局部 render offset（头顶中轴）。
--- options:
---   top (default true)      用顶部 texel；false 时用帧高中点
---   centerX (default true)  X 用帧宽中轴
---   paddingY (default 0)    头顶再向上抬的像素（渲染局部）
---   lockData                可选，用于跨帧锁定头层（Gospel 光环）
---   overlayYMul             Overlay 回退时的 Y 倍率
---   useTexel (default true) 关闭则只用 crop 顶估
function M.GetEntityHeadAnchor(ent, options)
	options = options or {}
	local paddingY = options.paddingY or 0
	local use_top = options.top ~= false
	local center_x = options.centerX ~= false

	if not ent then
		return Vector(0, -(16 + paddingY))
	end

	local info = M.GetEntityHeadFrameInfo(ent, options)
	if info.visual_present == false then
		return nil
	end
	local sprite = info.sprite
	if info.source == "head_layer" and sprite and info.layer_id then
		local fx = center_x and (info.width * 0.5) or 0
		local fy
		if use_top then
			fy = info.scalp_y
			if fy == nil then
				return nil
			end
		else
			fy = info.height * 0.5
		end
		local local_off = M.LocalOffsetFromFramePoint(
			sprite, info.layer_id, info.from_overlay, fx, fy
		)
		if local_off then
			return apply_entity_render_transform(ent, sprite, local_off + Vector(0, -paddingY))
		end
	end

	local ov = info.overlay_offset or overlay_fallback(ent, options)
	if ov then
		return apply_entity_render_transform(ent, sprite, ov + Vector(0, -paddingY))
	end
	return apply_entity_render_transform(ent, sprite, size_fallback(ent, paddingY))
end

--- Head attachment pose: position + wearable rotation (same transform stack as HeadAnchor).
--- Wearable consumers must use this instead of combining Sprite.Rotation + Entity.SpriteRotation.
--- Visibility gates (both required):
---   Layer 1: GetEntityRenderVisibility (Visible / IsVisible)
---   Layer 2: head-surface — empty scalp → visible=false (no transform / no fake position)
--- unavailable still allows height*0.15 geometry fallback.
function M.GetEntityHeadPose(ent, options)
	options = options or {}
	local paddingY = options.paddingY or 0
	if not ent then
		return {
			visible = true,
			hidden_reason = nil,
			position = Vector(0, -(16 + paddingY)),
			rotation = 0,
			field_rotation = 0,
			flip_x = false,
			flip_y = false,
			source = "size",
			layer_id = nil,
			rotation_source = "fallback",
			scalp_scan_state = "unavailable",
		}
	end

	local render_visible, hide_reason = M.GetEntityRenderVisibility(ent)
	if not render_visible then
		local sprite = ent.GetSprite and ent:GetSprite() or nil
		return {
			visible = false,
			hidden_reason = hide_reason,
			position = nil,
			rotation = nil,
			field_rotation = nil,
			flip_x = sprite and sprite.FlipX == true or false,
			flip_y = sprite and sprite.FlipY == true or false,
			source = nil,
			layer_id = nil,
			from_overlay = nil,
			rotation_source = nil,
			scalp_scan_state = nil,
		}
	end

	local info = M.GetEntityHeadFrameInfo(ent, options)
	if info.visual_present == false then
		local sprite = info.sprite
		return {
			visible = false,
			hidden_reason = info.hidden_reason or "empty_scalp_scan",
			position = nil,
			rotation = nil,
			field_rotation = nil,
			flip_x = sprite and sprite.FlipX == true or false,
			flip_y = sprite and sprite.FlipY == true or false,
			source = info.source,
			layer_id = info.layer_id,
			from_overlay = info.from_overlay,
			rotation_source = nil,
			scalp_scan_state = info.scalp_scan_state or "empty",
		}
	end

	local sprite = info.sprite
	local flip_x = sprite and sprite.FlipX == true or false
	local flip_y = sprite and sprite.FlipY == true or false
	local position = M.GetEntityHeadAnchor(ent, options)
	if not position then
		return {
			visible = false,
			hidden_reason = "no_head_anchor",
			position = nil,
			rotation = nil,
			field_rotation = nil,
			flip_x = flip_x,
			flip_y = flip_y,
			source = info.source,
			layer_id = info.layer_id,
			from_overlay = info.from_overlay,
			rotation_source = nil,
			scalp_scan_state = info.scalp_scan_state or "unavailable",
		}
	end
	local field_rotation = get_attachment_rotation(ent, sprite)
	local axis_rot = rotation_from_scalp_axis(ent, sprite, info)
	local rotation_source = "scalp_axis"
	local rotation = axis_rot
	if rotation == nil then
		rotation = field_rotation
		rotation_source = "fields"
	end

	return {
		visible = true,
		hidden_reason = nil,
		position = position,
		-- Formal attachment pose (scalp-axis preferred).
		rotation = rotation,
		-- Debug/reference: Sprite.Rotation + effective entity extra only.
		field_rotation = field_rotation,
		flip_x = flip_x,
		flip_y = flip_y,
		source = info.source,
		layer_id = info.layer_id,
		from_overlay = info.from_overlay,
		rotation_source = rotation_source,
		scalp_scan_state = info.scalp_scan_state or "unavailable",
	}
end

--- Gospel 光环：在头皮下方一段，仍用同一套头层几何。
--- empty scalp → nil（无挂载面，不造假位置）。
--- 无头层 / unavailable 时保持原 Size 回退（不用 OverlayEffect 冒充光环位置）。
function M.GetEntityHeadHaloAnchor(ent, lockData)
	if not ent then return Vector(0, -10) end
	local sprite = ent.GetSprite and ent:GetSprite() or nil
	if not sprite or not sprite.GetLayerCount then
		return apply_entity_render_transform(ent, sprite, Vector(0, -(size_radius(ent) * 0.55)))
	end
	local info = M.GetEntityHeadFrameInfo(ent, { lockData = lockData, skipOverlay = true })
	if info.visual_present == false then
		return nil
	end
	sprite = info.sprite or sprite
	if info.source == "head_layer" and info.frame_data and info.scalp_y ~= nil then
		local remain = math.max(0, info.height - info.scalp_y)
		local halo_y = info.scalp_y + math.min(remain * 0.38, math.max(8, info.height * 0.22))
		local local_off = M.LocalOffsetFromFramePoint(
			info.sprite, info.layer_id, info.from_overlay, info.width * 0.5, halo_y
		)
		if local_off then
			return apply_entity_render_transform(ent, sprite, local_off)
		end
	end
	return apply_entity_render_transform(ent, sprite, Vector(0, -(size_radius(ent) * 0.55 + 12)))
end

--- Dev-only: decompose head local transform into intermediate points + entity-order candidates.
--- Does not change gameplay math; probe/UI may call this freely.
--- options: same as GetEntityHeadAnchor (paddingY / top / centerX / lockData / …)
function M.DebugGetHeadTransform(ent, options)
	options = options or {}
	local paddingY = options.paddingY or 0
	local use_top = options.top ~= false
	local center_x = options.centerX ~= false
	local out = {
		ok = false,
		source = nil,
		error = nil,
		entity_rotation = 0,
		entity_sprite_offset = Vector.Zero,
		padding_y = paddingY,
	}
	if not ent then
		out.error = "nil_ent"
		return out
	end

	local entity_rot = tonumber(ent.SpriteRotation) or 0
	local entity_so = ent.SpriteOffset or Vector.Zero
	out.entity_rotation = entity_rot
	out.entity_sprite_offset = entity_so

	local info = M.GetEntityHeadFrameInfo(ent, options)
	local sprite_for_extra = info and info.sprite or nil
	local effective_extra = effective_entity_extra_rotation(ent, sprite_for_extra)
	out.effective_entity_extra_rotation = effective_extra
	out.attachment_rotation = get_attachment_rotation(ent, sprite_for_extra)
	out.source = info and info.source or nil
	local render_visible, render_reason = M.GetEntityRenderVisibility(ent)
	out.info = {
		source = info and info.source or nil,
		layer_id = info and info.layer_id or nil,
		from_overlay = info and info.from_overlay or false,
		width = info and info.width or nil,
		height = info and info.height or nil,
		scalp_y = info and info.scalp_y or nil,
		scalp_scan_state = info and info.scalp_scan_state or nil,
		render_visible = render_visible,
		render_visibility_reason = render_reason,
	}
	out.info.visual_present = info and info.visual_present
	out.info.hidden_reason = info and info.hidden_reason or nil
	out.scalp_scan_state = out.info.scalp_scan_state
	out.render_visible = render_visible
	out.render_visibility_reason = render_reason
	-- Compat: head surface present only when entity is render-visible AND scalp not empty.
	out.head_visual_present = render_visible and (not info or info.visual_present ~= false)

	if info and info.visual_present == false then
		out.error = info.hidden_reason or "empty_scalp_scan"
		out.ok = false
		return out
	end

	local function safe_call(fn)
		local ok, a, b, c = pcall(fn)
		if ok then return a, b, c end
		return nil
	end

	local layer_name = nil
	local frame_pos, frame_pivot, frame_scale, frame_rot = nil, nil, nil, nil
	local layer_pos, layer_size, layer_rot, crop_offset = nil, nil, nil, nil
	local sprite = info and info.sprite or nil
	local frame_data = info and info.frame_data or nil
	local layer_state = info and info.layer_state or nil

	if layer_state then
		if layer_state.GetName then
			layer_name = safe_call(function() return layer_state:GetName() end)
		end
		if layer_state.GetPos then
			layer_pos = safe_call(function() return layer_state:GetPos() end)
		end
		if layer_state.GetSize then
			layer_size = safe_call(function() return layer_state:GetSize() end)
		end
		if layer_state.GetRotation then
			layer_rot = safe_call(function() return layer_state:GetRotation() end)
		end
		if layer_state.GetCropOffset then
			crop_offset = safe_call(function() return layer_state:GetCropOffset() end)
		end
	end
	out.info.layer_name = layer_name

	if frame_data then
		frame_pos = safe_call(function() return frame_data:GetPos() end)
		frame_pivot = safe_call(function() return frame_data:GetPivot() end)
		frame_scale = safe_call(function() return frame_data:GetScale() end)
		frame_rot = safe_call(function() return frame_data:GetRotation() end)
	end
	out.frame = {
		pos = frame_pos,
		pivot = frame_pivot,
		scale = frame_scale,
		rotation = frame_rot,
	}
	out.layer = {
		pos = layer_pos,
		size = layer_size,
		rotation = layer_rot,
		crop_offset = crop_offset,
	}

	local official_final = M.GetEntityHeadAnchor(ent, options)
	out.current_final = official_final
	out.official_anchor = official_final

	if not (info and info.source == "head_layer" and sprite and info.layer_id and frame_data and layer_state) then
		out.error = "no_head_layer"
		out.ok = official_final ~= nil
		return out
	end

	local fx = center_x and ((info.width or 0) * 0.5) or 0
	local fy
	if use_top then
		fy = info.scalp_y or 0
	else
		fy = (info.height or 0) * 0.5
	end
	out.raw_point = Vector(fx, fy)

	local scale_multi = frame_scale or Vector(1, 1)
	if layer_size then
		scale_multi = scale_multi * layer_size
	end
	local total_frame_rot = (tonumber(frame_rot) or 0) + (tonumber(layer_rot) or 0)

	local raw = Vector(fx, fy)
	local frame_scaled = Vector(fx * scale_multi.X, fy * scale_multi.Y)
	local frame_rotated = frame_scaled:Rotated(total_frame_rot)
	local base = frame_pos or Vector.Zero
	if layer_pos then
		base = base + layer_pos
	end
	local pivot = ((frame_pivot or Vector.Zero) * scale_multi):Rotated(total_frame_rot)
	local frame_local = base - pivot + frame_rotated

	out.raw = raw
	out.frame_scaled = frame_scaled
	out.frame_rotated = frame_rotated
	out.frame_local = frame_local
	out.scale_multi = scale_multi
	out.total_frame_rot = total_frame_rot

	local spr_scale = sprite.Scale or Vector(1, 1)
	local sprite_scaled = Vector(frame_local.X * spr_scale.X, frame_local.Y * spr_scale.Y)

	-- Match formal apply_sprite_transform: Scale → Rotation → Flip → Offset.
	local spr_rot = tonumber(sprite.Rotation) or 0
	local sprite_rotated = sprite_scaled
	if math.abs(spr_rot) > 0.001 then
		sprite_rotated = sprite_rotated:Rotated(spr_rot)
	end

	local sprite_flipped = Vector(sprite_rotated.X, sprite_rotated.Y)
	if sprite.FlipX then
		sprite_flipped = Vector(-sprite_flipped.X, sprite_flipped.Y)
	end
	if sprite.FlipY then
		sprite_flipped = Vector(sprite_flipped.X, -sprite_flipped.Y)
	end

	local sprite_internal_offset = sprite.Offset or Vector.Zero
	local sprite_offset_applied = sprite_flipped + sprite_internal_offset

	out.sprite_scaled = sprite_scaled
	out.sprite_rotated = sprite_rotated
	out.sprite_flipped = sprite_flipped
	out.sprite_offset_internal = sprite_internal_offset
	out.sprite_offset_applied = sprite_offset_applied

	local official_local = M.LocalOffsetFromFramePoint(
		sprite, info.layer_id, info.from_overlay, fx, fy
	)
	out.official_local = official_local
	if official_local then
		out.delta_local = sprite_offset_applied - official_local
	end

	-- padding applied before entity transform (matches GetEntityHeadAnchor)
	local pad = Vector(0, -paddingY)
	local p7 = sprite_offset_applied
	local p7p = p7 + pad
	-- Geometry after Rotation+Flip, before Sprite.Offset.
	local p6 = sprite_flipped
	local p6p = p6 + pad

	-- Legacy entity-order candidates (kept for old logs).
	local cand_a = p7p:Rotated(effective_extra) + entity_so
	local cand_b = (p7p + entity_so):Rotated(entity_rot)
	local cand_c = p6p:Rotated(entity_rot) + sprite_internal_offset + entity_so
	local cand_d = (p6p + sprite_internal_offset + entity_so):Rotated(entity_rot)
	local cand_e = p7p + entity_so

	out.candidates = {
		A = cand_a,
		B = cand_b,
		C = cand_c,
		D = cand_d,
		E = cand_e,
	}
	out.candidates_unpadded = {
		A = p7:Rotated(effective_extra) + entity_so,
		B = (p7 + entity_so):Rotated(entity_rot),
		C = p6:Rotated(entity_rot) + sprite_internal_offset + entity_so,
		D = (p6 + sprite_internal_offset + entity_so):Rotated(entity_rot),
		E = p7 + entity_so,
	}

	-- Sprite order references: RF = formal contract; FR = legacy_wrong (Flip→Rot).
	local function frame_point_local(px, py)
		local pt = Vector(px * scale_multi.X, py * scale_multi.Y):Rotated(total_frame_rot)
		return base - pivot + pt
	end

	local function apply_flip_xy(v, flip_x, flip_y)
		if flip_x then
			v = Vector(-v.X, v.Y)
		end
		if flip_y then
			v = Vector(v.X, -v.Y)
		end
		return v
	end

	local function sprite_order_local(frame_pt, order_name)
		local scaled = Vector(frame_pt.X * spr_scale.X, frame_pt.Y * spr_scale.Y)
		local flip_x = sprite.FlipX == true
		local flip_y = sprite.FlipY == true
		local v = scaled
		if order_name == "FR" then
			-- legacy_wrong
			v = apply_flip_xy(v, flip_x, flip_y)
			if math.abs(spr_rot) > 0.001 then
				v = v:Rotated(spr_rot)
			end
		elseif order_name == "RF" then
			-- formal / expected
			if math.abs(spr_rot) > 0.001 then
				v = v:Rotated(spr_rot)
			end
			v = apply_flip_xy(v, flip_x, flip_y)
		elseif order_name == "R" then
			if math.abs(spr_rot) > 0.001 then
				v = v:Rotated(spr_rot)
			end
		elseif order_name == "F" then
			v = apply_flip_xy(v, flip_x, flip_y)
		end
		return v + sprite_internal_offset
	end

	local function apply_entity_stage(v)
		local result = v
		if math.abs(effective_extra) > 0.001 then
			result = result:Rotated(effective_extra)
		end
		return result + entity_so
	end

	local function pack_order_candidate(order_name, head_frame, body_frame)
		local head_sprite = sprite_order_local(head_frame, order_name) + pad
		local body_sprite = sprite_order_local(body_frame, order_name) + pad
		local head_ent = apply_entity_stage(head_sprite)
		local body_ent = apply_entity_stage(body_sprite)
		local down = body_ent - head_ent
		local rot = 0
		if down:Length() > 1e-6 then
			rot = down:GetAngleDegrees() - 90
		end
		return {
			sprite_local = head_sprite,
			after_entity = head_ent,
			head = head_ent,
			body = body_ent,
			down = down,
			rotation = rot,
		}
	end

	local head_frame = frame_local
	local body_frame = frame_point_local(fx, fy + 6)
	out.sprite_order_test = {
		input = {
			frame_local = frame_local,
			body_frame_local = body_frame,
			sprite_rotation = spr_rot,
			flip_x = sprite.FlipX == true,
			flip_y = sprite.FlipY == true,
			sprite_offset = sprite_internal_offset,
			sprite_scale = spr_scale,
			effective_entity_extra = effective_extra,
			padding_y = paddingY,
		},
		-- RF should match official after this fix; FR is regression contrast.
		RF = pack_order_candidate("RF", head_frame, body_frame),
		FR = pack_order_candidate("FR", head_frame, body_frame),
		R = pack_order_candidate("R", head_frame, body_frame),
		F = pack_order_candidate("F", head_frame, body_frame),
		legacy_wrong_FR = true,
		expected_order = "RF",
	}

	local pose = M.GetEntityHeadPose(ent, options)
	out.pose_rotation = pose and pose.rotation or nil
	out.pose_rotation_source = pose and pose.rotation_source or nil
	out.pose_position = pose and pose.position or nil

	out.ok = true
	return out
end

--- Attachment / render visibility for the current entity (segment-local).
--- Cheap visual signals only: Visible / IsVisible.
--- Never uses OverlayEffect, IsVulnerableEnemy, EntityCollisionClass, scalp, or State.
--- Returns: visible, reason
function M.GetEntityRenderVisibility(ent)
	if not ent then
		return false, "nil"
	end

	if ent.Visible == false then
		return false, "visible_field"
	end

	if ent.IsVisible then
		local ok, vis = pcall(function()
			return ent:IsVisible()
		end)
		if ok and vis == false then
			return false, "is_visible_api"
		end
	end

	return true, "visible"
end

--- Compatibility alias: render-only. No vulnerability/collision semantics.
function M.IsEntityTemporarilyHidden(ent)
	local visible = M.GetEntityRenderVisibility(ent)
	return not visible
end

-- Dev-only full-crop alpha presence (probe). Not a formal visibility owner.
-- Uses debug_head_helper only — never touches production_head_helper.
local frame_presence_debug_cache = {}

local function texel_alpha(texel)
	if not texel then
		return 0
	end
	return tonumber(texel.Alpha) or tonumber(texel.A) or 0
end

--- Dev-only: full-scan one layer's current frame crop for any opaque texel.
--- Probe only. Do not call from formal consumers / hide rules.
function M.DebugAnalyzeLayerCropPresence(sprite, layer_id, from_overlay, options)
	options = options or {}
	local threshold = tonumber(options.alphaThreshold) or 0.1
	local out = {
		available = false,
		nontransparent = false,
		alpha_pixels = 0,
		sample_pixels = 0,
		coverage = 0,
		layer_id = layer_id,
		layer_name = nil,
		sheet = nil,
		crop = nil,
		width = nil,
		height = nil,
		cached = false,
		from_overlay = from_overlay == true,
		error = nil,
	}
	if not sprite or layer_id == nil then
		out.error = "bad_args"
		return out
	end
	if not debug_head_helper.GetTexel then
		out.error = "get_texel_unavailable"
		return out
	end

	local resolved, err = resolve_layer_crop_sheet(sprite, layer_id, from_overlay)
	if not resolved then
		out.error = err or "no_frame"
		return out
	end

	local width = resolved.width
	local height = resolved.height
	local crop = resolved.crop
	local sheet = resolved.sheet
	local layer_state = resolved.layer_state
	out.width = width
	out.height = height
	if layer_state.GetName then
		local ok_name, name = pcall(function()
			return layer_state:GetName()
		end)
		if ok_name then
			out.layer_name = name
		end
	end
	out.crop = { x = crop.X, y = crop.Y, w = width, h = height }
	if width < 1 or height < 1 then
		out.error = "bad_size"
		return out
	end
	out.sheet = sheet
	if sheet == "" then
		out.error = "empty_sheet"
		return out
	end

	local key = sheet
		.. "|"
		.. tostring(crop.X)
		.. "|"
		.. tostring(crop.Y)
		.. "|"
		.. tostring(width)
		.. "|"
		.. tostring(height)
		.. "|"
		.. tostring(threshold)
	local cached = frame_presence_debug_cache[key]
	if cached then
		out.available = true
		out.nontransparent = cached.nontransparent
		out.alpha_pixels = cached.alpha_pixels
		out.sample_pixels = cached.sample_pixels
		out.coverage = cached.coverage
		out.cached = true
		return out
	end

	local image = sprite.GetSpritesheet and sprite:GetSpritesheet(layer_id) or nil
	local alpha_pixels, sample_pixels = with_helper_sheet_crop(
		debug_head_helper,
		sheet,
		crop,
		function(helper)
			local a_pixels = 0
			local s_pixels = 0
			for y = 0, height - 1 do
				for x = 0, width - 1 do
					s_pixels = s_pixels + 1
					local sample = Vector(x, y)
					local ok, texel = pcall(function()
						return helper:GetTexel(sample, Vector.Zero, threshold)
					end)
					if ok and texel and texel_alpha(texel) > threshold then
						local sheet_pos = Vector(crop.X + x, crop.Y + y)
						local in_sheet = true
						if image and image.GetWidth and image.GetHeight then
							if sheet_pos.X < 0
								or sheet_pos.X >= image:GetWidth()
								or sheet_pos.Y < 0
								or sheet_pos.Y >= image:GetHeight()
							then
								in_sheet = false
							end
						end
						if in_sheet then
							a_pixels = a_pixels + 1
						end
					end
				end
			end
			return a_pixels, s_pixels
		end
	)

	if alpha_pixels == nil then
		out.error = "scan_failed"
		return out
	end

	local coverage = sample_pixels > 0 and (alpha_pixels / sample_pixels) or 0
	local nontransparent = alpha_pixels > 0
	frame_presence_debug_cache[key] = {
		nontransparent = nontransparent,
		alpha_pixels = alpha_pixels,
		sample_pixels = sample_pixels,
		coverage = coverage,
	}
	out.available = true
	out.nontransparent = nontransparent
	out.alpha_pixels = alpha_pixels
	out.sample_pixels = sample_pixels
	out.coverage = coverage
	out.cached = false
	return out
end

local function scan_center_column_on_helper(helper, crop, width, height, use_absolute, threshold)
	local result = {
		hit = false,
		first_y = nil,
		max_alpha = 0,
		nonzero_count = 0,
		sample_count = 0,
		use_absolute = use_absolute == true,
	}
	local start_x = width * 0.5
	for y = 0, height - 1 do
		result.sample_count = result.sample_count + 1
		local local_x = start_x
		local local_y = y
		local sample
		if use_absolute then
			sample = Vector(crop.X + local_x, crop.Y + local_y)
		else
			sample = Vector(local_x, local_y)
		end
		local ok, texel = pcall(function()
			return helper:GetTexel(sample, Vector.Zero, threshold)
		end)
		local alpha = 0
		if ok then
			alpha = texel_alpha(texel)
		end
		if alpha > result.max_alpha then
			result.max_alpha = alpha
		end
		if alpha > threshold then
			result.nonzero_count = result.nonzero_count + 1
			if not result.hit then
				result.hit = true
				result.first_y = y
			end
		end
	end
	return result
end

--- Dev-only: compare GetTexel SamplePos semantics vs LayerState:SetCropOffset.
--- Uses debug_head_helper only. Does not mutate production_head_helper.
--- Modes:
---   A local_with_crop_offset     = SetCropOffset(crop) + GetTexel(local)     [production]
---   B absolute_with_crop_offset  = SetCropOffset(crop) + GetTexel(crop+local)
---   C absolute_without_crop_offset = SetCropOffset(0) + GetTexel(crop+local)
function M.DebugAnalyzeTexelCoordinateSemantics(sprite, layer_id, from_overlay, options)
	options = options or {}
	local threshold = tonumber(options.alphaThreshold) or 0.1
	local out = {
		available = false,
		layer_id = layer_id,
		layer_name = nil,
		sheet = nil,
		crop = nil,
		size = nil,
		animation = nil,
		sprite_frame = nil,
		production_scalp_scan_state = nil,
		production_scalp_y = nil,
		texel_modes = nil,
		error = nil,
	}
	if not sprite or layer_id == nil then
		out.error = "bad_args"
		return out
	end
	if not debug_head_helper.GetTexel then
		out.error = "get_texel_unavailable"
		return out
	end

	local resolved, err = resolve_layer_crop_sheet(sprite, layer_id, from_overlay)
	if not resolved then
		out.error = err or "no_frame"
		return out
	end

	local width = resolved.width
	local height = resolved.height
	local crop = resolved.crop
	local sheet = resolved.sheet
	local layer_state = resolved.layer_state
	local frame_data = resolved.frame_data
	out.size = { width, height }
	if layer_state.GetName then
		local ok_name, name = pcall(function()
			return layer_state:GetName()
		end)
		if ok_name then
			out.layer_name = name
		end
	end
	do
		local ok_a, anim = pcall(function()
			return sprite:GetAnimation()
		end)
		if ok_a then
			out.animation = anim
		end
		local ok_f, frame = pcall(function()
			return sprite:GetFrame()
		end)
		if ok_f then
			out.sprite_frame = frame
		end
	end
	out.crop = { crop.X, crop.Y }
	if width < 1 or height < 1 then
		out.error = "bad_size"
		return out
	end
	out.sheet = sheet
	if sheet == "" then
		out.error = "empty_sheet"
		return out
	end

	-- Production ScanScalpY (hit-only cache) for the same crop.
	local scalp_y, scalp_state = M.ScanScalpY(sprite, layer_id, frame_data, layer_state)
	out.production_scalp_y = scalp_y
	out.production_scalp_scan_state = scalp_state or "unavailable"

	local modes = {}
	local function run_mode(name, crop_offset, use_absolute)
		local result = with_helper_sheet_crop(
			debug_head_helper,
			sheet,
			crop_offset,
			function(helper)
				return scan_center_column_on_helper(
					helper, crop, width, height, use_absolute, threshold
				)
			end
		)
		if result then
			result.crop_offset = { x = crop_offset.X, y = crop_offset.Y }
		else
			result = {
				hit = false,
				error = "scan_failed",
				crop_offset = { x = crop_offset.X, y = crop_offset.Y },
				use_absolute = use_absolute == true,
			}
		end
		modes[name] = result
	end

	run_mode("local_with_crop_offset", crop, false)
	run_mode("absolute_with_crop_offset", crop, true)
	run_mode("absolute_without_crop_offset", Vector.Zero, true)

	out.texel_modes = modes
	out.available = true
	return out
end

--- Dev-only: resolve head layer then run texel coordinate semantics audit.
function M.DebugAnalyzeTexelCoordinateSemanticsForEntity(ent, options)
	options = options or {}
	local out = {
		available = false,
		error = nil,
	}
	if not ent then
		out.error = "nil_ent"
		return out
	end
	local info = M.GetEntityHeadFrameInfo(ent, options)
	if not info or info.source ~= "head_layer" or not info.sprite or info.layer_id == nil then
		out.error = "no_head_layer"
		out.head_source = info and info.source or nil
		out.scalp_scan_state = info and info.scalp_scan_state or nil
		return out
	end
	local layer_out = M.DebugAnalyzeTexelCoordinateSemantics(
		info.sprite,
		info.layer_id,
		info.from_overlay == true,
		options
	)
	for k, v in pairs(layer_out) do
		out[k] = v
	end
	out.head_source = info.source
	return out
end

--- Dev-only: full-scan current head-layer crop for any non-transparent texel.
--- Probe only. Do not call from formal consumers / hide rules.
--- options: same as GetEntityHeadFrameInfo, plus alphaThreshold (default 0.1).
function M.DebugAnalyzeHeadFramePresence(ent, options)
	options = options or {}
	local out = {
		available = false,
		nontransparent = false,
		alpha_pixels = 0,
		sample_pixels = 0,
		coverage = 0,
		layer_id = nil,
		layer_name = nil,
		sheet = nil,
		crop = nil,
		width = nil,
		height = nil,
		cached = false,
		source = nil,
		error = nil,
	}
	if not ent then
		out.error = "nil_ent"
		return out
	end

	local info = M.GetEntityHeadFrameInfo(ent, options)
	out.source = info and info.source or nil
	out.layer_id = info and info.layer_id or nil
	if not info or info.source ~= "head_layer" or not info.sprite or info.layer_id == nil then
		out.error = "no_head_layer"
		return out
	end

	local layer_out = M.DebugAnalyzeLayerCropPresence(
		info.sprite,
		info.layer_id,
		info.from_overlay == true,
		options
	)
	for k, v in pairs(layer_out) do
		out[k] = v
	end
	out.source = info.source
	return out
end

--- Dev-only: candidate head/body layers for presence summary (probe).
function M.DebugListCandidateLayers(sprite)
	local out = {}
	if not sprite or not sprite.GetLayerCount then
		return out
	end
	local seen = {}
	local function push(layer_id, from_overlay, reason)
		local key = tostring(layer_id) .. "|" .. tostring(from_overlay)
		if seen[key] then
			return
		end
		seen[key] = true
		local layer_state = sprite.GetLayer and sprite:GetLayer(layer_id) or nil
		local name = nil
		if layer_state and layer_state.GetName then
			local ok, n = pcall(function()
				return layer_state:GetName()
			end)
			if ok then
				name = n
			end
		end
		out[#out + 1] = {
			layer_id = layer_id,
			from_overlay = from_overlay == true,
			layer_name = name,
			reason = reason,
		}
	end

	local selected, from_overlay = M.FindHeadLayer(sprite)
	if selected ~= nil then
		push(selected, from_overlay, "selected")
	end
	for layer_id = 0, sprite:GetLayerCount() - 1 do
		local layer_state = sprite:GetLayer(layer_id)
		local name = layer_state and layer_state.GetName and string.lower(layer_state:GetName() or "") or ""
		if layer_name_priority(name) < 9999 then
			push(layer_id, false, "head_name")
		end
	end
	return out
end

function M.ClearCaches()
	head_layer_cache = {}
	scalp_cache = {}
	frame_presence_debug_cache = {}
	helper_bound_sheet[production_head_helper] = nil
	helper_bound_sheet[debug_head_helper] = nil
end

function M.DebugGetScalpStats()
	return {
		cache_hits = scalp_stats.cache_hits,
		scans = scalp_stats.scans,
		texel_samples = scalp_stats.texel_samples,
		hit_scans = scalp_stats.hit_scans,
		empty_scans = scalp_stats.empty_scans,
	}
end

function M.DebugResetScalpStats()
	scalp_stats.cache_hits = 0
	scalp_stats.scans = 0
	scalp_stats.texel_samples = 0
	scalp_stats.hit_scans = 0
	scalp_stats.empty_scans = 0
end

local function force_helper_crop_zero(helper)
	local layer = get_helper_layer(helper)
	if layer and layer.SetCropOffset then
		pcall(function()
			layer:SetCropOffset(Vector.Zero)
		end)
	end
end

--- Dev-only: belt-and-suspenders crop reset on both helpers after probe scans.
--- Production scans already restore via with_helper_sheet_crop.
function M.DebugRestoreHeadHelperCropOffset()
	force_helper_crop_zero(production_head_helper)
	force_helper_crop_zero(debug_head_helper)
end

return M
