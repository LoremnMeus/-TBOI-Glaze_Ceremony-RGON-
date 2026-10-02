-- Visual-center registration for Runtime Stitch capture.
--
-- Production path: measure alpha content center on a raw Entity:Render RT,
-- then offset the next capture so the visual center sits on the seam normal
-- anchor (default 0). Pose-keyed cache avoids remeasure noise.
--
-- This is NOT RootAnimation / "common layer motion". Horf's body Layer
-- PositionX (±2) is legitimate animation; treating layer-vs-frame0 median as
-- Root translation is incorrect for single-layer enemies.

local geometry = require("Qing_Remaster_scripts.auxiliary.sprite_splice_geometry")

local M = {}

local function as_xy(v)
	if not v then
		return nil, nil
	end
	local x = v.X or v.x or v[1]
	local y = v.Y or v.y or v[2]
	if x == nil or y == nil then
		return nil, nil
	end
	return tonumber(x) or 0, tonumber(y) or 0
end

local function normalize2(nx, ny)
	local len = math.sqrt(nx * nx + ny * ny)
	if len < 1e-6 then
		return 1, 0
	end
	return nx / len, ny / len
end

local function cut_axes(cut_normal)
	local nx = 1
	local ny = 0
	if cut_normal then
		nx = tonumber(cut_normal[1] or cut_normal.x or cut_normal.X) or 1
		ny = tonumber(cut_normal[2] or cut_normal.y or cut_normal.Y) or 0
	end
	nx, ny = normalize2(nx, ny)
	return nx, ny, -ny, nx
end

--- Full Entity:Render silhouette axis in RT-local coords (origin = RT center).
--- Production registration uses bbox center (union of all rendered layers/overlays).
--- Alpha-weighted centroid is diagnostic only — Head-heavy overlays bias it.
---
--- Registration only cancels whole-silhouette translation along the cut normal.
--- It does NOT cancel local stretch, rotation, mouth deformation, or crop changes.
function M.measure_silhouette_axis_local(image, size, sample_step, opts)
	opts = opts or {}
	size = tonumber(size) or 128
	sample_step = math.max(1, tonumber(sample_step) or 2)
	local measure = opts.registration_measure or opts.measure or "bbox_center"
	local alpha, err = geometry.analyze_image_alpha(image, size, sample_step)
	if not alpha then
		return nil, err or "alpha failed"
	end
	local bbc = alpha.bbox_center_local
	local acc = alpha.centroid_local
	local ax = acc and (acc[1] or acc.x) or nil
	local ay = acc and (acc[2] or acc.y) or nil
	local bx = bbc and (bbc[1] or bbc.x) or nil
	local by = bbc and (bbc[2] or bbc.y) or nil
	if bx == nil and alpha.bbox then
		local b = alpha.bbox
		bx = (b.minx + b.maxx + 1) * 0.5 - size * 0.5
		by = (b.miny + b.maxy + 1) * 0.5 - size * 0.5
		bbc = { bx, by }
	end
	local cx, cy, source
	if measure == "alpha_centroid" and ax ~= nil then
		cx, cy, source = ax, ay, "alpha_centroid"
	elseif bx ~= nil then
		cx, cy, source = bx, by, "bbox_center"
	elseif ax ~= nil then
		cx, cy, source = ax, ay, "alpha_centroid_fallback"
	else
		return nil, "no content"
	end
	return {
		x = tonumber(cx) or 0,
		y = tonumber(cy) or 0,
		bbox = alpha.bbox,
		bbox_center_local = bbc and { bx or bbc[1], by or bbc[2] } or nil,
		bbox_center_x = bx,
		bbox_center_y = by,
		alpha_centroid_local = (ax ~= nil) and { x = ax, y = ay } or nil,
		alpha_centroid_x = ax,
		alpha_centroid_y = ay,
		centroid_px = alpha.centroid_px,
		source = source,
		registration_measure = measure,
		sample_step = sample_step,
		alpha = alpha,
	}, nil
end

--- Back-compat alias; production default is bbox silhouette axis.
function M.measure_visual_center_local(image, size, sample_step, opts)
	local measure = (opts and (opts.registration_measure or opts.measure)) or "bbox_center"
	return M.measure_silhouette_axis_local(image, size, sample_step, {
		registration_measure = measure,
		measure = measure,
	})
end

--- Project silhouette axis onto cut normal; registration pushes axis to seam anchor.
--- Content moves; seam plane does not.
function M.registration_from_visual_center(center_local, cut_normal, opts)
	opts = opts or {}
	local target = tonumber(opts.target_center_normal)
	if target == nil then
		target = 0
	end
	local nx, ny = cut_axes(cut_normal)
	local cx, cy = as_xy(center_local)
	cx = cx or 0
	cy = cy or 0
	local raw_n = cx * nx + cy * ny
	local reg_n = target - raw_n
	local ox = nx * reg_n
	local oy = ny * reg_n
	local diag = {
		ok = true,
		source = "silhouette_axis",
		registration_measure = center_local and center_local.source or "bbox_center",
		axis = opts.axis or "normal",
		cut_normal = { x = nx, y = ny },
		raw_visual_center = { x = cx, y = cy },
		raw_bbox_center = center_local and center_local.bbox_center_local and {
			x = center_local.bbox_center_x or center_local.bbox_center_local[1],
			y = center_local.bbox_center_y or center_local.bbox_center_local[2],
		} or { x = cx, y = cy },
		raw_bbox_center_normal = raw_n,
		raw_visual_center_normal = raw_n, -- alias for older probes
		alpha_centroid_local = center_local and center_local.alpha_centroid_local or nil,
		target_center_normal = target,
		seam_normal_anchor = target,
		registration_normal = reg_n,
		registration = { x = ox, y = oy },
		normal_delta = { x = -ox, y = -oy },
		chosen_registration_center_source = center_local and center_local.source or "bbox_center",
		centroid_source = center_local and center_local.source or nil,
	}
	return Vector(ox, oy), diag
end

--- Measure raw RT → registration offset (bbox silhouette axis by default).
function M.registration_from_raw_image(image, size, cut_normal, opts)
	opts = opts or {}
	local sample_step = math.max(1, tonumber(opts.sample_step) or 2)
	local measure = opts.registration_measure or opts.measure or "bbox_center"
	local center, cerr = M.measure_silhouette_axis_local(image, size, sample_step, {
		registration_measure = measure,
	})
	if not center then
		local diag = {
			ok = false,
			source = "silhouette_axis",
			reason = cerr or "measure failed",
			sample_step = sample_step,
			registration_measure = measure,
		}
		return Vector(0, 0), diag
	end
	local offset, diag = M.registration_from_visual_center(center, cut_normal, opts)
	diag.measure = center
	diag.sample_step = sample_step
	diag.bbox = center.bbox
	diag.bbox_center_local = center.bbox_center_local
	diag.alpha_centroid_local = center.alpha_centroid_local
	if center.alpha_centroid_local then
		local nx, ny = cut_axes(cut_normal)
		local ax = center.alpha_centroid_local.x or center.alpha_centroid_local[1] or 0
		local ay = center.alpha_centroid_local.y or center.alpha_centroid_local[2] or 0
		diag.alpha_centroid_normal = ax * nx + ay * ny
	end
	return offset, diag
end

---------------------------------------------------------------------------
-- Legacy FrameData helpers (NOT used by production Runtime Stitch).
-- Kept for infrastructure Gate probes that still inspect layer GetPos.
---------------------------------------------------------------------------

local function median(nums)
	local n = #nums
	if n == 0 then
		return 0
	end
	table.sort(nums)
	if n % 2 == 1 then
		return nums[math.floor((n + 1) / 2)]
	end
	local a = nums[math.floor(n / 2)]
	local b = nums[math.floor(n / 2) + 1]
	return (a + b) * 0.5
end

--- DEPRECATED: layer current-frame0 median is NOT Root translation.
--- Single-layer enemies (Horf) misclassify body Layer PositionX as common motion.
function M.get_common_animation_translation(sprite)
	local meta = {
		ok = false,
		layer_count = 0,
		sample_count = 0,
		source = "frame_data_layer_delta_deprecated",
		deprecated = true,
	}
	if not sprite then
		meta.reason = "no_sprite"
		return Vector(0, 0), meta
	end
	if not (sprite.GetCurrentAnimationData and sprite.GetLayerFrameData) then
		meta.reason = "api_missing"
		return Vector(0, 0), meta
	end
	local anim
	local ok_anim, anim_or_err = pcall(function()
		return sprite:GetCurrentAnimationData()
	end)
	if not ok_anim or not anim_or_err then
		meta.reason = "no_anim_data"
		return Vector(0, 0), meta
	end
	anim = anim_or_err
	local layers
	local ok_layers, layers_or_err = pcall(function()
		return anim:GetAllLayers()
	end)
	if not ok_layers or type(layers_or_err) ~= "table" then
		meta.reason = "no_layers"
		return Vector(0, 0), meta
	end
	layers = layers_or_err
	local dxs, dys, samples = {}, {}, {}
	for _, layer in pairs(layers) do
		if layer and layer.GetLayerID and layer.GetFrame then
			meta.layer_count = meta.layer_count + 1
			local lid
			local ok_id, id_or_err = pcall(function()
				return layer:GetLayerID()
			end)
			if ok_id then
				lid = id_or_err
			end
			if lid ~= nil then
				local current, baseline
				pcall(function()
					current = sprite:GetLayerFrameData(lid)
				end)
				pcall(function()
					baseline = layer:GetFrame(0)
				end)
				if current and baseline and current.GetPos and baseline.GetPos then
					local cx, cy = as_xy(current:GetPos())
					local bx, by = as_xy(baseline:GetPos())
					if cx ~= nil and bx ~= nil then
						local dx = cx - bx
						local dy = cy - by
						dxs[#dxs + 1] = dx
						dys[#dys + 1] = dy
						meta.sample_count = meta.sample_count + 1
						samples[#samples + 1] = {
							layer_id = lid,
							current = { x = cx, y = cy },
							base = { x = bx, y = by },
							delta = { x = dx, y = dy },
						}
					end
				end
			end
		end
	end
	if meta.sample_count == 0 then
		meta.reason = "no_samples"
		meta.samples = samples
		return Vector(0, 0), meta
	end
	meta.ok = true
	meta.common = { x = median(dxs), y = median(dys) }
	meta.samples = samples
	return Vector(meta.common.x, meta.common.y), meta
end

--- DEPRECATED alias — do not use for production stitch.
function M.registration_for_sprite(sprite, cut_normal, opts)
	opts = opts or {}
	local common, meta = M.get_common_animation_translation(sprite)
	local nx, ny = cut_axes(cut_normal)
	local cx, cy = as_xy(common)
	cx = cx or 0
	cy = cy or 0
	local axis = opts.axis or "normal"
	local diag = {
		ok = meta.ok == true,
		source = "frame_data_layer_delta_deprecated",
		deprecated = true,
		meta = meta,
		samples = meta.samples,
		sample_count = meta.sample_count,
		common = { x = cx, y = cy },
		cut_normal = { x = nx, y = ny },
		axis = axis,
	}
	if axis == "full" then
		diag.registration = { x = -cx, y = -cy }
		return Vector(-cx, -cy), diag
	end
	local dot = cx * nx + cy * ny
	diag.normal_delta = { x = nx * dot, y = ny * dot }
	diag.registration = { x = -nx * dot, y = -ny * dot }
	return Vector(-nx * dot, -ny * dot), diag
end

--- Current Interpolated layer transform (Position / Scale / Rotation).
--- Not part of GeometryNode identity — apply on top of cached discrete geometry.
function M.get_interpolated_layer_transform(sprite)
	local out = {
		ok = false,
		x = 0,
		y = 0,
		scale_x = 1,
		scale_y = 1,
		rotation = 0,
		layer_count = 0,
		sample_count = 0,
	}
	if not sprite then
		out.reason = "no_sprite"
		return out
	end
	if not (sprite.GetCurrentAnimationData and sprite.GetLayerFrameData) then
		out.reason = "api_missing"
		return out
	end
	local anim
	local ok_anim, anim_or_err = pcall(function()
		return sprite:GetCurrentAnimationData()
	end)
	if not ok_anim or not anim_or_err then
		out.reason = "no_anim_data"
		return out
	end
	anim = anim_or_err
	local layers
	local ok_layers, layers_or_err = pcall(function()
		return anim:GetAllLayers()
	end)
	if not ok_layers or type(layers_or_err) ~= "table" then
		out.reason = "no_layers"
		return out
	end
	layers = layers_or_err
	local xs, ys, sxs, sys, rots = {}, {}, {}, {}, {}
	for _, layer in pairs(layers) do
		if layer and layer.GetLayerID then
			out.layer_count = out.layer_count + 1
			local lid
			pcall(function()
				lid = layer:GetLayerID()
			end)
			if lid ~= nil then
				local fd
				pcall(function()
					fd = sprite:GetLayerFrameData(lid)
				end)
				if fd and fd.IsVisible and fd:IsVisible() and fd.GetPos then
					local px, py = as_xy(fd:GetPos())
					if px ~= nil then
						xs[#xs + 1] = px
						ys[#ys + 1] = py
						out.sample_count = out.sample_count + 1
					end
					if fd.GetScale then
						local sc = fd:GetScale()
						if sc then
							sxs[#sxs + 1] = sc.X or 1
							sys[#sys + 1] = sc.Y or 1
						end
					end
					if fd.GetRotation then
						rots[#rots + 1] = fd:GetRotation() or 0
					end
				end
			end
		end
	end
	if out.sample_count == 0 then
		out.reason = "no_samples"
		return out
	end
	out.ok = true
	out.x = median(xs)
	out.y = median(ys)
	out.scale_x = (#sxs > 0) and median(sxs) or 1
	out.scale_y = (#sys > 0) and median(sys) or 1
	out.rotation = (#rots > 0) and median(rots) or 0
	return out
end

return M
