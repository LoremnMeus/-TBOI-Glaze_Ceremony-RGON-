-- Compatibility shim for Runtime Stitch adapters.
-- Canonical geometry lives in sprite_splice_geometry.
-- Prefer sprite_splice / sprite_splice_geometry for new code.

local geom = require("Qing_Remaster_scripts.auxiliary.sprite_splice_geometry")

local M = {
	MIN_SCALE = geom.MIN_SCALE,
	MAX_SCALE = geom.MAX_SCALE,
	FRAME_WEIGHT = geom.FRAME_WEIGHT,
	REF_WEIGHT = geom.REF_WEIGHT,
}

local function profile_span(profile_or_span)
	if type(profile_or_span) == "number" then
		return profile_or_span
	end
	if type(profile_or_span) ~= "table" then
		return nil
	end
	local g = profile_or_span.geometry_prior or profile_or_span.stitch_geometry
	if type(g) == "table" then
		local span = tonumber(g.avg_vertical_span)
		if span and span > 0 then return span end
	end
	return tonumber(profile_or_span.reference_span)
end

function M.reference_span(profile)
	return profile_span(profile)
end

--- Legacy: accepts movement/attack profiles OR numeric spans.
function M.blend_scale_ratio(frame_ratio, host_profile_or_span, donor_profile_or_span)
	return geom.blend_scale_ratio(
		frame_ratio,
		profile_span(host_profile_or_span),
		profile_span(donor_profile_or_span)
	)
end

-- Deprecated simplified path. Prefer geom.solve_pair via sprite_splice.
function M.compute_alignment(opts)
	opts = opts or {}
	local frame_ratio = 1
	local host_span = tonumber(opts.host_span) or 0
	local donor_span = tonumber(opts.donor_span) or 0
	if host_span > 2 and donor_span > 2 then
		frame_ratio = host_span / donor_span
	end
	local blend = M.blend_scale_ratio(frame_ratio, opts.host_profile, opts.donor_profile)
	local base = tonumber(opts.base_scale) or 1
	local donor_scale = base * blend.final_ratio
	local hc = opts.host_centroid or { 0, 0 }
	local dc = opts.donor_centroid or { 0, 0 }
	local hx, hy = hc[1] or 0, hc[2] or 0
	local dx = (dc[1] or 0) * donor_scale
	local dy = (dc[2] or 0) * donor_scale
	return {
		host_scale = 1,
		donor_scale = donor_scale,
		host_offset = { 0, 0 },
		donor_offset = { hx - dx, hy - dy },
		frame_ratio = blend.frame_ratio,
		reference_ratio = blend.reference_ratio,
		final_ratio = blend.final_ratio,
		clamped = blend.clamped,
		host_ref_span = blend.host_ref_span,
		donor_ref_span = blend.donor_ref_span,
		seam = {
			host_center = { hx, hy },
			donor_center = { dx, dy },
			residual = { 0, 0 },
		},
		_deprecated = "use sprite_splice_geometry.solve_pair",
	}
end

function M.fit_pair_to_box(alignment_or_solution, width, height, bbox_w_or_opts, bbox_h, max_scale)
	-- New signature: fit_pair_to_box(solution, width, height, opts)
	if type(alignment_or_solution) == "table" and alignment_or_solution.host and alignment_or_solution.donor
		and alignment_or_solution.host.cut_local then
		local opts = type(bbox_w_or_opts) == "table" and bbox_w_or_opts or { max_scale = max_scale }
		return geom.fit_pair_to_box(alignment_or_solution, width, height, opts)
	end
	-- Legacy: (alignment, w, h, bbox_w, bbox_h, max_scale)
	local alignment = alignment_or_solution or {}
	local bbox_w = tonumber(bbox_w_or_opts) or width
	local bh = tonumber(bbox_h) or height
	local ms = tonumber(max_scale) or 1.35
	if bbox_w < 1 then bbox_w = 1 end
	if bh < 1 then bh = 1 end
	local fit = math.min((tonumber(width) or 92) / bbox_w, (tonumber(height) or 76) / bh, ms)
	return {
		fit_scale = fit,
		host_scale = (alignment.host_scale or 1) * fit,
		donor_scale = (alignment.donor_scale or 1) * fit,
		host_offset = {
			(alignment.host_offset and alignment.host_offset[1] or 0) * fit,
			(alignment.host_offset and alignment.host_offset[2] or 0) * fit,
		},
		donor_offset = {
			(alignment.donor_offset and alignment.donor_offset[1] or 0) * fit,
			(alignment.donor_offset and alignment.donor_offset[2] or 0) * fit,
		},
		bbox_w = bbox_w,
		bbox_h = bh,
		max_scale = ms,
	}
end

function M.compute_pair_bbox(a, b, c, d, e)
	if type(a) == "table" and a.host and a.donor then
		return geom.compute_pair_bbox(a)
	end
	-- legacy (host_bbox, donor_bbox, host_rt, donor_rt, alignment)
	local host_bbox, donor_bbox, host_rt, donor_rt, alignment = a, b, c, d, e
	alignment = alignment or {}
	local fake = {
		host = {
			bbox = host_bbox,
			size = host_rt,
			scale = alignment.host_scale or 1,
			offset_local = alignment.host_offset or { 0, 0 },
		},
		donor = {
			bbox = donor_bbox,
			size = donor_rt,
			scale = alignment.donor_scale or 1,
			offset_local = alignment.donor_offset or { 0, 0 },
		},
	}
	return geom.compute_pair_bbox(fake)
end

M.bbox_to_center_rel = geom.bbox_to_center_rel
M.transform_bbox = geom.transform_bbox
M.union_bbox = geom.union_bbox
M.analyze_source = geom.analyze_source
M.solve_pair = geom.solve_pair

return M
