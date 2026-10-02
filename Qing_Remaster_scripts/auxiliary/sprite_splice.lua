-- Public façade: stitch two sources via Image bake + Gate3D geometry.
-- Consumers must not invent private Host/Donor seam math.
--
-- Source modes:
--   entity = production live NPC → capture_entity (EntityNPC:Render → RT)
--   sprite = UI / generic → bake_sprite (Sprite:Render → RT), dirty-key optimized
--
-- Capture refresh ≠ geometry refresh.
-- Live entity: dirty-key on sprite_frame_key (NOT Position). force_entity_capture
--   is escape hatch for create/debug only; production passes false.
-- Geometry (alpha/best-cut/solve) only when GeometryNode key changes.
-- Runtime Stitch production: centerline-only. Failed centerline never falls back
-- to bbox / full-image alpha / centroid (see runtime_stitch_gates.md).
-- Shared GLOBAL_* caches keyed by profile/TVS + node (never entity ptr / Position).

local geometry = require("Qing_Remaster_scripts.auxiliary.sprite_splice_geometry")
local render = require("Qing_Remaster_scripts.auxiliary.sprite_splice_render")
local registration = require("Qing_Remaster_scripts.auxiliary.sprite_visual_registration")

local M = {
	geometry = geometry,
	render = render,
	registration = registration,
}

-- Module-level shared caches (cross-pair). Not keyed by entity ptr / Position.
local GLOBAL_GEOMETRY_NODE_CACHE = {}
local GLOBAL_GEOMETRY_NODE_ORDER = {}
local GLOBAL_NODE_PAIR_SCALE_CACHE = {}
local GLOBAL_NODE_PAIR_SCALE_ORDER = {}
local GLOBAL_CACHE_MAX = 512

local PERF = {
	entity_rt_captures = 0,
	geometry_node_cache_hits = 0,
	geometry_node_cache_misses = 0,
	pair_solution_cache_hits = 0,
	pair_solution_cache_misses = 0,
}

function M.get_perf_counters()
	local gp = geometry.get_perf_counters and geometry.get_perf_counters() or {}
	return {
		entity_rt_captures = PERF.entity_rt_captures,
		geometry_node_cache_hits = PERF.geometry_node_cache_hits,
		geometry_node_cache_misses = PERF.geometry_node_cache_misses,
		pair_solution_cache_hits = PERF.pair_solution_cache_hits,
		pair_solution_cache_misses = PERF.pair_solution_cache_misses,
		global_geometry_node_cache_size = #GLOBAL_GEOMETRY_NODE_ORDER,
		global_node_pair_scale_cache_size = #GLOBAL_NODE_PAIR_SCALE_ORDER,
		get_texel_region = gp.get_texel_region,
		centerline_scans = gp.centerline_scans,
		decoded_texels = gp.decoded_texels,
		charm_rgb_tests = gp.charm_rgb_tests,
		full_alpha_scans = gp.full_alpha_scans,
		interface_scans = gp.interface_scans,
	}
end

function M.reset_perf_counters()
	PERF.entity_rt_captures = 0
	PERF.geometry_node_cache_hits = 0
	PERF.geometry_node_cache_misses = 0
	PERF.pair_solution_cache_hits = 0
	PERF.pair_solution_cache_misses = 0
	if geometry.reset_perf_counters then
		geometry.reset_perf_counters()
	end
end

local function put_global_lru(cache, order, key, entry, max_n)
	max_n = max_n or GLOBAL_CACHE_MAX
	if not cache[key] then
		order[#order + 1] = key
		while #order > max_n do
			local old = table.remove(order, 1)
			if old then
				cache[old] = nil
			end
		end
	end
	cache[key] = entry
end

local function side_source_id(side)
	if not side then
		return "unknown"
	end
	if side.profile_id ~= nil and side.profile_id ~= "" then
		return tostring(side.profile_id)
	end
	local ent = side.entity
	if ent then
		return string.format(
			"%s.%s.%s",
			tostring(ent.Type),
			tostring(ent.Variant),
			tostring(ent.SubType)
		)
	end
	return "unknown"
end

local function global_geometry_cache_key(side, node_key)
	return side_source_id(side) .. "|" .. tostring(node_key)
end

local function side_opts(side, defaults)
	side = side or {}
	return {
		entity = side.entity,
		sprite = side.sprite,
		draw = side.draw, -- sprite path only; nil => Sprite:Render
		keep_sign = (side.keep_sign ~= nil) and side.keep_sign or defaults.keep_sign,
		reference_span = side.reference_span,
		cut_origin = side.cut_origin,
		capture_wrap = side.capture_wrap,
		-- { mode="interface_first"|"interface" } production; legacy silhouette_axis for non-RS only
		registration = side.registration,
		-- Runtime Stitch geometry metadata (must survive create() normalization)
		profile_kind = side.profile_kind,
		profile_id = side.profile_id,
		ignore_geometry_frames = side.ignore_geometry_frames,
	}
end

local function side_has_source(cfg)
	return cfg.entity ~= nil or cfg.sprite ~= nil
end

local function live_sprite_of(side)
	if not side then
		return nil
	end
	if side.entity and side.entity.Exists and side.entity:Exists() and side.entity.GetSprite then
		return side.entity:GetSprite()
	end
	return side.sprite
end

--- Create a stitched pair.
--- opts.host / opts.donor: { entity=... } OR { sprite=... [, draw] }, keep_sign, reference_span
function M.create(opts)
	opts = opts or {}
	if not render.api_ready() then
		return nil, render.get_last_error() or "api not ready"
	end
	local size = tonumber(opts.size) or render.TARGET_SIZE
	-- Defaults match Left/host = keep right half (+1), Right/donor = keep left (-1).
	local host_cfg = side_opts(opts.host, { keep_sign = 1 })
	local donor_cfg = side_opts(opts.donor, { keep_sign = -1 })
	if not side_has_source(host_cfg) or not side_has_source(donor_cfg) then
		return nil, "host and donor require entity or sprite"
	end
	local host_slot = render.acquire_source(size)
	local donor_slot = render.acquire_source(size)
	if not host_slot or not donor_slot then
		if host_slot then render.release_source(host_slot) end
		if donor_slot then render.release_source(donor_slot) end
		return nil, render.get_last_error() or "acquire failed"
	end
	local pair = {
		size = size,
		cut_normal = opts.cut_normal or { 1, 0 },
		feather = opts.feather or 0,
		capture_wrap = opts.capture_wrap, -- shared wrap for entity captures
		-- Live NPC policy (UI preview leaves these nil / false).
		geometry_policy = opts.geometry_policy or {
			stable_cut = false,
			fixed_seam_plane = false,
			seam_normal_anchor = 0,
			fixed_body_scale = false,
			pose_geometry_cache = false,
			geometry_node_cache = false,
			node_pair_scale = false,
			-- Silhouette axis = full Entity:Render union bbox center (not alpha centroid).
			silhouette_axis_registration = false,
			visual_center_registration = false, -- alias of silhouette_axis_registration
			registration_measure = "bbox_center",
			tangent_align = "range_mid", -- interface (t_min+t_max)/2; not alpha centroid
			scale_mode = "blend",
			collect_cut_candidates = false,
			sample_step = nil, -- nil → geometry default 2; production sets 2
			min_scale = nil,
			max_scale = nil,
		},
		body_scale = tonumber(opts.body_scale),
		body_scale_source = opts.body_scale_source,
		pose_geometry_cache = {},
		pose_geometry_cache_order = {},
		node_pair_scale_cache = {},
		node_pair_scale_order = {},
		current_pose_key = nil,
		last_pose_geom_diag = nil,
		host = {
			entity = host_cfg.entity,
			sprite = host_cfg.sprite,
			draw = host_cfg.draw,
			keep_sign = host_cfg.keep_sign,
			reference_span = host_cfg.reference_span or opts.host_reference_span,
			ignore_geometry_frames = host_cfg.ignore_geometry_frames,
			profile_kind = host_cfg.profile_kind,
			profile_id = host_cfg.profile_id,
			slot = host_slot,
			analysis = nil,
			visual_key = nil,
			capture_mode = nil,
			capture_wrap = host_cfg.capture_wrap,
			registration = host_cfg.registration,
			registration_diag = nil,
			geometry_state = nil,
			last_good_geometry_analysis = nil,
			last_good_geometry_node_key = nil,
			geometry_frame_filter = nil,
		},
		donor = {
			entity = donor_cfg.entity,
			sprite = donor_cfg.sprite,
			draw = donor_cfg.draw,
			keep_sign = donor_cfg.keep_sign,
			reference_span = donor_cfg.reference_span or opts.donor_reference_span,
			ignore_geometry_frames = donor_cfg.ignore_geometry_frames,
			profile_kind = donor_cfg.profile_kind,
			profile_id = donor_cfg.profile_id,
			slot = donor_slot,
			analysis = nil,
			visual_key = nil,
			capture_mode = nil,
			capture_wrap = donor_cfg.capture_wrap,
			registration = donor_cfg.registration,
			registration_diag = nil,
			geometry_state = nil,
			last_good_geometry_analysis = nil,
			last_good_geometry_node_key = nil,
			geometry_frame_filter = nil,
		},
		solution = nil,
		presentation = nil,
		dirty = {
			host_bake = true,
			donor_bake = true,
			geometry = true,
		},
		last_update_frame = nil,
		last_error = nil,
		last_geometry_trace = nil,
	}
	-- Initial refresh so UI/create has a solution; live path also safe.
	M.update(pair, { force_entity_capture = true })
	return pair
end

local function runtime_registration_enabled(side, policy)
	if policy.interface_first_registration == true
		or policy.registration_measure == "interface_first"
		or policy.registration_measure == "interface"
	then
		return true
	end
	-- Legacy / non–Runtime-Stitch consumers may still enable bbox registration.
	if policy.silhouette_axis_registration == true
		or policy.visual_center_registration == true
	then
		return true
	end
	local reg = side and side.registration
	if not reg then
		return false
	end
	return reg.mode == "interface_first"
		or reg.mode == "interface"
		or reg.mode == "visual_center"
		or reg.mode == "silhouette_axis"
		or reg.mode == "bbox_center"
		or reg.visual_center == true
		or reg.silhouette_axis == true
end

local function policy_centerline_only(policy)
	policy = policy or {}
	return policy.interface_first_registration == true
		or policy.registration_measure == "interface_first"
		or policy.registration_measure == "interface"
end

local function light_centerline(cl)
	if type(cl) ~= "table" then
		return { ok = false, count = 0, span = 0 }
	end
	return {
		ok = cl.ok == true,
		chosen_column = cl.chosen_column,
		mid = cl.mid,
		span = tonumber(cl.span) or 0,
		count = tonumber(cl.count) or 0,
		scan_along_y = cl.scan_along_y,
		progressive_half_width = cl.progressive_half_width,
	}
end

local function side_centerline_ok(side)
	local cl = side and side.current_centerline
	return cl
		and cl.ok == true
		and cl.chosen_column ~= nil
		and (tonumber(cl.count) or 0) > 0
end

--- Live Entity capture with GeometryNode-aware silhouette-axis registration.
--- GeometryNode = discrete anim/frame/overlay/flip/crop (Combination semantics).
--- Interpolated Position/Scale/Rotation are runtime transform only — they adjust
--- cached registration, they do NOT invalidate the GeometryNode.
local function copy_bbox(b)
	if not b then
		return nil
	end
	return {
		minx = tonumber(b.minx),
		miny = tonumber(b.miny),
		maxx = tonumber(b.maxx),
		maxy = tonumber(b.maxy),
	}
end

local function store_geometry_node_cache(side, gkey, node_key, entry, use_node_cache)
	if not use_node_cache or not entry then
		return
	end
	put_global_lru(
		GLOBAL_GEOMETRY_NODE_CACHE,
		GLOBAL_GEOMETRY_NODE_ORDER,
		gkey,
		entry,
		GLOBAL_CACHE_MAX
	)
	side.geometry_node_cache = side.geometry_node_cache or {}
	side.geometry_node_order = side.geometry_node_order or {}
	if not side.geometry_node_cache[node_key] then
		side.geometry_node_order[#side.geometry_node_order + 1] = node_key
		while #side.geometry_node_order > 256 do
			local old = table.remove(side.geometry_node_order, 1)
			if old then
				side.geometry_node_cache[old] = nil
			end
		end
	end
	side.geometry_node_cache[node_key] = entry
end

local function finish_centerline_miss(side, node, cl, cerr, xform, gkey, use_node_cache, sample_step)
	local light = light_centerline(cl)
	side.current_centerline = light
	side.current_centerline_error = cerr
	side.current_centerline_node_key = node.key
	side.registration_diag = {
		ok = false,
		source = "centerline",
		registration_source = "centerline_miss",
		geometry_node_key = node.key,
		geometry_node = node,
		geometry_cache_version = node.geometry_cache_version or render.GEOMETRY_CACHE_VERSION,
		registration_measure = "interface_first",
		centerline = light,
		sample_step = sample_step,
		cache_hit = false,
	}
	side.last_geometry_node_key = node.key
	side.capture_mode = (side.slot and side.slot.capture_mode) or nil
	store_geometry_node_cache(side, gkey, node.key, {
		centerline = light,
		registration_source = "centerline_miss",
		capture_pos_x = xform.x or 0,
		capture_pos_y = xform.y or 0,
		created_frame = Game():GetFrameCount(),
	}, use_node_cache)
	if side.entity and side.entity.GetSprite then
		side.sprite = side.entity:GetSprite()
	end
	return true
end

local function capture_side(side, pair_wrap, cut_normal, pair, policy)
	if not side or not side.slot then
		return false
	end
	policy = policy or (pair and pair.geometry_policy) or {}
	local use_reg = runtime_registration_enabled(side, policy)

	if side.entity then
		local wrap = side.capture_wrap or pair_wrap
		if use_reg then
			if side.entity.GetSprite then
				side.sprite = side.entity:GetSprite()
			end
			local spr = live_sprite_of(side)
			local node = render.get_geometry_node_info(spr)
			local xform = registration.get_interpolated_layer_transform(spr)
			local seam_anchor = tonumber(policy.seam_normal_anchor) or 0
			local measure = policy.registration_measure or "bbox_center"
			local sample_step = math.max(1, tonumber(policy.sample_step) or 2)
			local nx = (cut_normal and (cut_normal[1] or cut_normal.x)) or 1
			local ny = (cut_normal and (cut_normal[2] or cut_normal.y)) or 0
			local nlen = math.sqrt(nx * nx + ny * ny)
			if nlen > 1e-6 then
				nx, ny = nx / nlen, ny / nlen
			else
				nx, ny = 1, 0
			end

			side.geometry_node_cache = side.geometry_node_cache or {}
			side.geometry_node_order = side.geometry_node_order or {}
			local use_node_cache = policy.geometry_node_cache ~= false
			local gkey = global_geometry_cache_key(side, node.key)
			local cached = nil
			if use_node_cache then
				cached = GLOBAL_GEOMETRY_NODE_CACHE[gkey]
					or side.geometry_node_cache[node.key]
			end
			local offset
			local diag
			local prefer_iface = policy_centerline_only(policy)
				or measure == "interface_first"
				or measure == "interface"

			local function capture_opts(extra)
				extra = extra or {}
				extra.wrap = wrap
				return extra
			end

			-- Cache hit: restore centerline; miss → refresh RT only; hit+body → transform reg.
			if cached and (cached.centerline ~= nil or cached.raw_bbox_center_normal ~= nil) then
				PERF.geometry_node_cache_hits = PERF.geometry_node_cache_hits + 1
				side.geometry_node_cache[node.key] = cached
				local cached_cl = light_centerline(cached.centerline)
				side.current_centerline = cached_cl
				side.current_centerline_error = nil
				side.current_centerline_node_key = node.key

				if cached.registration_source == "centerline_miss"
					or cached_cl.ok ~= true
					or cached_cl.chosen_column == nil
				then
					local ok_raw = render.capture_entity(side.slot, side.entity, capture_opts({
						registration_offset = nil,
					}))
					PERF.entity_rt_captures = PERF.entity_rt_captures + 1
					if not ok_raw then
						side.capture_mode = nil
						side.registration_diag = nil
						return false
					end
					side.registration_diag = {
						ok = false,
						source = "centerline",
						registration_source = "centerline_miss",
						cache_hit = true,
						geometry_node_key = node.key,
						geometry_node = node,
						geometry_cache_version = node.geometry_cache_version
							or render.GEOMETRY_CACHE_VERSION,
						registration_measure = "interface_first",
						centerline = cached_cl,
						sample_step = sample_step,
					}
					side.last_geometry_node_key = node.key
					side.capture_mode = (side.slot and side.slot.capture_mode) or nil
					if side.entity.GetSprite then
						side.sprite = side.entity:GetSprite()
					end
					return true
				end

				-- Transform-only update for successful body registration.
				local dpx = (xform.x or 0) - (cached.capture_pos_x or 0)
				local dpy = (xform.y or 0) - (cached.capture_pos_y or 0)
				local delta_n = dpx * nx + dpy * ny
				local raw_n = (cached.raw_bbox_center_normal or 0) + delta_n
				local reg_n = seam_anchor - raw_n
				offset = Vector(nx * reg_n, ny * reg_n)
				local cached_bbox = copy_bbox(cached.registered_bbox or cached.body_bbox or cached.bbox)
				diag = {
					ok = true,
					source = "geometry_node",
					cache_hit = true,
					registration_source = cached.registration_source or "interface",
					pose_registration_cache = false,
					geometry_node_key = node.key,
					geometry_node = node,
					geometry_cache_version = node.geometry_cache_version or render.GEOMETRY_CACHE_VERSION,
					registration_measure = measure,
					chosen_registration_center_source = cached.registration_source or "interface",
					raw_bbox_center_normal = raw_n,
					raw_visual_center_normal = raw_n,
					registration_normal = reg_n,
					registration = { x = nx * reg_n, y = ny * reg_n },
					seam_normal_anchor = seam_anchor,
					transform_delta_normal = delta_n,
					capture_pos = { x = cached.capture_pos_x, y = cached.capture_pos_y },
					current_pos = { x = xform.x, y = xform.y },
					sample_step = sample_step,
					centerline = cached_cl,
					bbox = cached_bbox,
					body_bbox = copy_bbox(cached.body_bbox) or cached_bbox,
					registered_bbox = copy_bbox(cached.registered_bbox) or cached_bbox,
					raw_bbox = copy_bbox(cached.raw_bbox or cached.body_bbox) or cached_bbox,
				}
			else
				PERF.geometry_node_cache_misses = PERF.geometry_node_cache_misses + 1
				-- New GeometryNode: raw capture → progressive centerline (production).
				local ok_raw = render.capture_entity(side.slot, side.entity, capture_opts({
					registration_offset = nil,
				}))
				PERF.entity_rt_captures = PERF.entity_rt_captures + 1
				if not ok_raw then
					side.capture_mode = nil
					side.registration_diag = nil
					side.current_centerline = nil
					return false
				end

				local iface_ok = false
				local cl, cerr = nil, nil
				if prefer_iface and geometry.measure_centerline_from_image then
					cl, cerr = geometry.measure_centerline_from_image(
						side.slot.image,
						side.slot.size,
						{
							cut_normal = { nx, ny },
							progressive = true,
							half_widths = { 2, 8, 24 },
						}
					)
					side.current_centerline = light_centerline(cl)
					side.current_centerline_error = cerr
					side.current_centerline_node_key = node.key
					if cl and cl.ok and cl.chosen_column ~= nil then
						local half = (side.slot.size or 128) * 0.5
						local lx, ly
						if cl.scan_along_y then
							lx = (cl.chosen_column or half) + 0.5 - half
							ly = (cl.mid or half) + 0.5 - half
						else
							lx = (cl.mid or half) + 0.5 - half
							ly = (cl.chosen_column or half) + 0.5 - half
						end
						local raw_n = lx * nx + ly * ny
						local reg_n = seam_anchor - raw_n
						offset = Vector(nx * reg_n, ny * reg_n)
						diag = {
							ok = true,
							source = "interface",
							registration_source = "interface",
							cache_hit = false,
							pose_registration_cache = false,
							geometry_node_key = node.key,
							geometry_node = node,
							geometry_cache_version = node.geometry_cache_version
								or render.GEOMETRY_CACHE_VERSION,
							registration_measure = "interface_first",
							chosen_registration_center_source = "interface",
							raw_bbox_center_normal = raw_n,
							raw_visual_center_normal = raw_n,
							registration_normal = reg_n,
							registration = { x = nx * reg_n, y = ny * reg_n },
							seam_normal_anchor = seam_anchor,
							sample_step = sample_step,
							chosen_column = cl.chosen_column,
							centerline = cl,
							progressive_half_width = cl.progressive_half_width,
						}
						iface_ok = true
					else
						-- Capture OK; scanline found no body. Do NOT bbox-fallback.
						return finish_centerline_miss(
							side,
							node,
							cl,
							cerr,
							xform,
							gkey,
							use_node_cache,
							sample_step
						)
					end
				end

				-- Legacy non–centerline-only consumers only (UI / debug). Production never enters.
				if not iface_ok and not prefer_iface then
					offset, diag = registration.registration_from_raw_image(
						side.slot.image,
						side.slot.size,
						cut_normal,
						{
							target_center_normal = seam_anchor,
							axis = "normal",
							sample_step = sample_step,
							registration_measure = measure,
						}
					)
					diag = diag or {}
					diag.cache_hit = false
					diag.source = diag.source or "silhouette_axis"
					diag.registration_source = "legacy_bbox"
					diag.pose_registration_cache = false
					diag.geometry_node_key = node.key
					diag.geometry_node = node
					diag.geometry_cache_version = node.geometry_cache_version
						or render.GEOMETRY_CACHE_VERSION
					diag.seam_normal_anchor = seam_anchor
					diag.chosen_registration_center_source = diag.chosen_registration_center_source
						or diag.registration_measure
						or "bbox_center"
					diag.body_bbox = copy_bbox(diag.bbox)
					diag.raw_bbox = copy_bbox(diag.bbox)
					side.current_centerline = nil
				elseif not iface_ok then
					return finish_centerline_miss(
						side,
						node,
						cl,
						cerr,
						xform,
						gkey,
						use_node_cache,
						sample_step
					)
				end

				if use_node_cache and diag and diag.ok then
					store_geometry_node_cache(side, gkey, node.key, {
						raw_bbox_center_normal = tonumber(diag.raw_bbox_center_normal)
							or tonumber(diag.raw_visual_center_normal)
							or 0,
						registration_normal = tonumber(diag.registration_normal) or 0,
						registration_source = diag.registration_source or "interface",
						centerline = light_centerline(diag.centerline),
						capture_pos_x = xform.x or 0,
						capture_pos_y = xform.y or 0,
						created_frame = Game():GetFrameCount(),
						bbox = copy_bbox(diag.bbox),
						body_bbox = copy_bbox(diag.body_bbox),
						raw_bbox = copy_bbox(diag.raw_bbox),
					}, true)
				end

				-- Interface success: keep raw RT (single Entity:Render this miss).
				if iface_ok and offset and diag then
					local size = side.slot.size or 128
					local half = size * 0.5
					local cl_ok = diag.centerline
					local cut_u, cut_v = 0.5, 0.5
					if cl_ok and cl_ok.chosen_column ~= nil then
						if cl_ok.scan_along_y then
							cut_u = ((cl_ok.chosen_column or half) + 0.5) / size
							cut_v = ((cl_ok.mid or half) + 0.5) / size
						else
							cut_u = ((cl_ok.mid or half) + 0.5) / size
							cut_v = ((cl_ok.chosen_column or half) + 0.5) / size
						end
					end
					diag.skip_registered_recapture = true
					diag.source_cut_origin = { cut_u, cut_v }
					diag.registered_bbox_center_normal = seam_anchor
					diag.registered_visual_center_normal = seam_anchor
					diag.registration_error = 0
					diag.registration_ok = true
					side.current_centerline = light_centerline(cl_ok)
					side.current_centerline_node_key = node.key
					side.capture_mode = (side.slot and side.slot.capture_mode) or nil
					side.registration_diag = diag
					side.last_geometry_node_key = node.key
					if side.entity.GetSprite then
						side.sprite = side.entity:GetSprite()
					end
					return true
				end
			end

			-- Registered Entity:Render (successful cache-hit / legacy bbox).
			local ok = render.capture_entity(side.slot, side.entity, capture_opts({
				registration_offset = offset,
				registration_diag = diag,
			}))
			PERF.entity_rt_captures = PERF.entity_rt_captures + 1
			side.capture_mode = (side.slot and side.slot.capture_mode) or nil
			side.registration_diag = diag
			side.last_geometry_node_key = node.key
			if diag and diag.centerline then
				side.current_centerline = light_centerline(diag.centerline)
				side.current_centerline_node_key = node.key
			end

			if ok and diag then
				diag.registered_bbox_center_normal = seam_anchor
				diag.registered_visual_center_normal = seam_anchor
				diag.registration_error = 0
				diag.registration_ok = true
				if not diag.cache_hit then
					diag.registration_verify_skipped = true
				end
			end
			if side.entity.GetSprite then
				side.sprite = side.entity:GetSprite()
			end
			return ok
		end

		side.registration_diag = nil
		side.current_centerline = nil
		local ok, mode = render.capture_entity(side.slot, side.entity, { wrap = wrap })
		PERF.entity_rt_captures = PERF.entity_rt_captures + 1
		side.capture_mode = mode or (side.slot and side.slot.capture_mode) or nil
		if side.entity.GetSprite then
			side.sprite = side.entity:GetSprite()
		end
		return ok
	end
	if side.sprite then
		side.registration_diag = nil
		side.current_centerline = nil
		local ok, mode = render.bake_sprite(side.slot, side.sprite, { draw = side.draw })
		side.capture_mode = mode or (side.slot and side.slot.capture_mode) or nil
		return ok
	end
	return false
end

local function analyze_side(side, cut_normal, policy)
	if not side or not side.slot or not side.slot.image then
		return nil, "missing slot"
	end
	policy = policy or {}
	local state = side.geometry_state or {}
	local analyze_opts = {
		cut_normal = cut_normal,
		keep_sign = side.keep_sign,
		lock_content_center = true,
		collect_candidates = policy.collect_cut_candidates == true,
		previous_ratio = state.cut_ratio,
		sample_step = math.max(1, tonumber(policy.sample_step) or 2),
	}
	if policy.fixed_seam_plane == true then
		analyze_opts.fixed_seam_plane = true
		analyze_opts.seam_normal_anchor = tonumber(policy.seam_normal_anchor) or 0
		analyze_opts.locked_ratio = nil
		local rd = side.registration_diag
		if rd and rd.skip_registered_recapture and rd.source_cut_origin then
			analyze_opts.source_cut_origin = rd.source_cut_origin
			analyze_opts.precomputed_centerline = rd.centerline
		end
	elseif policy.stable_cut and state.cut_ratio ~= nil then
		analyze_opts.locked_ratio = state.cut_ratio
		analyze_opts.collect_candidates = policy.collect_cut_candidates == true or true
	end
	local analysis, err = geometry.analyze_source(side.slot.image, side.slot.size, analyze_opts)
	if not analysis then
		return nil, err
	end

	local prev = state.cut_ratio
	local chosen = analysis.candidate_ratio
	if policy.fixed_seam_plane then
		state.cut_ratio = analysis.seam_normal_anchor or 0
		state.chosen_ratio = state.cut_ratio
		state.locked_ratio_changed = false
		state.best_candidate_changed = false
		state.cut_locked = true
		state.lock_source = "fixed_seam_plane"
	elseif policy.stable_cut then
		if state.cut_ratio == nil and chosen ~= nil then
			state.cut_ratio = chosen
			state.locked_at_frame = Game():GetFrameCount()
			state.lock_source = "first_best_cut"
		end
		chosen = state.cut_ratio or chosen
		state.previous_ratio = prev
		state.chosen_ratio = chosen
		state.would_choose_ratio = analysis.would_choose_ratio or analysis.candidate_ratio
		state.locked_ratio_changed = (prev ~= nil and chosen ~= nil and math.abs(prev - chosen) > 1e-6)
		local would = state.would_choose_ratio
		if would ~= nil and chosen ~= nil then
			state.best_candidate_changed = math.abs(would - chosen) > 1e-6
		else
			state.best_candidate_changed = false
		end
		state.changed = state.locked_ratio_changed
		state.cut_locked = true
	else
		state.previous_ratio = prev
		state.chosen_ratio = chosen
		state.would_choose_ratio = analysis.would_choose_ratio or analysis.candidate_ratio
		state.locked_ratio_changed = (prev ~= nil and chosen ~= nil and math.abs(prev - chosen) > 1e-6)
		state.best_candidate_changed = analysis.cut_changed == true
		state.changed = state.locked_ratio_changed
		state.cut_locked = analysis.cut_locked == true
	end
	state.score = analysis.cut_score
	state.score_margin = analysis.cut_score_margin
	state.cut_candidates = analysis.cut_candidates
	side.geometry_state = state
	return analysis
end

local function clamp_scale(ratio, min_s, max_s)
	ratio = tonumber(ratio) or 1
	min_s = tonumber(min_s) or geometry.MIN_SCALE
	max_s = tonumber(max_s) or geometry.MAX_SCALE
	local clamped, lo, hi = false, false, false
	if ratio < min_s then
		ratio = min_s
		clamped, lo = true, true
	elseif ratio > max_s then
		ratio = max_s
		clamped, hi = true, true
	end
	return ratio, clamped, lo, hi
end

local MAX_POSE_GEOMETRY_CACHE = 256

local function geom_cache_size(pair)
	local order = pair and pair.pose_geometry_cache_order
	return order and #order or 0
end

local function side_node_cache_size(side)
	local order = side and side.geometry_node_order
	return order and #order or 0
end

local function pair_scale_cache_size(pair)
	local order = pair and pair.node_pair_scale_order
	return order and #order or 0
end

local function ensure_body_scale(pair, policy)
	policy = policy or {}
	if tonumber(pair.body_scale) and pair.body_scale > 0 then
		return pair.body_scale
	end
	-- Production: explicit profile visual.body_scale, else 1.0.
	-- Do NOT use avg_vertical_span ratio (geometry hint ≠ body scale).
	local explicit = tonumber(policy.body_scale)
	if explicit and explicit > 0 then
		local scale = select(1, clamp_scale(explicit, policy.min_scale, policy.max_scale))
		pair.body_scale = scale
		pair.body_scale_source = "profile_visual"
		pair.body_scale_diag = { raw_ratio = explicit, scale = scale }
		return scale
	end
	pair.body_scale = 1
	pair.body_scale_source = "default"
	pair.body_scale_diag = { raw_ratio = 1, scale = 1 }
	return 1
end

local function snapshot_side_geometry(analysis, side)
	if not analysis then
		return nil
	end
	local iface = analysis.interface or {}
	local span, src = geometry.choose_interface_span(iface)
	local alpha = analysis.alpha or {}
	local cl = analysis.centerline or {}
	return {
		bbox = analysis.bbox,
		cut_origin = analysis.cut_origin,
		cut_local = analysis.cut_local,
		raw_cut_local = analysis.raw_cut_local,
		seam_normal_anchor = analysis.seam_normal_anchor,
		cut_normal = analysis.cut_normal,
		keep_sign = analysis.keep_sign,
		candidate_ratio = analysis.candidate_ratio,
		band_px = analysis.band_px,
		span_source = analysis.span_source or src,
		interface_confidence = analysis.interface_confidence,
		size = analysis.size,
		sample_step = analysis.sample_step,
		centerline = {
			st = cl.st or cl.centerline_st,
			ed = cl.ed or cl.centerline_ed,
			mid = cl.mid or cl.centerline_mid,
			span = cl.span or cl.centerline_span or span,
			count = cl.count,
			chosen_column = cl.chosen_column,
			sampled_columns = cl.sampled_columns,
			charm_pixels_skipped = cl.charm_pixels_skipped or cl.charm_skipped,
			charm_skipped = cl.charm_skipped or cl.charm_pixels_skipped,
			body_start_y = cl.body_start_y,
			segments = cl.segments,
			selected_segment = cl.selected_segment,
		},
		charm_filter = analysis.charm_filter,
		alpha = {
			centroid_local = alpha.centroid_local,
			bbox_center_local = alpha.bbox_center_local,
			centroid_source = alpha.centroid_source,
			bbox = alpha.bbox or analysis.bbox,
		},
		interface = {
			span_px = span,
			interface_span_px = span,
			keep_span_px = iface.keep_span_px,
			count = iface.count,
			keep_count = iface.keep_count,
			centroid_local = iface.centroid_local or iface.edge_centroid_from_center,
			edge_centroid_from_center = iface.edge_centroid_from_center,
			keep_centroid_from_center = iface.keep_centroid_from_center,
			mode = iface.mode,
			band_px = iface.band_px,
			span_source = src,
			t_min = iface.t_min,
			t_max = iface.t_max,
			range_mid_t = iface.range_mid_t,
			centroid_t = iface.centroid_t,
			centroid_minus_range_mid = iface.centroid_minus_range_mid,
			t_min_px = iface.t_min_px,
			t_max_px = iface.t_max_px,
			range_mid_t_px = iface.range_mid_t_px,
			centroid_t_px = iface.centroid_t_px,
			sample_step = iface.sample_step,
		},
		registration = side and side.registration_diag or nil,
	}
end

local function analysis_from_snapshot(snap)
	if not snap then
		return nil
	end
	local iface = snap.interface or {}
	return {
		bbox = snap.bbox,
		cut_origin = snap.cut_origin,
		cut_local = snap.cut_local,
		raw_cut_local = snap.raw_cut_local,
		seam_normal_anchor = snap.seam_normal_anchor,
		cut_normal = snap.cut_normal,
		keep_sign = snap.keep_sign,
		candidate_ratio = snap.candidate_ratio,
		band_px = snap.band_px,
		span_source = snap.span_source,
		interface_confidence = snap.interface_confidence,
		size = snap.size,
		sample_step = snap.sample_step,
		centerline = snap.centerline,
		charm_filter = snap.charm_filter,
		alpha = snap.alpha,
		interface = {
			span_px = iface.span_px,
			interface_span_px = iface.span_px,
			keep_span_px = iface.keep_span_px,
			count = iface.count,
			keep_count = iface.keep_count,
			centroid_local = iface.centroid_local,
			edge_centroid_from_center = iface.edge_centroid_from_center or iface.centroid_local,
			keep_centroid_from_center = iface.keep_centroid_from_center,
			mode = iface.mode,
			band_px = iface.band_px,
			span_source = snap.span_source,
			t_min = iface.t_min,
			t_max = iface.t_max,
			range_mid_t = iface.range_mid_t,
			centroid_t = iface.centroid_t,
			centroid_minus_range_mid = iface.centroid_minus_range_mid,
			t_min_px = iface.t_min_px,
			t_max_px = iface.t_max_px,
			range_mid_t_px = iface.range_mid_t_px,
			centroid_t_px = iface.centroid_t_px,
			sample_step = iface.sample_step,
		},
		from_pose_cache = true,
	}
end

local function put_pose_geometry(pair, pose_key, entry)
	pair.pose_geometry_cache = pair.pose_geometry_cache or {}
	pair.pose_geometry_cache_order = pair.pose_geometry_cache_order or {}
	if not pair.pose_geometry_cache[pose_key] then
		pair.pose_geometry_cache_order[#pair.pose_geometry_cache_order + 1] = pose_key
		while #pair.pose_geometry_cache_order > MAX_POSE_GEOMETRY_CACHE do
			local old = table.remove(pair.pose_geometry_cache_order, 1)
			if old then
				pair.pose_geometry_cache[old] = nil
			end
		end
	end
	pair.pose_geometry_cache[pose_key] = entry
end

local MAX_SIDE_GEOMETRY_ANALYSIS_CACHE = 256

local function side_analysis_cache_size(side)
	local order = side and side.geometry_analysis_order
	return order and #order or 0
end

local function put_side_geometry_analysis(side, node_key, snap)
	if not side or not node_key or not snap then
		return
	end
	side.geometry_analysis_cache = side.geometry_analysis_cache or {}
	side.geometry_analysis_order = side.geometry_analysis_order or {}
	if not side.geometry_analysis_cache[node_key] then
		side.geometry_analysis_order[#side.geometry_analysis_order + 1] = node_key
		while #side.geometry_analysis_order > MAX_SIDE_GEOMETRY_ANALYSIS_CACHE do
			local old = table.remove(side.geometry_analysis_order, 1)
			if old then
				side.geometry_analysis_cache[old] = nil
			end
		end
	end
	side.geometry_analysis_cache[node_key] = snap
end

local function apply_side_lock_state(side, snap, policy)
	if not side or not (policy.stable_cut or policy.fixed_seam_plane) then
		return
	end
	side.geometry_state = side.geometry_state or {}
	side.geometry_state.cut_ratio = side.geometry_state.cut_ratio
		or (snap and snap.candidate_ratio)
		or (policy.fixed_seam_plane and (tonumber(policy.seam_normal_anchor) or 0))
	side.geometry_state.chosen_ratio = side.geometry_state.cut_ratio
	side.geometry_state.cut_locked = true
	side.geometry_state.locked_ratio_changed = false
end

--- Resolve ignore map from live profile table (authoritative), then side copy.
--- Prefer profile_id so attach-time effect.visual copies cannot silently miss.
local function resolve_ignore_map(side)
	if type(side) ~= "table" then
		return nil, nil
	end
	local kind = side.profile_kind
	local id = side.profile_id
	if type(kind) == "string" and type(id) == "string" then
		local ok, profiles = pcall(require, "Qing_Remaster_scripts.config.runtime_stitch_enemy_profiles")
		if ok and type(profiles) == "table" then
			local p = nil
			if kind == "movement" and profiles.get_movement then
				p = profiles.get_movement(id)
			elseif kind == "attack" and profiles.get_attack then
				p = profiles.get_attack(id)
			elseif profiles.get then
				p = profiles.get(id)
			end
			local map = profiles.ignore_geometry_frames_of and profiles.ignore_geometry_frames_of(p) or nil
			if type(map) ~= "table" and p and type(p.visual) == "table" then
				map = p.visual.ignore_geometry_frames
			end
			if type(map) == "table" then
				return map, "profiles." .. kind .. "." .. id
			end
		end
	end
	if type(side.ignore_geometry_frames) == "table" then
		return side.ignore_geometry_frames, "side.ignore_geometry_frames"
	end
	return nil, nil
end

--- Profile-declared decorative / extreme wing poses: hard-exclude from geometry.
--- Visual sprite still plays; only analysis / NodePair scale reuse last_good.
--- Supports {[frame]=true} or list {frame, frame, ...}.
--- Prefer GeometryNode anim/frame when provided (same identity as the node being solved).
local function geometry_frame_is_ignored(side, spr, geometry_node)
	local map, map_src = resolve_ignore_map(side)
	local anim = ""
	local frame = -1
	if geometry_node and geometry_node.anim ~= nil then
		anim = geometry_node.anim or ""
	elseif spr and spr.GetAnimation then
		anim = spr:GetAnimation() or ""
	end
	if geometry_node and geometry_node.frame ~= nil then
		frame = tonumber(geometry_node.frame)
		if frame == nil then
			frame = -1
		end
	elseif spr and spr.GetFrame then
		frame = tonumber(spr:GetFrame())
		if frame == nil then
			frame = -1
		end
	end
	local diag = {
		profile_id = side and side.profile_id or nil,
		profile_kind = side and side.profile_kind or nil,
		ignore_map_present = type(map) == "table",
		ignore_map_source = map_src,
		ignore_anim_present = false,
		ignore_frame_match = false,
	}
	if type(map) ~= "table" then
		return false, nil, anim, frame, diag
	end
	local anim_map = map[anim]
	diag.ignore_anim_present = type(anim_map) == "table"
	if type(anim_map) ~= "table" then
		return false, nil, anim, frame, diag
	end
	if anim_map[frame] == true then
		diag.ignore_frame_match = true
		return true, "profile.ignore_geometry_frames", anim, frame, diag
	end
	-- Also accept numeric string keys if a profile was authored that way.
	if anim_map[tostring(frame)] == true then
		diag.ignore_frame_match = true
		return true, "profile.ignore_geometry_frames", anim, frame, diag
	end
	for i = 1, #anim_map do
		if anim_map[i] == frame then
			diag.ignore_frame_match = true
			return true, "profile.ignore_geometry_frames", anim, frame, diag
		end
	end
	return false, nil, anim, frame, diag
end

local function last_good_span_mid(side)
	local snap = side and side.last_good_geometry_analysis
	local cl = snap and snap.centerline or nil
	return cl and cl.span or nil, cl and cl.mid or nil
end

local function remember_last_good(side, node_key, analysis)
	-- Only call for NON-IGNORED frames. Boundary startup fallbacks must not become last_good.
	if not side or not analysis then
		return
	end
	side.last_good_geometry_analysis = snapshot_side_geometry(analysis, side)
	side.last_good_geometry_node_key = node_key
end

--- Resolve geometry analysis for ONE side keyed by GeometryNode.
--- Never re-analyzes because a NodePair combination is new.
local function resolve_side_analysis(side, geometry_node, cut_normal, policy)
	if not side then
		return nil, false, "missing side"
	end
	local node_key = geometry_node and geometry_node.key or "?"
	local spr = live_sprite_of(side)
	local ignored, ignore_src, anim, frame, ignore_diag =
		geometry_frame_is_ignored(side, spr, geometry_node)
	local good_span, good_mid = last_good_span_mid(side)
	ignore_diag = ignore_diag or {}
	side.geometry_frame_filter = {
		anim = anim or (geometry_node and geometry_node.anim),
		frame = frame or (geometry_node and geometry_node.frame),
		geometry_frame_ignored = ignored == true,
		ignore_source = ignore_src,
		profile_id = ignore_diag.profile_id or (side and side.profile_id),
		profile_kind = ignore_diag.profile_kind or (side and side.profile_kind),
		ignore_map_present = ignore_diag.ignore_map_present == true,
		ignore_map_source = ignore_diag.ignore_map_source,
		ignore_anim_present = ignore_diag.ignore_anim_present == true,
		ignore_frame_match = ignore_diag.ignore_frame_match == true,
		current_geometry_node_key = node_key,
		geometry_used_node_key = nil,
		geometry_source = nil,
		last_good_span = good_span,
		last_good_mid = good_mid,
		last_good_geometry_node_key = side.last_good_geometry_node_key,
	}

	-- Ignored decorative frame: freeze full seam geometry (span/mid/interface), not scale-only.
	if ignored and side.last_good_geometry_analysis then
		local analysis = analysis_from_snapshot(side.last_good_geometry_analysis)
		side.analysis = analysis
		local used_key = side.last_good_geometry_node_key or node_key
		side.last_geometry_node_key = used_key
		side.geometry_frame_filter.geometry_used_node_key = used_key
		side.geometry_frame_filter.geometry_source = "profile_frame_filter"
		apply_side_lock_state(side, side.last_good_geometry_analysis, policy)
		return analysis, true, nil
	end

	side.geometry_analysis_cache = side.geometry_analysis_cache or {}
	side.geometry_analysis_order = side.geometry_analysis_order or {}
	local use_cache = policy.geometry_node_cache ~= false
	local cached = use_cache and side.geometry_analysis_cache[node_key] or nil
	if cached then
		local analysis = analysis_from_snapshot(cached)
		side.analysis = analysis
		side.last_geometry_node_key = node_key
		side.geometry_frame_filter.geometry_used_node_key = node_key
		side.geometry_frame_filter.geometry_source = ignored and "boundary_startup_fallback_cache"
			or "geometry_node_cache"
		apply_side_lock_state(side, cached, policy)
		-- Only a NON-IGNORED frame may become last_good.
		if not ignored then
			remember_last_good(side, node_key, analysis)
			side.geometry_frame_filter.last_good_span, side.geometry_frame_filter.last_good_mid =
				last_good_span_mid(side)
			side.geometry_frame_filter.last_good_geometry_node_key = side.last_good_geometry_node_key
		end
		return analysis, true, nil
	end
	local analysis, err = analyze_side(side, cut_normal, policy)
	if not analysis then
		return nil, false, err or "analyze_side failed"
	end
	side.analysis = analysis
	side.last_geometry_node_key = node_key
	side.geometry_frame_filter.geometry_used_node_key = node_key
	-- Ignored + no last_good: measure once so this frame can render, but do NOT
	-- register it as last_good (boundary startup fallback is temporary).
	side.geometry_frame_filter.geometry_source = ignored and "boundary_startup_fallback"
		or "geometry_node_measure"
	-- Do not cache ignored/boundary analyses as GeometryNode entries; they are
	-- temporary until a NON-IGNORED frame establishes last_good.
	if use_cache and not ignored then
		put_side_geometry_analysis(side, node_key, snapshot_side_geometry(analysis, side))
	end
	if not ignored then
		remember_last_good(side, node_key, analysis)
		side.geometry_frame_filter.last_good_span, side.geometry_frame_filter.last_good_mid =
			last_good_span_mid(side)
		side.geometry_frame_filter.last_good_geometry_node_key = side.last_good_geometry_node_key
	end
	return analysis, false, nil
end

local function resolve_pose_analyses(pair, policy)
	local host_spr = live_sprite_of(pair.host)
	local donor_spr = live_sprite_of(pair.donor)
	local host_node = render.get_geometry_node_info(host_spr)
	local donor_node = render.get_geometry_node_info(donor_spr)
	local host_info = render.get_pose_info(host_spr)
	local donor_info = render.get_pose_info(donor_spr)
	pair.current_host_geometry_node = host_node
	pair.current_donor_geometry_node = donor_node

	local host_a, host_hit, herr = resolve_side_analysis(pair.host, host_node, pair.cut_normal, policy)
	if not host_a then
		return nil, nil, nil, herr or "host analyze failed"
	end
	local donor_a, donor_hit, derr = resolve_side_analysis(pair.donor, donor_node, pair.cut_normal, policy)
	if not donor_a then
		return nil, nil, nil, derr or "donor analyze failed"
	end

	-- NodePair / pose key must use geometry-used keys (last_good when frame filtered),
	-- so ignored wing frames do not create/update a new scale entry.
	local host_used = (pair.host.geometry_frame_filter and pair.host.geometry_frame_filter.geometry_used_node_key)
		or host_node.key
	local donor_used = (pair.donor.geometry_frame_filter and pair.donor.geometry_frame_filter.geometry_used_node_key)
		or donor_node.key
	local pose_key = host_used .. "||" .. donor_used
	pair.current_pose_key = pose_key

	local host_filt = pair.host.geometry_frame_filter
	local donor_filt = pair.donor.geometry_frame_filter
	local any_filter = (host_filt and host_filt.geometry_source == "profile_frame_filter")
		or (donor_filt and donor_filt.geometry_source == "profile_frame_filter")
	pair.last_pose_geom_diag = {
		pose_key = pose_key,
		host_pose = host_info,
		donor_pose = donor_info,
		host_geometry_node_key = host_used,
		donor_geometry_node_key = donor_used,
		host_current_geometry_node_key = host_node.key,
		donor_current_geometry_node_key = donor_node.key,
		cache_hit = host_hit and donor_hit,
		host_geometry_node_hit = host_hit == true,
		donor_geometry_node_hit = donor_hit == true,
		host_geometry_analysis_cache_size = side_analysis_cache_size(pair.host),
		donor_geometry_analysis_cache_size = side_analysis_cache_size(pair.donor),
		cache_size = side_analysis_cache_size(pair.host) + side_analysis_cache_size(pair.donor),
		source = any_filter and "profile_frame_filter"
			or ((host_hit and donor_hit) and "side_geometry_node_cache" or "side_geometry_node_measure"),
		host_geometry_frame_filter = host_filt,
		donor_geometry_frame_filter = donor_filt,
	}
	return host_a, donor_a, pair.last_pose_geom_diag
end

local function resolve_node_pair_scale(pair, policy, host_a, donor_a, pose_diag)
	policy = policy or {}
	if policy.node_pair_scale ~= true then
		return nil
	end
	pair.node_pair_scale_cache = pair.node_pair_scale_cache or {}
	pair.node_pair_scale_order = pair.node_pair_scale_order or {}
	local host_key = (pose_diag and pose_diag.host_geometry_node_key)
		or (pair.current_host_geometry_node and pair.current_host_geometry_node.key)
		or "?"
	local donor_key = (pose_diag and pose_diag.donor_geometry_node_key)
		or (pair.current_donor_geometry_node and pair.current_donor_geometry_node.key)
		or "?"
	local host_prof = side_source_id(pair.host)
	local donor_prof = side_source_id(pair.donor)
	local body = tonumber(policy.body_scale) or tonumber(pair.body_scale) or 1
	local ver = tostring(render.GEOMETRY_CACHE_VERSION or 0)
	-- Global key: profiles + nodes + body_scale + version — never entity ptr / Position.
	local pair_key = table.concat({
		host_prof,
		donor_prof,
		tostring(host_key),
		tostring(donor_key),
		string.format("%.4f", body),
		ver,
	}, "|")
	local local_pair_key = host_key .. "||" .. donor_key
	local cached = GLOBAL_NODE_PAIR_SCALE_CACHE[pair_key]
		or pair.node_pair_scale_cache[local_pair_key]
	if cached and tonumber(cached.scale) then
		return {
			scale = cached.scale,
			raw_interface_ratio = cached.raw_interface_ratio,
			filtered_span_ratio = cached.filtered_span_ratio or cached.raw_interface_ratio,
			raw_span_ratio = cached.raw_span_ratio,
			cache_hit = true,
			node_pair_key = pair_key,
			host_geometry_node_key = host_key,
			donor_geometry_node_key = donor_key,
			clamped = cached.clamped,
			clamped_lo = cached.clamped_lo,
			clamped_hi = cached.clamped_hi,
		}
	end

	local hi = host_a and host_a.interface or {}
	local di = donor_a and donor_a.interface or {}
	local hs = tonumber(host_a and host_a.centerline and host_a.centerline.span)
		or tonumber(host_a and host_a.centerline and host_a.centerline.centerline_span)
	local ds = tonumber(donor_a and donor_a.centerline and donor_a.centerline.span)
		or tonumber(donor_a and donor_a.centerline and donor_a.centerline.centerline_span)
	local hs_src, ds_src = "interface", "interface"
	if not hs or hs <= 0 then
		hs, hs_src = geometry.choose_interface_span(hi)
	end
	if not ds or ds <= 0 then
		ds, ds_src = geometry.choose_interface_span(di)
	end
	local filtered_ratio = nil
	if hs and ds and hs >= geometry.MIN_VALID_INTERFACE_SPAN and ds >= geometry.MIN_VALID_INTERFACE_SPAN
		and hs_src == "interface" and ds_src == "interface"
	then
		filtered_ratio = hs / ds
	end
	local raw_span_ratio = nil -- probe-only; production centerline path does not compute raw
	local base = tonumber(policy.body_scale) or 1
	-- Production scale uses filtered (charm-sanitized) interface spans only.
	local ratio = (filtered_ratio or 1) * base
	local scale, clamped, lo, hi_c = clamp_scale(ratio, policy.min_scale, policy.max_scale)
	local entry = {
		scale = scale,
		raw_interface_ratio = filtered_ratio,
		filtered_span_ratio = filtered_ratio,
		raw_span_ratio = raw_span_ratio,
		clamped = clamped,
		clamped_lo = lo,
		clamped_hi = hi_c,
		host_span = hs,
		donor_span = ds,
		created_frame = Game():GetFrameCount(),
	}
	put_global_lru(
		GLOBAL_NODE_PAIR_SCALE_CACHE,
		GLOBAL_NODE_PAIR_SCALE_ORDER,
		pair_key,
		entry,
		GLOBAL_CACHE_MAX
	)
	if not pair.node_pair_scale_cache[local_pair_key] then
		pair.node_pair_scale_order[#pair.node_pair_scale_order + 1] = local_pair_key
		while #pair.node_pair_scale_order > 1024 do
			local old = table.remove(pair.node_pair_scale_order, 1)
			if old then
				pair.node_pair_scale_cache[old] = nil
			end
		end
	end
	pair.node_pair_scale_cache[local_pair_key] = entry
	return {
		scale = scale,
		raw_interface_ratio = filtered_ratio,
		filtered_span_ratio = filtered_ratio,
		raw_span_ratio = raw_span_ratio,
		cache_hit = false,
		node_pair_key = pair_key,
		host_geometry_node_key = host_key,
		donor_geometry_node_key = donor_key,
		clamped = clamped,
		clamped_lo = lo,
		clamped_hi = hi_c,
	}
end

local function solve_geometry(pair)
	local policy = pair.geometry_policy or {}
	local production = policy.fixed_body_scale == true
		or policy.fixed_seam_plane == true
		or policy.pose_geometry_cache == true
		or policy.geometry_node_cache == true
		or policy.node_pair_scale == true
		or policy.silhouette_axis_registration == true
		or policy.visual_center_registration == true

	local host_a, donor_a, pose_diag, err
	if production then
		host_a, donor_a, pose_diag, err = resolve_pose_analyses(pair, policy)
		if not host_a then
			pair.last_error = err or "pose analyze failed"
			return false
		end
	else
		host_a, err = analyze_side(pair.host, pair.cut_normal, policy)
		if not host_a then
			pair.last_error = err or "host analyze failed"
			return false
		end
		donor_a, err = analyze_side(pair.donor, pair.cut_normal, policy)
		if not donor_a then
			pair.last_error = err or "donor analyze failed"
			return false
		end
		pair.host.analysis = host_a
		pair.donor.analysis = donor_a
	end

	local solve_opts = {
		cut_normal = pair.cut_normal,
		host_reference_span = pair.host.reference_span,
		donor_reference_span = pair.donor.reference_span,
		base_scale = 1,
		min_scale = policy.min_scale,
		max_scale = policy.max_scale,
		tangent_align = policy.tangent_align or "range_mid",
	}

	local scale_diag = nil
	if policy.node_pair_scale == true then
		scale_diag = resolve_node_pair_scale(pair, policy, host_a, donor_a, pose_diag)
		if scale_diag and scale_diag.scale then
			solve_opts.locked_scale = scale_diag.scale
			pair.body_scale = scale_diag.scale
			pair.body_scale_source = scale_diag.cache_hit and "node_pair_cache" or "node_pair"
			pair.body_scale_diag = scale_diag
		end
	elseif production or policy.fixed_body_scale then
		local body = ensure_body_scale(pair, policy)
		solve_opts.body_scale = body
	elseif policy.scale_mode == "reference_only" then
		solve_opts.frame_weight = 0
		solve_opts.reference_weight = 1
		solve_opts.frame_weight_degraded = 0
		solve_opts.reference_weight_degraded = 1
	end

	local solution, serr = geometry.solve_pair(host_a, donor_a, solve_opts)
	if not solution then
		pair.last_error = serr or "solve_pair failed"
		return false
	end
	if solution.diagnostics then
		solution.diagnostics.body_scale = pair.body_scale
		solution.diagnostics.body_scale_source = pair.body_scale_source or "default"
		if pose_diag then
			solution.diagnostics.pose_key = pose_diag.pose_key
			solution.diagnostics.pose_geometry_cache_hit = pose_diag.cache_hit
			solution.diagnostics.pose_geometry_cache_size = pose_diag.cache_size
			solution.diagnostics.pose_geometry_source = pose_diag.source
			solution.diagnostics.host_geometry_node_key = pose_diag.host_geometry_node_key
			solution.diagnostics.donor_geometry_node_key = pose_diag.donor_geometry_node_key
		end
		if scale_diag then
			solution.diagnostics.node_pair_key = scale_diag.node_pair_key
			solution.diagnostics.raw_interface_ratio = scale_diag.raw_interface_ratio
			solution.diagnostics.filtered_span_ratio = scale_diag.filtered_span_ratio
			solution.diagnostics.raw_span_ratio = scale_diag.raw_span_ratio
			solution.diagnostics.cached_pair_scale = scale_diag.scale
			solution.diagnostics.scale_cache_hit = scale_diag.cache_hit
			solution.diagnostics.clamped = scale_diag.clamped
			solution.diagnostics.clamped_lo = scale_diag.clamped_lo
			solution.diagnostics.clamped_hi = scale_diag.clamped_hi
		end
	end
	pair.solution = solution
	pair.dirty.geometry = false
	pair.last_geometry_trace = M.build_geometry_trace(pair)
	return true
end

--- Invalidate locked cut ratios and pose geometry cache (attach / Morph / explicit reset).
function M.invalidate_geometry(pair, reason)
	if not pair then
		return
	end
	if pair.host then
		pair.host.geometry_state = nil
		pair.host.analysis = nil
	end
	if pair.donor then
		pair.donor.geometry_state = nil
		pair.donor.analysis = nil
	end
	pair.pose_geometry_cache = {}
	pair.pose_geometry_cache_order = {}
	pair.node_pair_scale_cache = {}
	pair.node_pair_scale_order = {}
	pair.body_scale = nil
	pair.body_scale_source = nil
	pair.body_scale_diag = nil
	pair.current_pose_key = nil
	pair.last_pose_geom_diag = nil
	if pair.host then
		pair.host.pose_registration_cache = {}
		pair.host.pose_registration_order = {}
		pair.host.geometry_node_cache = {}
		pair.host.geometry_node_order = {}
		pair.host.geometry_analysis_cache = {}
		pair.host.geometry_analysis_order = {}
		pair.host.last_geometry_node_key = nil
		pair.host.last_good_geometry_analysis = nil
		pair.host.last_good_geometry_node_key = nil
		pair.host.geometry_frame_filter = nil
	end
	if pair.donor then
		pair.donor.pose_registration_cache = {}
		pair.donor.pose_registration_order = {}
		pair.donor.geometry_node_cache = {}
		pair.donor.geometry_node_order = {}
		pair.donor.geometry_analysis_cache = {}
		pair.donor.geometry_analysis_order = {}
		pair.donor.last_geometry_node_key = nil
		pair.donor.last_good_geometry_analysis = nil
		pair.donor.last_good_geometry_node_key = nil
		pair.donor.geometry_frame_filter = nil
	end
	pair.solution = nil
	pair.dirty.geometry = true
	pair.geometry_invalidate_reason = reason or "manual"
end

local function side_trace(side, name)
	if not side then
		return nil
	end
	local ent = side.entity
	local spr = live_sprite_of(side)
	local a = side.analysis or {}
	local iface = a.interface or {}
	local st = side.geometry_state or {}
	local reg = side.registration_diag or {}
	local alpha = a.alpha or {}
	local bbox = a.bbox or alpha.bbox
	local po = ent and ent.PositionOffset
	local bbc = alpha.bbox_center_local
	local acc = alpha.centroid_local
	local node_info = nil
	if spr then
		local ok_n, n = pcall(function()
			return require("Qing_Remaster_scripts.auxiliary.sprite_splice_render").get_geometry_node_info(spr)
		end)
		if ok_n then
			node_info = n
		end
	end
	local out = {
		side = name,
		type = ent and ent.Type or nil,
		variant = ent and ent.Variant or nil,
		subtype = ent and ent.SubType or nil,
		anim = spr and spr:GetAnimation() or nil,
		sprite_frame = spr and spr:GetFrame() or nil,
		overlay = spr and spr.GetOverlayAnimation and spr:GetOverlayAnimation() or nil,
		overlay_frame = spr and spr.GetOverlayFrame and spr:GetOverlayFrame() or nil,
		flip_x = node_info and node_info.flip_x or (spr and spr.FlipX and 1 or 0),
		crop_key = node_info and node_info.crop_key or nil,
		profile_id = side.profile_id,
		profile_kind = side.profile_kind,
		position_offset = po and { x = po.X, y = po.Y } or nil,
		sample_step = a.sample_step,
		bbox = bbox and {
			minx = bbox.minx,
			maxx = bbox.maxx,
			miny = bbox.miny,
			maxy = bbox.maxy,
			center_x = bbc and bbc[1] or (bbox.minx and ((bbox.minx + bbox.maxx + 1) * 0.5 - (a.size or 128) * 0.5)),
			center_y = bbc and bbc[2] or (bbox.miny and ((bbox.miny + bbox.maxy + 1) * 0.5 - (a.size or 128) * 0.5)),
			top = bbox.miny,
			bottom = bbox.maxy,
		} or nil,
		raw_bbox = a.raw_bbox and {
			minx = a.raw_bbox.minx,
			maxx = a.raw_bbox.maxx,
			miny = a.raw_bbox.miny,
			maxy = a.raw_bbox.maxy,
			top = a.raw_bbox.miny,
			bottom = a.raw_bbox.maxy,
		} or nil,
		filtered_bbox = a.filtered_bbox and {
			minx = a.filtered_bbox.minx,
			maxx = a.filtered_bbox.maxx,
			miny = a.filtered_bbox.miny,
			maxy = a.filtered_bbox.maxy,
			top = a.filtered_bbox.miny,
			bottom = a.filtered_bbox.maxy,
		} or (bbox and {
			minx = bbox.minx,
			maxx = bbox.maxx,
			miny = bbox.miny,
			maxy = bbox.maxy,
			top = bbox.miny,
			bottom = bbox.maxy,
		}) or nil,
		charm_filter = a.charm_filter,
		raw_interface_span = a.raw_interface_span,
		filtered_interface_span = a.filtered_interface_span or iface.span_px or iface.interface_span_px,
		centerline = a.centerline,
		alpha = {
			centroid_x = acc and acc[1] or nil,
			centroid_y = acc and acc[2] or nil,
			source = alpha.centroid_source,
			centroid_minus_bbox_center_x = (acc and bbc) and (acc[1] - bbc[1]) or nil,
			centroid_minus_bbox_center_y = (acc and bbc) and (acc[2] - bbc[2]) or nil,
		},
		cut_ratio = st.chosen_ratio or a.candidate_ratio,
		previous_ratio = st.previous_ratio,
		would_choose_ratio = st.would_choose_ratio,
		locked_ratio_changed = st.locked_ratio_changed,
		best_candidate_changed = st.best_candidate_changed,
		cut_changed = st.locked_ratio_changed,
		cut_locked = st.cut_locked,
		cut_local = a.cut_local,
		raw_cut_local = a.raw_cut_local,
		seam_normal_anchor = a.seam_normal_anchor,
		cut_origin = a.cut_origin,
		interface_span = iface.span_px or iface.interface_span_px,
		interface_count = iface.count,
		keep_span = iface.keep_span_px,
		span_source = iface.span_source or a.span_source,
		interface_centroid = iface.centroid_local or iface.edge_centroid_from_center,
		interface = {
			t_min = iface.t_min,
			t_max = iface.t_max,
			range_mid_t = iface.range_mid_t,
			centroid_t = iface.centroid_t,
			centroid_minus_range_mid = iface.centroid_minus_range_mid,
			t_min_px = iface.t_min_px,
			t_max_px = iface.t_max_px,
			range_mid_t_px = iface.range_mid_t_px,
			centroid_t_px = iface.centroid_t_px,
			count = iface.count,
			sample_step = iface.sample_step,
		},
		band_px = a.band_px or iface.band_px,
		score = st.score or a.cut_score,
		score_margin = st.score_margin or a.cut_score_margin,
		cut_candidates = st.cut_candidates or a.cut_candidates,
		registration = {
			source = reg.source,
			ok = reg.ok,
			registration_ok = reg.registration_ok,
			geometry_node_key = reg.geometry_node_key,
			cache_hit = reg.cache_hit,
			pose_registration_cache = reg.pose_registration_cache,
			transform_delta_normal = reg.transform_delta_normal,
			pose_key = reg.pose_key,
			sample_step = reg.sample_step,
			registration_measure = reg.registration_measure or reg.chosen_registration_center_source,
			chosen_registration_center_source = reg.chosen_registration_center_source,
			raw_visual_center = reg.raw_visual_center,
			raw_visual_center_normal = reg.raw_visual_center_normal,
			raw_bbox_center = reg.raw_bbox_center,
			raw_bbox_center_normal = reg.raw_bbox_center_normal or reg.raw_visual_center_normal,
			alpha_centroid_normal = reg.alpha_centroid_normal,
			registered_visual_center = reg.registered_visual_center,
			registered_visual_center_normal = reg.registered_visual_center_normal,
			registered_bbox_center = reg.registered_bbox_center,
			registered_bbox_center_normal = reg.registered_bbox_center_normal
				or reg.registered_visual_center_normal,
			expected_registered_normal = reg.expected_registered_normal,
			registration_error = reg.registration_error,
			registration_normal = reg.registration_normal,
			registration = reg.registration,
			seam_normal_anchor = reg.seam_normal_anchor,
			bbox_center_local = reg.bbox_center_local,
			alpha_centroid_local = reg.alpha_centroid_local,
			geometry_cache_version = reg.geometry_cache_version,
			common = reg.common,
			normal_delta = reg.normal_delta,
			samples = reg.samples,
			sample_count = reg.sample_count,
		},
		capture_mode = side.capture_mode,
		geometry_node_cache_size = side_node_cache_size(side),
		last_geometry_node_key = side.last_geometry_node_key,
		geometry_frame_filter = side.geometry_frame_filter,
		last_good_geometry_node_key = side.last_good_geometry_node_key,
		entity_flags = (function()
			local ent = side.entity
			if not ent or not ent.Exists or not ent:Exists() or not ent.HasEntityFlags then
				return nil
			end
			local friendly, charm = false, false
			pcall(function()
				friendly = ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) == true
				charm = ent:HasEntityFlags(EntityFlag.FLAG_CHARM) == true
			end)
			return { friendly = friendly, charm = charm }
		end)(),
	}
	return out
end

--- Full per-frame geometry trace for probes.
function M.build_geometry_trace(pair)
	if not pair then
		return nil
	end
	local sol = pair.solution
	local diag = sol and sol.diagnostics or {}
	local host_off = sol and sol.donor and sol.donor.offset_local or nil
	return {
		frame = Game():GetFrameCount(),
		isaac_frame = Isaac.GetFrameCount and Isaac.GetFrameCount() or nil,
		policy = pair.geometry_policy,
		host = side_trace(pair.host, "host"),
		donor = side_trace(pair.donor, "donor"),
		scale = {
			body_scale = pair.body_scale,
			body_scale_source = pair.body_scale_source or (pair.body_scale_diag and "geometry_prior"),
			body_scale_diag = pair.body_scale_diag,
			final_ratio = pair.body_scale or diag.final_ratio,
			reference_ratio = diag.reference_ratio,
			would_be_interface_ratio = diag.would_be_ratio or diag.frame_ratio or diag.raw_interface_ratio,
			frame_ratio = diag.frame_ratio,
			raw_interface_ratio = diag.raw_interface_ratio,
			filtered_span_ratio = (pair.body_scale_diag and pair.body_scale_diag.filtered_span_ratio)
				or diag.filtered_span_ratio
				or diag.raw_interface_ratio,
			raw_span_ratio = (pair.body_scale_diag and pair.body_scale_diag.raw_span_ratio)
				or diag.raw_span_ratio,
			cached_pair_scale = diag.cached_pair_scale or pair.body_scale,
			scale_cache_hit = diag.scale_cache_hit,
			node_pair_key = diag.node_pair_key,
			host_geometry_node_key = diag.host_geometry_node_key
				or (pair.current_host_geometry_node and pair.current_host_geometry_node.key),
			donor_geometry_node_key = diag.donor_geometry_node_key
				or (pair.current_donor_geometry_node and pair.current_donor_geometry_node.key),
			clamped = diag.clamped or (pair.body_scale_diag and pair.body_scale_diag.clamped),
			clamped_lo = diag.clamped_lo or (pair.body_scale_diag and pair.body_scale_diag.clamped_lo),
			clamped_hi = diag.clamped_hi or (pair.body_scale_diag and pair.body_scale_diag.clamped_hi),
			min_scale = diag.min_scale or (pair.geometry_policy and pair.geometry_policy.min_scale),
			max_scale = diag.max_scale or (pair.geometry_policy and pair.geometry_policy.max_scale),
			blend_span_source = diag.blend_span_source,
			host_ref_span = (pair.body_scale_diag and pair.body_scale_diag.host_ref_span) or diag.host_ref_span,
			donor_ref_span = (pair.body_scale_diag and pair.body_scale_diag.donor_ref_span) or diag.donor_ref_span,
			pose_key = (pair.last_pose_geom_diag and pair.last_pose_geom_diag.pose_key) or pair.current_pose_key,
			host_pose = pair.last_pose_geom_diag and pair.last_pose_geom_diag.host_pose,
			donor_pose = pair.last_pose_geom_diag and pair.last_pose_geom_diag.donor_pose,
			pose_geometry_cache_hit = pair.last_pose_geom_diag and pair.last_pose_geom_diag.cache_hit,
			pose_geometry_cache_size = pair.last_pose_geom_diag and pair.last_pose_geom_diag.cache_size
				or geom_cache_size(pair),
			pose_geometry_source = pair.last_pose_geom_diag and pair.last_pose_geom_diag.source,
			host_geometry_node_hit = pair.last_pose_geom_diag and pair.last_pose_geom_diag.host_geometry_node_hit,
			donor_geometry_node_hit = pair.last_pose_geom_diag and pair.last_pose_geom_diag.donor_geometry_node_hit,
			host_geometry_analysis_cache_size = pair.last_pose_geom_diag
				and pair.last_pose_geom_diag.host_geometry_analysis_cache_size
				or side_analysis_cache_size(pair.host),
			donor_geometry_analysis_cache_size = pair.last_pose_geom_diag
				and pair.last_pose_geom_diag.donor_geometry_analysis_cache_size
				or side_analysis_cache_size(pair.donor),
			host_geometry_node_cache_size = side_node_cache_size(pair.host),
			donor_geometry_node_cache_size = side_node_cache_size(pair.donor),
			node_pair_scale_cache_size = pair_scale_cache_size(pair),
			geometry_cache_version = render.GEOMETRY_CACHE_VERSION,
			source = pair.body_scale_source or diag.blend_span_source,
		},
		perf = (function()
			local gp = geometry.get_perf_counters and geometry.get_perf_counters() or {}
			local pd = pair.last_pose_geom_diag or {}
			return {
				geometry_cache_version = render.GEOMETRY_CACHE_VERSION,
				pose_geometry_cache_size = geom_cache_size(pair),
				host_geometry_node_cache_size = side_node_cache_size(pair.host),
				donor_geometry_node_cache_size = side_node_cache_size(pair.donor),
				host_geometry_analysis_cache_size = side_analysis_cache_size(pair.host),
				donor_geometry_analysis_cache_size = side_analysis_cache_size(pair.donor),
				node_pair_scale_cache_size = pair_scale_cache_size(pair),
				pose_geometry_cache_hit = pd.cache_hit,
				host_geometry_node_hit = pd.host_geometry_node_hit,
				donor_geometry_node_hit = pd.donor_geometry_node_hit,
				scale_cache_hit = diag.scale_cache_hit,
				get_texel_region = gp.get_texel_region,
				centerline_scans = gp.centerline_scans,
				decoded_texels = gp.decoded_texels,
				charm_rgb_tests = gp.charm_rgb_tests,
				full_alpha_scans = gp.full_alpha_scans,
				interface_scans = gp.interface_scans,
			}
		end)(),
		solution = sol and {
			host_cut_local = sol.host and sol.host.cut_local,
			donor_cut_local = sol.donor and sol.donor.cut_local,
			donor_scale = sol.donor and sol.donor.scale,
			donor_offset_local = host_off,
			tangent_slide = diag.tangent_slide,
			normal_residual = diag.normal_residual,
			chosen_tangent_source = diag.chosen_tangent_source,
			host_interface_t = diag.host_interface_t,
			donor_interface_t = diag.donor_interface_t,
			host_cut_ratio = diag.host_candidate_ratio,
			donor_cut_ratio = diag.donor_candidate_ratio,
			seam_tangent_scale = 1,
			seam_normal_scale = 1,
		} or nil,
	}
end

function M.get_geometry_trace(pair)
	if not pair then
		return nil
	end
	return pair.last_geometry_trace or M.build_geometry_trace(pair)
end

--- Advance capture + geometry.
--- opts.force_entity_capture: always Entity:Render (escape hatch for create/debug).
---   Default FALSE — production dirty-keys on sprite_frame_key; Position does not dirty.
--- opts.skip_entity_capture: keep existing RT; do not Entity:Render (water REFRACT/REFLECT).
--- opts.skip_geometry_solve / disable_geometry_refresh: reuse solution if present.
--- Live entity path: capture only when capture_visual_key changes (or force / no image).
--- GeometryNode key change sets pair.dirty.geometry (independent of capture).
--- Sprite-only path: bake only when visual key dirty (UI).
function M.update(pair, opts)
	opts = opts or {}
	if not pair then
		return false
	end
	local host_is_ent = pair.host and pair.host.entity ~= nil
	local donor_is_ent = pair.donor and pair.donor.entity ~= nil
	local live = host_is_ent or donor_is_ent
	local force_ent = opts.force_entity_capture
	if force_ent == nil then
		-- Production live default: dirty-key only. create() passes true explicitly.
		force_ent = false
	end
	local skip_ent_capture = opts.skip_entity_capture == true
	local skip_geom = opts.skip_geometry_solve == true
		or opts.disable_geometry_refresh == true

	pair.last_update_frame = Game():GetFrameCount()

	local cut_n = pair.cut_normal or { 1, 0 }
	local policy = pair.geometry_policy or {}

	local function refresh_live_side(side, is_ent, bake_flag, err_label)
		if is_ent then
			local spr = live_sprite_of(side)
			local capture_visual_key = render.sprite_frame_key(spr)
			local node = render.get_geometry_node_info(spr)
			local node_key = node.key
			-- GeometryNode change dirties geometry solve (not capture by itself).
			if side.geometry_node_key ~= node_key then
				side.geometry_node_key = node_key
				pair.dirty.geometry = true
			end
			local need_capture = force_ent
				or not (side.slot and side.slot.image)
				or side.capture_visual_key ~= capture_visual_key
			if need_capture then
				if skip_ent_capture then
					-- Water under/reflect: consume existing RT; never capture native water pass.
					if not (side.slot and side.slot.image) then
						pair.last_error = err_label .. " no RT for water-pass skip_entity_capture"
						return false
					end
					-- Do not update capture_visual_key — NORMAL/ABOVE will recapture if dirty.
				else
					if not capture_side(side, pair.capture_wrap, cut_n, pair, policy) then
						pair.last_error = render.get_last_error()
							or (err_label .. " entity capture failed")
						return false
					end
					side.capture_visual_key = capture_visual_key
				end
			end
			if side.visual_key ~= node_key then
				side.visual_key = node_key
				pair.dirty.geometry = true
			end
			pair.dirty[bake_flag] = false
			return true
		elseif pair.dirty[bake_flag] then
			if skip_ent_capture then
				pair.last_error = err_label .. " bake blocked by skip_entity_capture"
				return false
			end
			if not capture_side(side, pair.capture_wrap, cut_n, pair, policy) then
				pair.last_error = render.get_last_error() or (err_label .. " bake failed")
				return false
			end
			side.visual_key = render.get_geometry_node_info(live_sprite_of(side)).key
			side.capture_visual_key = render.sprite_frame_key(live_sprite_of(side))
			pair.dirty[bake_flag] = false
			pair.dirty.geometry = true
		end
		return true
	end

	if live then
		if not refresh_live_side(pair.host, host_is_ent, "host_bake", "host") then
			return false
		end
		if not refresh_live_side(pair.donor, donor_is_ent, "donor_bake", "donor") then
			return false
		end

		-- Centerline-only production: scan miss keeps prior solution; do not re-solve.
		if policy_centerline_only(policy) then
			local host_scan_ok = side_centerline_ok(pair.host)
			local donor_scan_ok = side_centerline_ok(pair.donor)
			if not host_scan_ok or not donor_scan_ok then
				pair.dirty.geometry = false
				pair.last_geometry_trace = M.build_geometry_trace(pair)
				return true
			end
		end

		if skip_geom and pair.solution then
			PERF.pair_solution_cache_hits = PERF.pair_solution_cache_hits + 1
			pair.last_geometry_trace = M.build_geometry_trace(pair)
			return true
		end
		if pair.dirty.geometry or not pair.solution then
			PERF.pair_solution_cache_misses = PERF.pair_solution_cache_misses + 1
			return solve_geometry(pair)
		end
		PERF.pair_solution_cache_hits = PERF.pair_solution_cache_hits + 1
		-- Same GeometryNode: refresh presentation trace registration fields only.
		pair.last_geometry_trace = M.build_geometry_trace(pair)
		return true
	end

	-- Sprite / UI path: dirty-key bake.
	local host_key = render.sprite_frame_key(live_sprite_of(pair.host))
	local donor_key = render.sprite_frame_key(live_sprite_of(pair.donor))
	if host_key ~= pair.host.visual_key then
		pair.dirty.host_bake = true
		pair.dirty.geometry = true
	end
	if donor_key ~= pair.donor.visual_key then
		pair.dirty.donor_bake = true
		pair.dirty.geometry = true
	end
	if pair.dirty.host_bake then
		if not capture_side(pair.host, pair.capture_wrap, cut_n, pair, policy) then
			pair.last_error = render.get_last_error() or "host bake failed"
			return false
		end
		pair.host.visual_key = host_key
		pair.dirty.host_bake = false
		pair.dirty.geometry = true
	end
	if pair.dirty.donor_bake then
		if not capture_side(pair.donor, pair.capture_wrap, cut_n, pair, policy) then
			pair.last_error = render.get_last_error() or "donor bake failed"
			return false
		end
		pair.donor.visual_key = donor_key
		pair.dirty.donor_bake = false
		pair.dirty.geometry = true
	end
	if skip_geom and pair.solution then
		PERF.pair_solution_cache_hits = PERF.pair_solution_cache_hits + 1
		return true
	end
	if pair.dirty.geometry or not pair.solution then
		PERF.pair_solution_cache_misses = PERF.pair_solution_cache_misses + 1
		return solve_geometry(pair)
	end
	PERF.pair_solution_cache_hits = PERF.pair_solution_cache_hits + 1
	return true
end

function M.fit_to_box(pair, width, height, opts)
	if not pair or not pair.solution then return nil end
	local fit = geometry.fit_pair_to_box(pair.solution, width, height, opts)
	pair.presentation = fit
	return fit
end

local function as_xy(v)
	if v == nil then
		return 0, 0
	end
	if type(v) == "userdata" or type(v) == "table" then
		local x = v.X or v.x or v[1]
		local y = v.Y or v.y or v[2]
		return tonumber(x) or 0, tonumber(y) or 0
	end
	return 0, 0
end

local function offset_plus(base, extra)
	base = base or { 0, 0 }
	local bx = base[1] or base.x or 0
	local by = base[2] or base.y or 0
	local ex, ey = as_xy(extra)
	return { bx + ex, by + ey }
end

--- Render complementary halves (already-captured RTs).
function M.render(pair, screen_pos, opts)
	opts = opts or {}
	if not pair or not pair.solution or not screen_pos then
		return false, false
	end
	local sol = pair.solution
	local presentation = opts.presentation or pair.presentation
	local host_scale = sol.host.scale or 1
	local donor_scale = sol.donor.scale or 1
	local host_off = sol.host.offset_local or { 0, 0 }
	local donor_off = sol.donor.offset_local or { 0, 0 }
	if presentation then
		host_scale = presentation.host_scale or host_scale
		donor_scale = presentation.donor_scale or donor_scale
		host_off = presentation.host_offset or host_off
		donor_off = presentation.donor_offset or donor_off
	end
	-- Render-time common scale (e.g. seam-size weighted T/H): multiplies
	-- seam solution scales + local offsets only. Extra world PO deltas stay raw.
	local common_scale = tonumber(opts.common_scale) or 1
	if common_scale ~= 1 then
		host_scale = host_scale * common_scale
		donor_scale = donor_scale * common_scale
		local hx, hy = as_xy(host_off)
		local dx, dy = as_xy(donor_off)
		host_off = { hx * common_scale, hy * common_scale }
		donor_off = { dx * common_scale, dy * common_scale }
	end
	host_off = offset_plus(host_off, opts.host_extra_offset)
	donor_off = offset_plus(donor_off, opts.donor_extra_offset)
	local tint = opts.tint
	if opts.highlight and not tint then
		tint = KColor(1.0, 0.92, 0.62, 1.0)
	end
	tint = tint or KColor(1, 1, 1, 1)
	local cn = sol.cut_normal or pair.cut_normal or { 1, 0 }

	local host_ok = render.render_half(pair.host.slot, screen_pos, {
		cut_origin = sol.host.cut_origin,
		cut_normal = cn,
		keep_sign = sol.host.keep_sign or pair.host.keep_sign,
		feather = pair.feather,
		scale = host_scale,
		offset = host_off,
		tint = tint,
		flip_y = opts.flip_y == true,
		reflect_flip_mode = opts.reflect_flip_mode,
	})
	local donor_ok = render.render_half(pair.donor.slot, screen_pos, {
		cut_origin = sol.donor.cut_origin,
		cut_normal = cn,
		keep_sign = sol.donor.keep_sign or pair.donor.keep_sign,
		feather = pair.feather,
		scale = donor_scale,
		offset = donor_off,
		tint = tint,
		flip_y = opts.flip_y == true,
		reflect_flip_mode = opts.reflect_flip_mode,
	})
	return host_ok == true, donor_ok == true
end

function M.destroy(pair)
	if not pair then return end
	if pair.host and pair.host.slot then
		render.release_source(pair.host.slot)
		pair.host.slot = nil
	end
	if pair.donor and pair.donor.slot then
		render.release_source(pair.donor.slot)
		pair.donor.slot = nil
	end
	pair.solution = nil
	pair.presentation = nil
	pair.host = nil
	pair.donor = nil
end

function M.get_diagnostics(pair)
	if not pair then
		return nil
	end
	local diag = pair.solution and pair.solution.diagnostics or {}
	local out = {}
	for k, v in pairs(diag) do
		out[k] = v
	end
	out.host_capture_mode = pair.host and pair.host.capture_mode or nil
	out.donor_capture_mode = pair.donor and pair.donor.capture_mode or nil
	out.host_registration = pair.host and pair.host.registration_diag or nil
	out.donor_registration = pair.donor and pair.donor.registration_diag or nil
	out.host_geometry_state = pair.host and pair.host.geometry_state or nil
	out.donor_geometry_state = pair.donor and pair.donor.geometry_state or nil
	out.geometry_policy = pair.geometry_policy
	out.body_scale = pair.body_scale
	out.body_scale_source = pair.body_scale_source
	out.body_scale_diag = pair.body_scale_diag
	out.pose_geometry_cache_size = geom_cache_size(pair)
	out.host_geometry_node_cache_size = side_node_cache_size(pair.host)
	out.donor_geometry_node_cache_size = side_node_cache_size(pair.donor)
	out.node_pair_scale_cache_size = pair_scale_cache_size(pair)
	out.geometry_cache_version = render.GEOMETRY_CACHE_VERSION
	out.current_pose_key = pair.current_pose_key
	out.last_pose_geom_diag = pair.last_pose_geom_diag
	out.host_cut_ratio = pair.host and pair.host.geometry_state and pair.host.geometry_state.chosen_ratio
		or (pair.solution and pair.solution.diagnostics and pair.solution.diagnostics.host_candidate_ratio)
	out.donor_cut_ratio = pair.donor and pair.donor.geometry_state and pair.donor.geometry_state.chosen_ratio
		or (pair.solution and pair.solution.diagnostics and pair.solution.diagnostics.donor_candidate_ratio)
	return out
end

function M.export_source_rts(pair)
	if not pair or not pair.host or not pair.donor then
		return nil, "no pair"
	end
	local left_ppm, lerr = render.export_source_ppm(pair.host.slot)
	if not left_ppm then
		return nil, "left: " .. tostring(lerr)
	end
	local right_ppm, rerr = render.export_source_ppm(pair.donor.slot)
	if not right_ppm then
		return nil, "right: " .. tostring(rerr)
	end
	return {
		left_full_rt = left_ppm,
		right_full_rt = right_ppm,
		host_capture_mode = pair.host.capture_mode,
		donor_capture_mode = pair.donor.capture_mode,
	}
end

return M
