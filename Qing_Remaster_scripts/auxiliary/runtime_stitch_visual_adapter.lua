-- Live Native Mixture visual adapter via sprite_splice.
--
-- Native Runtime Stitch render ownership:
--   Live Left/Right NPCs remain real native entities.
--   Runtime Stitch NEVER writes Entity.Visible.
--   Automatic linkee screen rendering is suppressed in MC_PRE_NPC_RENDER
--   when capture_depth == 0.
--   During linker composite (MC_POST_NPC_RENDER), Runtime Stitch explicitly
--   invokes EntityNPC:Render() for each native linkee inside RenderToImage.
--   A reentrancy guard makes this adapter's PRE hook pass through during
--   that explicit native capture.
--
-- Do not:
--   - call Sprite:Update on live native NPC sprites
--   - enumerate RenderLayer / rebuild overlays
--   - replace Entity:Render with Sprite:Render for production live NPC capture
--   - use Stitch Edition precomputed half ANM2

local sprite_splice = require("Qing_Remaster_scripts.auxiliary.sprite_splice")
local controller = require("Qing_Remaster_scripts.auxiliary.native_mixture.controller")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local M = {
	ToCall = {},
	-- A/B perf flags (default false). Probe / ImGui may toggle.
	disable_runtime_capture = false,
	disable_geometry_refresh = false,
}

local VISUAL_KEY = "Qing_NativeMixture_Visual"
local active = {}
local LINKER_NPC_TYPE = 996

-- Depth of explicit Entity:Render capture. PRE suppress only when depth == 0.
local capture_depth = 0

-- Probe counters (resettable).
local stats = {
	entity_render_calls = 0,
	native_pre_suppressed = 0,
	native_pre_passthrough = 0,
	linker_composite = 0,
	presentation_skip = 0,
	room_reused_visual = 0,
	room_reattached_visual = 0,
	last_room_reused = 0,
	last_room_reattached = 0,
	water_skip_capture = 0,
	water_under_renders = 0,
	water_above_renders = 0,
}

-- Tiny water-pass diagnostic (default off). Records REFRACT/REFLECT/ABOVE.
-- reflect_flip_mode: 0=none, 1=destination Flip (A/B), 2=source Flip (production).
local water_pass_probe = {
	enabled = false,
	draw_cross = true,
	reflect_flip_mode = 2,
	ring = {},
	ring_max = 48,
	last_by_mode = {},
}

local function active_pair_count()
	local n = 0
	for _ in pairs(active) do
		n = n + 1
	end
	return n
end

function M.get_capture_depth()
	return capture_depth
end

function M.get_stats()
	return {
		capture_depth = capture_depth,
		entity_render_calls = stats.entity_render_calls,
		entity_rt_captures = stats.entity_render_calls, -- alias
		native_pre_suppressed = stats.native_pre_suppressed,
		native_pre_passthrough = stats.native_pre_passthrough,
		linker_composite = stats.linker_composite,
		presentation_skip = stats.presentation_skip,
		room_reused_visual = stats.room_reused_visual,
		room_reattached_visual = stats.room_reattached_visual,
		last_room_reused = stats.last_room_reused,
		last_room_reattached = stats.last_room_reattached,
		water_skip_capture = stats.water_skip_capture,
		water_under_renders = stats.water_under_renders,
		water_above_renders = stats.water_above_renders,
		pair_count = active_pair_count(),
		disable_runtime_capture = M.disable_runtime_capture == true,
		disable_geometry_refresh = M.disable_geometry_refresh == true,
		water_pass_probe = water_pass_probe.enabled == true,
	}
end

--- Rolling totals + pair_count (+ splice module counters when available).
function M.get_perf_counters()
	local out = M.get_stats()
	if sprite_splice.get_perf_counters then
		out.splice = sprite_splice.get_perf_counters()
	end
	return out
end

function M.reset_stats()
	stats.entity_render_calls = 0
	stats.native_pre_suppressed = 0
	stats.native_pre_passthrough = 0
	stats.linker_composite = 0
	stats.presentation_skip = 0
	stats.room_reused_visual = 0
	stats.room_reattached_visual = 0
	stats.water_skip_capture = 0
	stats.water_under_renders = 0
	stats.water_above_renders = 0
	water_pass_probe.ring = {}
	water_pass_probe.last_by_mode = {}
	if sprite_splice.reset_perf_counters then
		sprite_splice.reset_perf_counters()
	end
end

function M.note_room_reused_visual()
	stats.room_reused_visual = stats.room_reused_visual + 1
end

function M.note_room_reattached_visual()
	stats.room_reattached_visual = stats.room_reattached_visual + 1
end

function M.note_room_transition(reused, reattached)
	-- Counters already incremented per linker; keep last transition snapshot.
	stats.last_room_reused = tonumber(reused) or 0
	stats.last_room_reattached = tonumber(reattached) or 0
end

local function render_mode_name(mode)
	if mode == RenderMode.RENDER_NORMAL then
		return "NORMAL"
	elseif mode == RenderMode.RENDER_WATER_ABOVE then
		return "WATER_ABOVE"
	elseif mode == RenderMode.RENDER_WATER_REFRACT then
		return "WATER_REFRACT"
	elseif mode == RenderMode.RENDER_WATER_REFLECT then
		return "WATER_REFLECT"
	elseif mode == RenderMode.RENDER_NULL then
		return "NULL"
	elseif mode == RenderMode.RENDER_SKIP then
		return "SKIP"
	end
	return "MODE_" .. tostring(mode)
end

local function xy_delta(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return nil
	end
	local ax = tonumber(a[1] or a.x) or 0
	local ay = tonumber(a[2] or a.y) or 0
	local bx = tonumber(b[1] or b.x) or 0
	local by = tonumber(b[2] or b.y) or 0
	return { bx - ax, by - ay }
end

local function push_water_pass_sample(sample)
	if not water_pass_probe.enabled then
		return
	end
	local ring = water_pass_probe.ring
	ring[#ring + 1] = sample
	while #ring > water_pass_probe.ring_max do
		table.remove(ring, 1)
	end
	if sample and sample.mode_name then
		water_pass_probe.last_by_mode[sample.mode_name] = sample
	end
end

local function draw_water_pass_cross(screen, mode)
	if not water_pass_probe.enabled or not water_pass_probe.draw_cross then
		return
	end
	if not screen or not Isaac.DrawLine then
		return
	end

	-- Isaac.DrawLine requires KColor (Color userdata is rejected).
	-- Probe overlay must never abort the production MC_POST_NPC_RENDER path.
	local col = KColor(1, 1, 0, 1)
	if mode == RenderMode.RENDER_WATER_REFRACT then
		col = KColor(0.2, 0.8, 1, 1)
	elseif mode == RenderMode.RENDER_WATER_REFLECT then
		col = KColor(1, 0.4, 0.9, 1)
	elseif mode == RenderMode.RENDER_WATER_ABOVE then
		col = KColor(0.3, 1, 0.3, 1)
	end
	local arm = 2
	pcall(function()
		Isaac.DrawLine(screen + Vector(-arm, 0), screen + Vector(arm, 0), col, col, 1)
		Isaac.DrawLine(screen + Vector(0, -arm), screen + Vector(0, arm), col, col, 1)
	end)
end

function M.set_water_pass_probe_enabled(value)
	water_pass_probe.enabled = value == true
	if not water_pass_probe.enabled then
		water_pass_probe.ring = {}
		water_pass_probe.last_by_mode = {}
	end
end

function M.get_water_pass_probe_enabled()
	return water_pass_probe.enabled == true
end

function M.set_water_pass_probe_draw_cross(value)
	water_pass_probe.draw_cross = value ~= false
end

--- Debug A/B: 0=none, 1=destination Flip, 2=source Flip (+ clip Y mirror). Default 2.
function M.set_reflect_flip_mode(mode)
	local m = tonumber(mode)
	if m == 0 or m == 1 or m == 2 then
		water_pass_probe.reflect_flip_mode = m
	else
		water_pass_probe.reflect_flip_mode = 2
	end
end

function M.get_reflect_flip_mode()
	local m = tonumber(water_pass_probe.reflect_flip_mode)
	if m == 0 or m == 1 or m == 2 then
		return m
	end
	return 2
end

local REFLECT_FLIP_MODE_NAMES = {
	[0] = "none",
	[1] = "destination",
	[2] = "source",
}

function M.get_reflect_flip_mode_name(mode)
	local m = tonumber(mode)
	if m == nil then
		m = M.get_reflect_flip_mode()
	end
	return REFLECT_FLIP_MODE_NAMES[m] or ("mode_" .. tostring(m))
end

function M.get_water_pass_probe_diag()
	local last = water_pass_probe.last_by_mode or {}
	local above = last.WATER_ABOVE
	local refract = last.WATER_REFRACT
	local reflect = last.WATER_REFLECT
	local flip_mode = M.get_reflect_flip_mode()
	return {
		enabled = water_pass_probe.enabled == true,
		draw_cross = water_pass_probe.draw_cross ~= false,
		reflect_flip_mode = flip_mode,
		reflect_flip_mode_name = REFLECT_FLIP_MODE_NAMES[flip_mode] or "source",
		ring_len = #water_pass_probe.ring,
		last_by_mode = water_pass_probe.last_by_mode,
		ring_tail = (#water_pass_probe.ring > 0)
			and water_pass_probe.ring[#water_pass_probe.ring]
			or nil,
		-- Mode-to-mode callback_offset deltas (expect non-zero if engine already
		-- injects water-pass placement into the native render callback).
		callback_delta_refract_minus_above = above and refract
			and xy_delta(above.callback_offset, refract.callback_offset)
			or nil,
		callback_delta_reflect_minus_above = above and reflect
			and xy_delta(above.callback_offset, reflect.callback_offset)
			or nil,
		screen_delta_refract_minus_above = above and refract
			and xy_delta(
				above.water_adjusted_screen or above.base_screen,
				refract.water_adjusted_screen or refract.base_screen
			)
			or nil,
		screen_delta_reflect_minus_above = above and reflect
			and xy_delta(
				above.water_adjusted_screen or above.base_screen,
				reflect.water_adjusted_screen or reflect.base_screen
			)
			or nil,
	}
end

function M.set_disable_runtime_capture(value)
	M.disable_runtime_capture = value == true
end

function M.set_disable_geometry_refresh(value)
	M.disable_geometry_refresh = value == true
end

function M.get_disable_runtime_capture()
	return M.disable_runtime_capture == true
end

function M.get_disable_geometry_refresh()
	return M.disable_geometry_refresh == true
end

--- Reentrancy guard around explicit ent:Render. Always restores depth.
function M.with_native_capture(fn)
	capture_depth = capture_depth + 1
	local ok, err = pcall(fn)
	capture_depth = math.max(0, capture_depth - 1)
	if not ok then
		error(tostring(err))
	end
end

local function world_to_screen_b(ent, offset)
	offset = offset or Vector(0, 0)
	local room = Game():GetRoom()
	return Isaac.WorldToScreen(ent.Position + ent.PositionOffset) + offset - room:GetRenderScrollOffset()
end

local function span_of(slot)
	if not slot then
		return nil
	end
	local g = slot.geometry_prior
	if type(g) == "table" then
		local span = tonumber(g.avg_vertical_span)
		if span and span > 0 then
			return span
		end
	end
	return nil
end

local function body_scale_of(left_slot, right_slot)
	-- Donor uniform scale from explicit profile field only (default 1).
	local function from_slot(slot)
		if not slot then
			return nil
		end
		local vis = slot.visual
		if type(vis) == "table" and tonumber(vis.body_scale) then
			return tonumber(vis.body_scale)
		end
		return tonumber(slot.body_scale)
	end
	return from_slot(right_slot) or from_slot(left_slot) or 1
end

--- Profile visual.seam_size_attack_weight → render-time common scale.
--- Seam solver still matches Attack to Movement (both become H). Then:
---   T = lerp(H, D, w); common_scale = T / H
--- Uses already-measured tangent/centerline spans only — never Sprite.Scale.
local function seam_size_common_scale(effect, pair)
	local w = nil
	if type(effect) == "table" then
		for _, side in ipairs({ "Left", "Right" }) do
			local slot = effect[side]
			local vis = slot and slot.visual
			if type(vis) == "table" and tonumber(vis.seam_size_attack_weight) ~= nil then
				w = tonumber(vis.seam_size_attack_weight)
				break
			end
		end
	end
	if w == nil then
		return 1
	end
	w = math.max(0, math.min(1, w))
	if w <= 0 then
		return 1
	end

	local diag = pair and pair.solution and pair.solution.diagnostics or {}
	local H = tonumber(diag.host_span)
	local D = tonumber(diag.donor_span)
	-- Prefer live centerline spans (same family as node_pair_scale) when present.
	local hcl = pair and pair.host and pair.host.current_centerline
	local dcl = pair and pair.donor and pair.donor.current_centerline
	local h_span = hcl and (tonumber(hcl.span) or tonumber(hcl.centerline_span))
	local d_span = dcl and (tonumber(dcl.span) or tonumber(dcl.centerline_span))
	if h_span and h_span > 0 then
		H = h_span
	end
	if d_span and d_span > 0 then
		D = d_span
	end
	if not H or H <= 0.001 or not D or D < 0 then
		return 1
	end
	local T = H * (1 - w) + D * w
	return T / H
end

--- Production registration: progressive centerline only (no bbox fallback).
local function registration_of(_slot)
	return {
		mode = "interface_first",
		axis = "normal",
	}
end

local function get_visual(linker)
	if not linker then
		return nil
	end
	return linker:GetData()[VISUAL_KEY]
end

function M.detach(linker)
	if not linker then
		return
	end
	local vis = get_visual(linker)
	if vis and vis.pair then
		sprite_splice.destroy(vis.pair)
	end
	linker:GetData()[VISUAL_KEY] = nil
	active[GetPtrHash(linker)] = nil
end

--- True when linker already has a live visual pair (no recreate needed).
function M.has_valid_visual(linker)
	local vis = get_visual(linker)
	if not (vis and vis.pair) then
		return false
	end
	local pair = vis.pair
	-- Prefer host/donor image slots when present; otherwise accept any solved pair.
	local host_ok = pair.host and pair.host.slot and pair.host.slot.image
	local donor_ok = pair.donor and pair.donor.slot and pair.donor.slot.image
	if host_ok and donor_ok then
		return true
	end
	return pair.solution ~= nil
end

--- Re-index adapter active table without destroy/create/force-capture.
function M.rebind(linker)
	if not linker or not controller.is_linker(linker) then
		return false
	end
	if not M.has_valid_visual(linker) then
		return false
	end
	active[GetPtrHash(linker)] = linker
	return true
end

function M.attach(linker)
	if not linker or not controller.is_linker(linker) then
		return false
	end
	local effect = controller.get_effect(linker)
	if not effect or not effect.Left or not effect.Right then
		return false
	end
	local left = effect.Left.ent
	local right = effect.Right.ent
	if not left or not right or not left:Exists() or not right:Exists() then
		return false
	end

	M.detach(linker)

	local host_span = span_of(effect.Left)
	local donor_span = span_of(effect.Right)
	local body_scale = body_scale_of(effect.Left, effect.Right)
	-- Left (host) keeps the right half of its sprite (+1); Right (donor) keeps left (-1).
	-- Analysis and blit both use these signs — do not invert only at draw time.
	local pair, err = sprite_splice.create({
		host = {
			entity = left,
			keep_sign = 1,
			reference_span = host_span,
			registration = registration_of(effect.Left),
			profile_kind = "movement",
			profile_id = effect.move_id,
			ignore_geometry_frames = effect.Left.visual
				and effect.Left.visual.ignore_geometry_frames,
		},
		donor = {
			entity = right,
			keep_sign = -1,
			reference_span = donor_span,
			registration = registration_of(effect.Right),
			profile_kind = "attack",
			profile_id = effect.attack_id,
			ignore_geometry_frames = effect.Right.visual
				and effect.Right.visual.ignore_geometry_frames,
		},
		cut_normal = { 1, 0 },
		host_reference_span = host_span,
		donor_reference_span = donor_span,
		body_scale = body_scale,
		body_scale_source = (body_scale ~= 1) and "profile_visual" or "default",
		geometry_policy = {
			stable_cut = true,
			fixed_seam_plane = true,
			seam_normal_anchor = 0,
			-- Scale from GeometryNodePair interface ratio (cached); not fixed 1.0.
			fixed_body_scale = false,
			body_scale = (body_scale ~= 1) and body_scale or nil, -- optional profile prior multiplier
			-- Discrete GeometryNode cache (anim/frame/crop). Interpolated transform separate.
			pose_geometry_cache = false, -- production uses per-side GeometryNode analysis cache
			geometry_node_cache = true,
			node_pair_scale = true,
			pose_registration_cache = false, -- never anim:frame alone
			-- Centerline-only: never enable bbox / silhouette_axis fallback for production.
			silhouette_axis_registration = false,
			visual_center_registration = false,
			registration_measure = "interface_first",
			interface_first_registration = true,
			tangent_align = "range_mid",
			sample_step = 2,
			collect_cut_candidates = false,
			min_scale = 0.35,
			max_scale = 2.50,
		},
		capture_wrap = function(fn)
			stats.entity_render_calls = stats.entity_render_calls + 1
			M.with_native_capture(fn)
		end,
	})
	if not pair then
		return false, err
	end
	-- Production live pair must be entity_render, never sprite draw override.
	if pair.host and pair.host.draw ~= nil then
		return false, "production adapter must not set host.draw"
	end
	if pair.donor and pair.donor.draw ~= nil then
		return false, "production adapter must not set donor.draw"
	end

	linker:GetData()[VISUAL_KEY] = {
		pair = pair,
		host_span = host_span,
		donor_span = donor_span,
	}
	active[GetPtrHash(linker)] = linker
	return true
end

--- Explicit Extra.set_visible only (pre-capture). Centerline gate runs after update.
local function evaluate_explicit_visibility(effect)
	local tg_name = (effect.baseinfo and effect.baseinfo.tg) or "Left"
	if tg_name ~= "Left" and tg_name ~= "Right" then
		tg_name = "Left"
	end
	local slot = effect[tg_name]
	local ent = slot and slot.ent
	local out = {
		tg = tg_name,
		profile_id = slot and slot.profile_id or nil,
		anim = "",
		frame = -1,
		scan_ok = nil,
		scan_count = 0,
		scan_span = 0,
		set_visible = nil,
		composite_visible = false,
		reason = "no_tg",
	}
	if not ent or not ent.Exists or not ent:Exists() then
		return out
	end
	local spr = ent.GetSprite and ent:GetSprite() or nil
	if spr then
		pcall(function()
			out.anim = spr:GetAnimation() or ""
			out.frame = spr:GetFrame() or -1
		end)
	end
	local info = slot.info or {}
	if info.set_visible ~= nil then
		local vis = auxi.check_if_any(info.set_visible, ent)
		out.set_visible = vis
		if vis == false then
			out.reason = "set_visible_false"
			out.composite_visible = false
			return out
		end
	end
	out.reason = "pending_centerline"
	out.composite_visible = true -- allow capture; centerline gate may still hide
	return out
end

local function apply_centerline_presentation(base_pres, tg_side)
	local out = {}
	for k, v in pairs(base_pres or {}) do
		out[k] = v
	end
	local cl = tg_side and tg_side.current_centerline
	out.scan_ok = cl and cl.ok == true and cl.chosen_column ~= nil
	out.scan_count = cl and (tonumber(cl.count) or 0) or 0
	out.scan_span = cl and (tonumber(cl.span) or 0) or 0
	if not out.scan_ok or out.scan_count <= 0 then
		out.composite_visible = false
		out.reason = "centerline_miss"
		return out
	end
	out.composite_visible = true
	out.reason = "centerline_body"
	return out
end

function M.get_presentation_diag(linker)
	local vis = get_visual(linker)
	return vis and vis.presentation or nil
end

--- Capture A/B via Entity:Render + refresh geometry if silhouette dirty; blit composite.
--- RenderMode-aware presentation (Image blit, not native Entity:Render):
---   NORMAL / WATER_ABOVE:
---     screen = WorldToScreen + callbackOffset - scroll
---   WATER_REFLECT:
---     screen = base only — callback_offset already carries reflection placement
---     (~GetWaterRenderOffset). SourceQuad FlipY handles orientation only.
---   WATER_REFRACT:
---     screen = base only for now (no second WaterOffset); re-probe if scenes appear.
--- Water passes never recapture; they consume the above-water canonical RT.
--- Pair-level visibility: motion tg centerline miss (or Extra set_visible==false)
--- skips the entire composite — not a transparent host half / bbox guess.
function M.render_linker(linker, callback_offset)
	local vis = get_visual(linker)
	if not vis or not vis.pair then
		return false
	end
	local effect = controller.get_effect(linker)
	if not effect or not effect.Left or not effect.Right then
		return false
	end
	local left = effect.Left.ent
	local right = effect.Right.ent
	if not left or not right or not left:Exists() or not right:Exists() then
		return false
	end

	local room = Game():GetRoom()
	local mode = room:GetRenderMode()
	local is_refract = mode == RenderMode.RENDER_WATER_REFRACT
	local is_reflect = mode == RenderMode.RENDER_WATER_REFLECT
	local is_water_pass = is_refract or is_reflect

	-- Refresh entity wrappers (Isaac may issue new userdata).
	vis.pair.host.entity = left
	vis.pair.donor.entity = right
	vis.pair.host.draw = nil
	vis.pair.donor.draw = nil
	vis.pair.host.registration = registration_of(effect.Left)
	vis.pair.donor.registration = registration_of(effect.Right)
	-- Keep profile identity fresh so ignore_geometry_frames resolves from profiles.
	vis.pair.host.profile_kind = "movement"
	vis.pair.host.profile_id = effect.move_id
	vis.pair.donor.profile_kind = "attack"
	vis.pair.donor.profile_id = effect.attack_id
	vis.pair.host.ignore_geometry_frames = effect.Left.visual
		and effect.Left.visual.ignore_geometry_frames
	vis.pair.donor.ignore_geometry_frames = effect.Right.visual
		and effect.Right.visual.ignore_geometry_frames

	local explicit = evaluate_explicit_visibility(effect)
	if explicit.reason == "set_visible_false" or explicit.reason == "no_tg" then
		vis.presentation = explicit
		stats.presentation_skip = (stats.presentation_skip or 0) + 1
		return true
	end

	-- A/B: skip all capture/solve; blit last solution if any.
	if M.disable_runtime_capture then
		if not vis.pair.solution then
			return false
		end
	else
		-- Production: dirty-key capture (force_entity_capture=false).
		-- REFRACT/REFLECT must not Entity:Render→RT (would pollute source with water pass).
		-- Also skip geometry solve under water — blit last NORMAL/ABOVE solution.
		local upd_opts = {
			force_entity_capture = false,
			skip_geometry_solve = is_water_pass or (M.disable_geometry_refresh == true),
			skip_entity_capture = is_water_pass,
		}
		local ok = sprite_splice.update(vis.pair, upd_opts)
		if is_water_pass then
			stats.water_skip_capture = stats.water_skip_capture + 1
		end
		if not ok then
			return false
		end
	end

	local tg_name = explicit.tg or "Left"
	local tg_side = (tg_name == "Right") and vis.pair.donor or vis.pair.host
	local presentation = apply_centerline_presentation(explicit, tg_side)
	vis.presentation = presentation
	if not presentation.composite_visible then
		stats.presentation_skip = (stats.presentation_skip or 0) + 1
		return true
	end
	if not vis.pair.solution then
		return false
	end

	local host_extra = left.PositionOffset - linker.PositionOffset
	local donor_extra = right.PositionOffset - linker.PositionOffset
	local base_screen = world_to_screen_b(linker, callback_offset)
	local screen = base_screen
	-- manual_water_delta stays zero: REFLECT callback_offset already ≈ WaterOffset;
	-- adding GetWaterRenderOffset() again double-applied (~-101,-11 vs expected once).
	local manual_water_delta = Vector(0, 0)
	if is_reflect then
		-- Placement from callback only; SourceQuad flip handles orientation.
		screen = base_screen
		stats.water_under_renders = stats.water_under_renders + 1
	elseif is_refract then
		-- Keep independent of REFLECT; current flooded rooms may never hit this pass.
		-- Do not re-bind to GetWaterRenderOffset without a dedicated REFRACT probe.
		screen = base_screen
		stats.water_under_renders = stats.water_under_renders + 1
	elseif mode == RenderMode.RENDER_WATER_ABOVE then
		stats.water_above_renders = stats.water_above_renders + 1
	end

	local reflect_flip_mode = M.get_reflect_flip_mode()
	local common_scale = seam_size_common_scale(effect, vis.pair)
	local host_ok, donor_ok = sprite_splice.render(vis.pair, screen, {
		host_extra_offset = host_extra,
		donor_extra_offset = donor_extra,
		flip_y = is_reflect,
		reflect_flip_mode = reflect_flip_mode,
		common_scale = common_scale,
	})
	if water_pass_probe.enabled then
		local off = callback_offset or Vector(0, 0)
		push_water_pass_sample({
			frame = Game():GetFrameCount(),
			mode = mode,
			mode_name = render_mode_name(mode),
			callback_offset = { off.X, off.Y },
			base_screen = { base_screen.X, base_screen.Y },
			manual_water_delta = { manual_water_delta.X, manual_water_delta.Y },
			water_adjusted_screen = { screen.X, screen.Y },
			native_screen = { base_screen.X, base_screen.Y },
			flip_y = is_reflect,
			reflect_flip_mode = is_reflect and reflect_flip_mode or 0,
			reflect_flip_mode_name = is_reflect
				and M.get_reflect_flip_mode_name(reflect_flip_mode)
				or "none",
			host_render_call_ok = host_ok == true,
			donor_render_call_ok = donor_ok == true,
			is_refract = is_refract,
			is_reflect = is_reflect,
			water_under = is_water_pass,
			rendered = true,
			ptr = GetPtrHash(linker),
		})
	end
	draw_water_pass_cross(screen, mode)
	stats.linker_composite = stats.linker_composite + 1
	return true
end

-- Compat: prepare = existing valid visual pair (room transition reuse).
function M.prepare(linker)
	return M.has_valid_visual(linker)
end

function M.update(linker)
	return M.prepare(linker)
end

function M.get_diagnostics(linker)
	local vis = get_visual(linker)
	if not vis or not vis.pair then
		return nil
	end
	local diag = sprite_splice.get_diagnostics(vis.pair) or {}
	diag.capture_depth = capture_depth
	diag.stats = M.get_stats()
	diag.geometry_trace = sprite_splice.get_geometry_trace(vis.pair)
	diag.presentation = vis.presentation
	return diag
end

function M.get_geometry_trace(linker)
	local vis = get_visual(linker)
	if not vis or not vis.pair then
		return nil
	end
	return sprite_splice.get_geometry_trace(vis.pair)
end

function M.export_source_rts(linker)
	local vis = get_visual(linker)
	if not vis or not vis.pair then
		return nil, "no pair"
	end
	return sprite_splice.export_source_rts(vis.pair)
end

-- PRE: suppress automatic linkee screen blit; pass through during explicit capture.
table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_NPC_RENDER,
	params = nil,
	Function = function(_, ent, _offset)
		if not controller.is_linkee(ent) then
			return
		end
		if capture_depth > 0 then
			stats.native_pre_passthrough = stats.native_pre_passthrough + 1
			return -- allow Entity:Render inside our RenderToImage
		end
		stats.native_pre_suppressed = stats.native_pre_suppressed + 1
		return false -- cancel automatic world blit only
	end,
})

-- POST Linker: Entity capture + splice composite (Stitch Edition ownership model).
table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NPC_RENDER,
	params = LINKER_NPC_TYPE,
	Function = function(_, npc, offset)
		if capture_depth > 0 then
			return -- never recurse into composite while capturing
		end
		if not controller.is_linker(npc) then
			return
		end
		M.render_linker(npc, offset)
	end,
})

return M
