-- LEGACY / DEBUG RENDERER ONLY.
-- Production Runtime Stitch visuals are owned by:
--   sprite_splice.lua
--   sprite_splice_render.lua
--   runtime_stitch_visual_adapter.lua
--
-- Do not copy RenderLayer/shadow handling into production capture.
-- Canonical capture is always Sprite:Render() inside Renderer.RenderToImage().
--
-- Gate1/2: donor bake + clip blit (probe).
-- Gate2.5: organ-graft attachment (no Host clip) — technical side path.
-- Gate3: Host render takeover + true Host/Donor splice (3A full takeover first).
-- Bake in POST_UPDATE only; blit in PRE/POST_NPC_RENDER.
-- Clip via Image:RenderWithShader; never Entity/Sprite SetCustomShader.

local donors = require("Qing_Remaster_scripts.config.runtime_stitch_donors")
local host_edge = require("Qing_Remaster_scripts.auxiliary.runtime_stitch_host_edge")
local stitch_geometry = require("Qing_Remaster_scripts.auxiliary.runtime_stitch_geometry")
local splice_geometry = require("Qing_Remaster_scripts.auxiliary.sprite_splice_geometry")
local sprite_splice = require("Qing_Remaster_scripts.auxiliary.sprite_splice")
local splice_render = require("Qing_Remaster_scripts.auxiliary.sprite_splice_render")

local M = {
	ToCall = {},
	TARGET_SIZE = 128,
	SHADER_PATH = "shaders/suture_runtime_clip",
	MAX_ACTIVE = 6,
	SEAM_ANM2 = "gfx/mimics/Suture_Needle/suture_marks.anm2",
}

local _shader = nil
local _shader_failed = false
local _pool = {}
local _grafts = {}
local _takeovers = {} -- GetPtrHash(host) -> takeover state (Gate3A+)
local _status = {
	api = false,
	shader = false,
	last_error = nil,
	gate1_ok = false,
	gate2_ok = false,
	gate2_5_ok = false,
	gate3_ok = false, -- reserved / legacy alias for gate2_5 during transition
	gate3a_ok = false,
	gate3b_ok = false,
	gate3c_ok = false,
	gate3d_ok = false,
	last_seam_align = "none",
	last_bake_ok = false,
	last_blit_mode = "none",
	last_edge_source = "none",
	last_draw_order = "none",
	last_host_flip_x = false,
	last_takeover_mode = "none",
	last_verify_mode = "none",
	last_export_path = nil,
	last_export_error = nil,
	last_export_nonzero = 0,
	last_diag_path = nil,
	last_diag_error = nil,
	last_residual_error_px = nil,
	last_math_ok = false,
	gate3d_phase = "diagnostic",
	-- Screen pos locked to project standard B (entity_render_scroll_offset_pitfalls.md).
	screen_pos_formula = "B",
	last_render_align = nil,
}

-- Gate3D diagnostic snapshot (filled by refresh_seam_align / export).
local _diag = {
	overlay = false,
	frame = 0,
	host = nil,
	donor = nil,
	final = nil,
	layers = nil,
}

local _seam = {
	ready = false,
	thread = nil,
	stitch = nil,
	knot = nil,
	wound = nil,
}

-- Forward decls: used by blit / debug_splice / set_takeover_cut before definitions below.
local refresh_seam_align
local sample_side_geometry
local refresh_all_seam_aligns
local apply_tangent_stretch
local compute_seam_delta_at_render
local bake_one_takeover
local _seam_align_tick = 0

-- Shared donor geometry: donor_id + visual frame + cut config (not per-graft).
local _donor_geom_cache = {}

local _perf = {
	window_start_frame = -1,
	bakes = 0,
	bake_skips = 0,
	texel_reads = 0,
	geometry_analyzes = 0,
	geometry_skips = 0,
	donor_geom_hits = 0,
	donor_geom_misses = 0,
	bakes_per_s = 0,
	bake_skips_per_s = 0,
	texel_reads_per_s = 0,
	geometry_analyzes_per_s = 0,
	geometry_skips_per_s = 0,
	donor_hits_per_s = 0,
	donor_misses_per_s = 0,
}

local function perf_roll_window()
	local frame = 0
	local ok, g = pcall(Game)
	if ok and g and g.GetFrameCount then
		frame = g:GetFrameCount() or 0
	end
	if (_perf.window_start_frame or -1) < 0 then
		_perf.window_start_frame = frame
		return
	end
	local dt = frame - _perf.window_start_frame
	if dt < 60 then
		return
	end
	local s = dt / 60
	_perf.bakes_per_s = _perf.bakes / s
	_perf.bake_skips_per_s = _perf.bake_skips / s
	_perf.texel_reads_per_s = _perf.texel_reads / s
	_perf.geometry_analyzes_per_s = _perf.geometry_analyzes / s
	_perf.geometry_skips_per_s = _perf.geometry_skips / s
	_perf.donor_hits_per_s = _perf.donor_geom_hits / s
	_perf.donor_misses_per_s = _perf.donor_geom_misses / s
	_perf.window_start_frame = frame
	_perf.bakes = 0
	_perf.bake_skips = 0
	_perf.texel_reads = 0
	_perf.geometry_analyzes = 0
	_perf.geometry_skips = 0
	_perf.donor_geom_hits = 0
	_perf.donor_geom_misses = 0
end

--- Silhouette key only. Color / Alpha / Position / Offset must not be included.
local function sprite_frame_key(sprite)
	if not sprite then
		return "nil"
	end
	local anim, frame, oanim, oframe, fx, fy = "?", -1, "", -1, 0, 0
	pcall(function()
		anim = sprite:GetAnimation() or "?"
		frame = sprite:GetFrame() or -1
		if sprite.GetOverlayAnimation then
			oanim = sprite:GetOverlayAnimation() or ""
		end
		if sprite.GetOverlayFrame then
			oframe = sprite:GetOverlayFrame() or -1
		end
		fx = sprite.FlipX and 1 or 0
		fy = sprite.FlipY and 1 or 0
	end)
	return table.concat({
		tostring(anim),
		tostring(frame),
		tostring(oanim),
		tostring(oframe),
		tostring(fx),
		tostring(fy),
	}, ":")
end

local function cut_config_key(origin, normal, keep_sign)
	local ox = (origin and origin[1]) or 0.5
	local oy = (origin and origin[2]) or 0.5
	local nx = (normal and normal[1]) or 1
	local ny = (normal and normal[2]) or 0
	return string.format("%.4f:%.4f:%.4f:%.4f:%.3f", ox, oy, nx, ny, tonumber(keep_sign) or -1)
end

local function donor_geom_cache_key(graft, visual_key)
	return table.concat({
		tostring(graft.donor_id or "?"),
		tostring(visual_key or "?"),
		cut_config_key(graft.cut_origin, graft.cut_normal, graft.keep_sign),
		tostring(graft.size or M.TARGET_SIZE),
	}, "|")
end

local function set_error(msg)
	_status.last_error = msg
end

local function api_ready()
	if not REPENTOGON then
		set_error("REPENTOGON missing")
		_status.api = false
		return false
	end
	if not Renderer or not Renderer.CreateImage or not Renderer.RenderToImage then
		set_error("Renderer.CreateImage / RenderToImage unavailable")
		_status.api = false
		return false
	end
	_status.api = true
	return true
end

local function count_active()
	local n = 0
	for _, list in pairs(_grafts) do
		n = n + #list
	end
	return n
end

local function ensure_seam_sprites()
	if _seam.ready then return true end
	local ok = pcall(function()
		_seam.thread = Sprite()
		_seam.stitch = Sprite()
		_seam.knot = Sprite()
		_seam.wound = Sprite()
		_seam.thread:Load(M.SEAM_ANM2, true)
		_seam.stitch:Load(M.SEAM_ANM2, true)
		_seam.knot:Load(M.SEAM_ANM2, true)
		_seam.wound:Load(M.SEAM_ANM2, true)
		_seam.thread:Play("Thread", true)
		_seam.stitch:Play("Stitch", true)
		_seam.knot:Play("Knot", true)
		_seam.wound:Play("WoundSmall", true)
	end)
	_seam.ready = ok == true
	if not _seam.ready then
		set_error("seam sprites load failed")
	end
	return _seam.ready
end

local function acquire_target(size)
	return splice_render.acquire_source(size or M.TARGET_SIZE)
end

local function release_target(slot)
	splice_render.release_source(slot)
end

local function load_clip_shader()
	local sh = splice_render.load_clip_shader()
	_status.shader = sh ~= nil
	if not sh and splice_render.get_last_error then
		local err = splice_render.get_last_error()
		if err then set_error(err) end
	end
	return sh
end

-- Bake must exclude ANM2 shadow layers so interface measure / splice
-- does not treat the foot oval as cut edge. Draw one full shadow later.
local SHADOW_ANM2 = "gfx/shadow_replace.anm2"
local _shadow_sprite = nil

local function is_shadow_layer_name(name)
	if type(name) ~= "string" or name == "" then
		return false
	end
	local n = string.lower(name)
	return string.find(n, "shadow", 1, true) ~= nil
		or string.find(n, "shade", 1, true) ~= nil
		or n == "ground"
		or n == "foot"
end

local function layer_looks_like_shadow(layer)
	if not layer then
		return false
	end
	if layer.GetName and is_shadow_layer_name(layer:GetName()) then
		return true
	end
	if layer.GetSpritesheetPath then
		local ok, p = pcall(function()
			return layer:GetSpritesheetPath()
		end)
		if ok and type(p) == "string" and string.find(string.lower(p), "shadow", 1, true) then
			return true
		end
	end
	return false
end

local function for_each_sprite_layer(sprite, fn)
	if not sprite or not fn then
		return
	end
	if sprite.GetAllLayers then
		local ok, layers = pcall(function()
			return sprite:GetAllLayers()
		end)
		if ok and type(layers) == "table" then
			for _, layer in pairs(layers) do
				if layer then
					fn(layer)
				end
			end
			return
		end
	end
	local count = nil
	if sprite.GetLayerCount then
		local ok, n = pcall(function()
			return sprite:GetLayerCount()
		end)
		if ok then
			count = tonumber(n)
		end
	end
	if count and count > 0 and sprite.GetLayer then
		for id = 0, count - 1 do
			local ok, layer = pcall(function()
				return sprite:GetLayer(id)
			end)
			if ok and layer then
				fn(layer)
			end
		end
		return
	end
	if sprite.GetLayer then
		for id = 0, 31 do
			local ok, layer = pcall(function()
				return sprite:GetLayer(id)
			end)
			if not ok or not layer then
				break
			end
			fn(layer)
		end
	end
end

--- Temporarily hide shadow-named layers, run fn, then restore visibility.
local function with_shadow_layers_hidden(sprite, fn)
	local hidden = {}
	for_each_sprite_layer(sprite, function(layer)
		if layer_looks_like_shadow(layer) and layer.IsVisible and layer.SetVisible then
			local okv, vis = pcall(function()
				return layer:IsVisible()
			end)
			if okv and vis then
				hidden[#hidden + 1] = layer
				layer:SetVisible(false)
			end
		end
	end)
	local ok, a, b = pcall(fn)
	for i = 1, #hidden do
		pcall(function()
			hidden[i]:SetVisible(true)
		end)
	end
	if not ok then
		error(a)
	end
	return a, b
end

--- Bake body only via RenderLayer (SetVisible alone is flaky inside RenderToImage).
local function render_sprite_without_shadow(sprite, center)
	local drew, skipped = 0, 0
	local layers = {}
	for_each_sprite_layer(sprite, function(layer)
		layers[#layers + 1] = layer
	end)
	if sprite.RenderLayer and #layers > 0 then
		for i = 1, #layers do
			local layer = layers[i]
			local id = i - 1
			if layer.GetLayerID then
				local ok, v = pcall(function()
					return layer:GetLayerID()
				end)
				if ok and v ~= nil then
					id = v
				end
			end
			if layer_looks_like_shadow(layer) then
				skipped = skipped + 1
			else
				local visible = true
				if layer.IsVisible then
					local ok, v = pcall(function()
						return layer:IsVisible()
					end)
					if ok then
						visible = v ~= false
					end
				end
				if visible then
					local ok = pcall(function()
						sprite:RenderLayer(id, center, Vector(0, 0), Vector(0, 0))
					end)
					if ok then
						drew = drew + 1
					end
				end
			end
		end
	end
	if drew < 1 then
		with_shadow_layers_hidden(sprite, function()
			sprite:Render(center, Vector(0, 0), Vector(0, 0))
		end)
		drew = 1
	end
	_status.last_shadow_layers_skipped = skipped
	_status.last_body_layers_drawn = drew
	return drew, skipped
end

local function read_entity_shadow_size(ent)
	local sz = nil
	if ent and ent.GetEntityConfigEntity then
		local ok, cfg = pcall(function()
			return ent:GetEntityConfigEntity()
		end)
		if ok and cfg and cfg.GetShadowSize then
			local s = tonumber(cfg:GetShadowSize())
			if s and s > 0 then
				sz = s
			end
		end
	end
	if (not sz or sz <= 0) and EntityConfig and EntityConfig.GetEntity and ent then
		local ok, cfg = pcall(EntityConfig.GetEntity, ent.Type, ent.Variant, ent.SubType or 0)
		if ok and cfg and cfg.GetShadowSize then
			local s = tonumber(cfg:GetShadowSize())
			if s and s > 0 then
				sz = s
			end
		end
	end
	if (not sz or sz <= 0) and ent and ent.GetShadowSize then
		local s = tonumber(ent:GetShadowSize())
		if s and s > 0 then
			sz = s
		end
	end
	return sz or 0.1
end

local function suppress_host_engine_shadow(to, host)
	if not to or not host then
		return
	end
	if to.saved_shadow_size == nil then
		to.saved_shadow_size = read_entity_shadow_size(host)
		if host.GetShadowSize then
			local cur = tonumber(host:GetShadowSize())
			if cur and cur > 0 then
				to.saved_shadow_size = cur
			end
		end
	end
	if host.SetShadowSize then
		host:SetShadowSize(0)
	end
end

local function restore_host_engine_shadow(to, host)
	if not to then
		return
	end
	host = host or to.host
	local sz = to.saved_shadow_size
	if host and host.SetShadowSize and sz and sz > 0 then
		pcall(function()
			host:SetShadowSize(sz)
		end)
	end
end

local function ensure_shadow_sprite()
	if _shadow_sprite then
		return _shadow_sprite
	end
	local spr = Sprite()
	local ok = pcall(function()
		spr:Load(SHADOW_ANM2, true)
		spr:Play("Idle", true)
	end)
	if not ok then
		return nil
	end
	_shadow_sprite = spr
	return spr
end

--- Entity PRE/POST screen pos — project standard (locked).
-- W2S + callback offset - GetRenderScrollOffset().
-- See codex_work/notes/entity_render_scroll_offset_pitfalls.md
local function resolve_screen_formula(_unused)
	return "B"
end

local function entity_callback_screen_pos(world_pos, render_offset, _unused)
	local screen = Isaac.WorldToScreen(world_pos)
	if render_offset then
		screen = screen + render_offset
	end
	local room = Game():GetRoom()
	if room and room.GetRenderScrollOffset then
		screen = screen - room:GetRenderScrollOffset()
	end
	return screen
end

local function room_scroll_offset()
	local room = Game():GetRoom()
	if room and room.GetRenderScrollOffset then
		return room:GetRenderScrollOffset()
	end
	return Vector(0, 0)
end

--- One complete ground shadow under the spliced body (engine shadow stays 0).
local function draw_full_host_shadow(host, to, render_offset)
	local spr = ensure_shadow_sprite()
	if not spr or not host then
		return
	end
	-- Feet / ground at Position; do not add PositionOffset (body lift).
	local formula = resolve_screen_formula(to)
	local screen = entity_callback_screen_pos(host.Position, render_offset, formula)
	local scale = (to and to.saved_shadow_size) or read_entity_shadow_size(host)
	if not scale or scale <= 0 then
		scale = 0.1
	end
	spr.Scale = Vector(scale, scale)
	spr.Color = Color(1, 1, 1, 1)
	spr:SetFrame("Idle", 0)
	pcall(function()
		spr:Render(screen, Vector.Zero, Vector.Zero)
	end)
end

local function resolve_anm2(type_id, variant, subtype)
	if not EntityConfig or not EntityConfig.GetEntity then
		return nil, "EntityConfig.GetEntity missing"
	end
	local ok, cfg = pcall(function()
		return EntityConfig.GetEntity(type_id, variant or 0, subtype or 0)
	end)
	if not ok or not cfg then
		return nil, "EntityConfig.GetEntity failed"
	end
	if not cfg.GetAnm2Path then
		return nil, "GetAnm2Path missing"
	end
	local ok2, path = pcall(function()
		return cfg:GetAnm2Path()
	end)
	if not ok2 or type(path) ~= "string" or path == "" then
		return nil, "empty anm2 path"
	end
	return path, nil
end

local function play_donor_anim(sprite, donor)
	local candidates = donor.animation_candidates or { "Idle" }
	for i = 1, #candidates do
		local name = candidates[i]
		local ok = pcall(function()
			sprite:Play(name, true)
		end)
		if ok and sprite:IsPlaying(name) then
			return name
		end
		if ok then
			local anim = sprite.GetAnimation and sprite:GetAnimation() or nil
			if anim == name then
				return name
			end
		end
	end
	return nil
end

local function as_xy(t, fx, fy)
	if not t then return fx or 0, fy or 0 end
	if t.X ~= nil then return t.X or fx or 0, t.Y or fy or 0 end
	return t[1] or fx or 0, t[2] or fy or 0
end

local function as_vector(t, fx, fy)
	local x, y = as_xy(t, fx, fy)
	return Vector(x, y)
end

local function angle_of(v)
	return math.deg(math.atan(v.Y, v.X))
end

local function host_sprite(host)
	return host and host.GetSprite and host:GetSprite() or nil
end

local function host_visible(host)
	if not host or not host:Exists() then return false end
	if host.Visible == false then return false end
	local spr = host_sprite(host)
	if spr and spr.Color and (spr.Color.A or 1) <= 0.02 then
		return false
	end
	if spr and spr.Scale then
		local sx = math.abs(spr.Scale.X or 1)
		local sy = math.abs(spr.Scale.Y or 1)
		if sx < 0.02 and sy < 0.02 then
			return false
		end
	end
	return true
end

local function host_tint(host)
	local spr = host_sprite(host)
	local c = (spr and spr.Color) or Color(1, 1, 1, 1)
	local r, g, b, a = c.R or 1, c.G or 1, c.B or 1, c.A or 1
	return KColor(r, g, b, a), Color(r, g, b, a)
end

local function host_scale_factor(host)
	local spr = host_sprite(host)
	if not spr or not spr.Scale then return 1 end
	return (math.abs(spr.Scale.X or 1) + math.abs(spr.Scale.Y or 1)) * 0.5
end

local function scan_direction_for(host, graft)
	local dir = as_vector(graft.scan_direction or graft.normalized_host_offset, 1, -0.2)
	local spr = host_sprite(host)
	if spr then
		if spr.FlipX then dir = Vector(-dir.X, dir.Y) end
		if spr.FlipY then dir = Vector(dir.X, -dir.Y) end
	end
	if dir:Length() < 1e-4 then
		return Vector(1, 0)
	end
	return dir:Normalized()
end

local function refresh_edge(host, graft)
	local dir = scan_direction_for(host, graft)
	if not graft.use_host_edge then
		local size = math.max(8, host.Size or 12)
		local ox, oy = as_xy(graft.normalized_host_offset, 0.85, -0.1)
		graft.edge = {
			localPos = Vector(ox * size, oy * size),
			normal = dir,
			source = "offset",
		}
		_status.last_edge_source = "offset"
		return graft.edge
	end
	graft.edge = host_edge.update_edge_cache(graft.edge, host, dir)
	_status.last_edge_source = graft.edge and graft.edge.source or "none"
	return graft.edge
end

local function resolve_pose(host, graft)
	local spr = host_sprite(host)
	local po = host.PositionOffset or Vector(0, 0)
	local dx, dy = as_xy(graft.donor_offset, 0, 0)

	-- Gate3C: center both RTs on the host render point (complementary KeepSign).
	if graft.align == "host_center" then
		local host_joint = host.Position + po + Vector(dx, dy)
		local n = as_vector(graft.cut_normal, 1, 0)
		if n:Length() < 1e-4 then n = Vector(1, 0) else n = n:Normalized() end
		return {
			host_joint_world = host_joint,
			host_normal = n,
			rotation = graft.rotation or 0,
			donor_uv = { 0.5, 0.5 },
			scale = (graft.scale or 1) * host_scale_factor(host),
			edge_source = "host_center",
			flip_x = false,
			flip_y = false,
			host_flip_x = spr and spr.FlipX == true,
			host_flip_y = spr and spr.FlipY == true,
		}
	end

	local edge = refresh_edge(host, graft)
	local host_joint = host.Position + po + edge.localPos
	host_joint = host_joint + Vector(dx, dy)

	local host_n = edge.normal
	if not host_n or host_n:Length() < 1e-4 then
		host_n = Vector(1, 0)
	else
		host_n = host_n:Normalized()
	end

	local dj = graft.donor_joint or { uv = { 0.5, 0.5 }, normal = { -1, 0 } }
	local donor_n = as_vector(dj.normal, -1, 0)
	if donor_n:Length() < 1e-4 then
		donor_n = Vector(-1, 0)
	else
		donor_n = donor_n:Normalized()
	end
	local want = Vector(-host_n.X, -host_n.Y)
	local rotation = angle_of(want) - angle_of(donor_n) + (graft.rotation or 0)

	return {
		host_joint_world = host_joint,
		host_normal = host_n,
		rotation = rotation,
		donor_uv = dj.uv or { 0.5, 0.5 },
		scale = (graft.scale or 1) * host_scale_factor(host),
		edge_source = edge.source,
		-- Do NOT mirror the donor quad with host FlipX/Y.
		-- Edge localPos + normal rotation already follow Flip; mirroring again
		-- buries the kept half inside the body whenever the NPC faces the other way.
		flip_x = false,
		flip_y = false,
		host_flip_x = spr and spr.FlipX == true,
		host_flip_y = spr and spr.FlipY == true,
	}
end

function M.get_status()
	api_ready()
	load_clip_shader()
	return {
		api = _status.api,
		shader = _status.shader,
		last_error = _status.last_error,
		gate1_ok = _status.gate1_ok,
		gate2_ok = _status.gate2_ok,
		gate2_5_ok = _status.gate2_5_ok,
		gate3_ok = _status.gate3_ok,
		gate3a_ok = _status.gate3a_ok,
		gate3b_ok = _status.gate3b_ok,
		gate3c_ok = _status.gate3c_ok,
		gate3d_ok = _status.gate3d_ok,
		last_seam_align = _status.last_seam_align,
		last_bake_ok = _status.last_bake_ok,
		last_blit_mode = _status.last_blit_mode,
		last_edge_source = _status.last_edge_source,
		last_draw_order = _status.last_draw_order,
		last_host_flip_x = _status.last_host_flip_x,
		last_takeover_mode = _status.last_takeover_mode,
		last_verify_mode = _status.last_verify_mode,
		last_export_path = _status.last_export_path,
		last_export_error = _status.last_export_error,
		last_export_nonzero = _status.last_export_nonzero,
		last_diag_path = _status.last_diag_path,
		last_diag_error = _status.last_diag_error,
		last_residual_error_px = _status.last_residual_error_px,
		last_math_ok = _status.last_math_ok == true,
		gate3d_phase = _status.gate3d_phase or "diagnostic",
		screen_pos_formula = _status.screen_pos_formula or "B",
		last_render_align = _status.last_render_align,
		diag_overlay = _diag.overlay == true,
		active_takeovers = (function()
			local n = 0
			for _ in pairs(_takeovers) do n = n + 1 end
			return n
		end)(),
		active_grafts = count_active(),
		perf = {
			bakes_per_s = _perf.bakes_per_s,
			bake_skips_per_s = _perf.bake_skips_per_s,
			texel_reads_per_s = _perf.texel_reads_per_s,
			geometry_analyzes_per_s = _perf.geometry_analyzes_per_s,
			geometry_skips_per_s = _perf.geometry_skips_per_s,
			donor_hits_per_s = _perf.donor_hits_per_s,
			donor_misses_per_s = _perf.donor_misses_per_s,
			donor_cache_entries = (function()
				local n = 0
				for _ in pairs(_donor_geom_cache) do n = n + 1 end
				return n
			end)(),
		},
		active_hosts = (function()
			local n = 0
			for _ in pairs(_grafts) do n = n + 1 end
			return n
		end)(),
	}
end

function M.get_donor(id)
	return donors[id]
end

function M.list_donors()
	local list = {}
	for id, d in pairs(donors) do
		list[#list + 1] = { id = id, label = d.label or id }
	end
	table.sort(list, function(a, b) return a.id < b.id end)
	return list
end

local function clear_takeovers()
	for _, to in pairs(_takeovers) do
		restore_host_engine_shadow(to, to.host)
		release_target(to.target)
	end
	_takeovers = {}
	_status.last_takeover_mode = "none"
end

function M.clear_all()
	for _, list in pairs(_grafts) do
		for i = 1, #list do
			release_target(list[i].target)
		end
	end
	_grafts = {}
	_donor_geom_cache = {}
	clear_takeovers()
	_status.gate3c_ok = false
	_status.gate3d_ok = false
	_status.last_math_ok = false
	_status.last_residual_error_px = nil
	_status.last_diag_path = nil
	_status.last_diag_error = nil
	_status.last_seam_align = "none"
	_status.gate3d_phase = "diagnostic"
	_diag.overlay = false
	_diag.host = nil
	_diag.donor = nil
	_diag.final = nil
	_diag.layers = nil
	_seam_align_tick = 0
end

function M.attach(host, donor_id, overrides)
	overrides = overrides or {}
	if not host or not api_ready() then return nil end
	local donor = donors[donor_id]
	if not donor then
		set_error("unknown donor " .. tostring(donor_id))
		return nil
	end
	local key = GetPtrHash(host)
	local replacing = _grafts[key] ~= nil
	if not replacing and count_active() >= M.MAX_ACTIVE then
		set_error("MAX_ACTIVE graft limit reached")
		return nil
	end
	local path, err = resolve_anm2(donor.type, donor.variant, donor.subtype)
	if not path then
		set_error(err or "anm2 resolve failed")
		return nil
	end
	local sprite = Sprite()
	local ok_load = pcall(function()
		sprite:Load(path, true)
	end)
	if not ok_load then
		set_error("Sprite:Load failed for " .. tostring(path))
		return nil
	end
	local anim = play_donor_anim(sprite, donor)
	local size = overrides.target_size or donor.target_size or M.TARGET_SIZE
	local target = acquire_target(size)
	if not target then return nil end

	local cut = donor.cut or {}
	local attach = donor.attach or {}
	local joint = donor.donor_joint or {}
	local graft = {
		donor_id = donor_id,
		path = path,
		animation = anim,
		sprite = sprite,
		target = target,
		size = size,
		cut_origin = overrides.cut_origin or cut.origin or (joint.uv and { joint.uv[1], joint.uv[2] }) or { 0.5, 0.5 },
		cut_normal = overrides.cut_normal or cut.normal or { 1, 0 },
		keep_sign = overrides.keep_sign or cut.keep_sign or -1,
		feather = overrides.feather or cut.feather or 0,
		-- Draw order:
		--   "front"  -> MC_POST_NPC_RENDER (over host). Use this to validate attachment.
		--   "behind" -> MC_PRE_NPC_RENDER  (under host). Only useful once the organ
		--              truly protrudes past the silhouette; otherwise Host covers it all.
		draw_order = overrides.draw_order or attach.draw_order or "front",
		normalized_host_offset = overrides.normalized_host_offset or attach.normalized_host_offset or { 0.85, -0.1 },
		scan_direction = overrides.scan_direction or attach.scan_direction or attach.normalized_host_offset or { 1.0, -0.2 },
		donor_offset = overrides.donor_offset or attach.donor_offset or { 0, 0 },
		rotation = overrides.rotation or attach.rotation or 0,
		scale = overrides.scale or attach.scale or 1,
		use_clip = overrides.use_clip,
		use_host_edge = overrides.use_host_edge,
		align = overrides.align, -- "host_center" for Gate3C/3D
		complementary = overrides.complementary == true,
		seam_align = overrides.seam_align == true,
		base_scale = overrides.scale or attach.scale or 1,
		visual_dirty = true,
		geometry_dirty = true,
		last_visual_key = nil,
		seam_align_screen = nil,
		seam_tangent_scale = 1,
		seam_normal_scale = 1,
		show_seam = overrides.show_seam,
		donor_joint = overrides.donor_joint or {
			uv = joint.uv or { 0.5, 0.5 },
			normal = joint.normal or { -1, 0 },
		},
		edge = nil,
		baked = false,
		dirty = true,
	}
	if graft.use_clip == nil then
		graft.use_clip = true
	end
	if graft.use_host_edge == nil then
		if graft.align == "host_center" or graft.complementary then
			graft.use_host_edge = false
		else
			graft.use_host_edge = attach.use_host_edge ~= false
		end
	end
	-- Seam marks optional; Gate3 validation leaves them off until joint looks right.
	if graft.show_seam == nil then
		graft.show_seam = attach.show_seam == true
	end

	local prev = _grafts[key]
	if prev then
		for i = 1, #prev do
			release_target(prev[i].target)
		end
	end
	_grafts[key] = { graft }
	return graft
end

function M.detach(host)
	if not host then return end
	local key = GetPtrHash(host)
	local list = _grafts[key]
	if not list then return end
	for i = 1, #list do
		release_target(list[i].target)
	end
	_grafts[key] = nil
end

--- Latest graft list for a host (room-local). Prefer first graft for attack presentation.
function M.get_grafts(host)
	if not host then return nil end
	return _grafts[GetPtrHash(host)]
end

function M.get_primary_graft(host)
	local list = M.get_grafts(host)
	return list and list[1] or nil
end

--- Attach a donor-like visual source without donors.lua lookup.
--- visual = { id?, source={type,variant,subtype}, visual={animation_candidates,target_size}, ... }
function M.attach_visual_source(host, visual, overrides)
	overrides = overrides or {}
	if not host or not api_ready() or type(visual) ~= "table" then
		return nil
	end
	local src = visual.source or visual
	local type_id = tonumber(src.type)
	if not type_id then
		set_error("attach_visual_source: missing source.type")
		return nil
	end
	local donor_like = {
		id = visual.id or "profile_visual",
		type = type_id,
		variant = tonumber(src.variant) or 0,
		subtype = tonumber(src.subtype) or 0,
		animation_candidates = (visual.runtime_visual and visual.runtime_visual.animation_candidates)
			or (visual.visual and visual.visual.animation_candidates)
			or visual.animation_candidates
			or { "Idle", "Walk", "Fly", "Attack" },
		target_size = (visual.runtime_visual and visual.runtime_visual.target_size)
			or (visual.visual and visual.visual.target_size)
			or visual.target_size
			or M.TARGET_SIZE,
		cut = visual.cut,
		attach = visual.attach,
		donor_joint = visual.donor_joint,
	}
	-- Temporarily register so M.attach can resolve; remove after.
	local temp_id = tostring(donor_like.id) .. "_tmp_" .. tostring(GetPtrHash(host))
	donors[temp_id] = donor_like
	local graft = M.attach(host, temp_id, overrides)
	donors[temp_id] = nil
	if graft then
		graft.donor_id = visual.id or donor_like.id
	end
	return graft
end

local function bake_all_targets()
	if not next(_grafts) then return end
	_status.last_bake_ok = false
	for _, list in pairs(_grafts) do
		for i = 1, #list do
			local graft = list[i]
			local slot = graft.target
			local sprite = graft.sprite
			if slot and sprite then
				-- Always advance animation; rebake only when silhouette key changes.
				if not graft.freeze_sprite then
					sprite:Update()
				end
				local key = sprite_frame_key(sprite)
				local need_bake = graft.visual_dirty == true
					or graft.baked ~= true
					or graft.last_visual_key ~= key
					or graft.dirty == true
				if graft.freeze_bake and graft.baked and not graft.dirty and not graft.visual_dirty then
					need_bake = false
				end
				if not need_bake then
					_status.last_bake_ok = true
					_perf.bake_skips = (_perf.bake_skips or 0) + 1
				else
					local size = slot.size
					local center = Vector(size * 0.5, size * 0.5)
					local ok, err = pcall(function()
						Renderer.RenderToImage(slot.image, function(controller)
							if controller and controller.Clear then
								controller:Clear()
							end
							sprite.Color = Color(1, 1, 1, 1)
							sprite.Scale = Vector(1, 1)
							sprite.Rotation = 0
							sprite.Offset = Vector(0, 0)
							render_sprite_without_shadow(sprite, center)
						end)
					end)
					_perf.bakes = (_perf.bakes or 0) + 1
					if ok then
						local frame_changed = graft.last_visual_key ~= key
						graft.baked = true
						graft.dirty = false
						graft.visual_dirty = false
						graft.last_visual_key = key
						_status.gate1_ok = true
						_status.last_bake_ok = true
						if graft.seam_align and frame_changed then
							graft.geometry_dirty = true
							graft.seam_align_dirty = true
							graft.geom_cache = nil
						end
					else
						set_error("RenderToImage failed: " .. tostring(err))
						graft.baked = false
					end
				end
			end
		end
	end
end

local function build_rotated_dest_quad(joint_screen, logical_size, scale, rotation_deg, donor_uv, flip_x, flip_y)
	local S = logical_size * (scale or 1)
	local u = (donor_uv and donor_uv[1]) or 0.5
	local v = (donor_uv and donor_uv[2]) or 0.5
	local joint_from_tl = Vector(u * S, v * S)
	local tl = joint_screen - joint_from_tl
	local dst = DestinationQuad.NewFromRectangle(tl, S, S)
	if (flip_x or flip_y) and dst.Scale then
		local sx = flip_x and -1 or 1
		local sy = flip_y and -1 or 1
		dst:Scale(Vector(sx, sy), joint_screen)
	elseif (flip_x or flip_y) and dst.Flip then
		dst:Flip(flip_x == true, flip_y == true)
	end
	if rotation_deg and math.abs(rotation_deg) > 0.01 and dst.Rotate then
		dst:Rotate(rotation_deg, joint_screen)
	end
	return dst
end

local function blit_graft_image(graft, joint_screen, pose, tint_k)
	local slot = graft.target
	if not slot or not slot.image or not graft.baked then
		_status.last_blit_mode = "skip_unbaked"
		return
	end
	local logical = slot.size
	local src = SourceQuad.NewFromRectangle(Vector(0, 0), logical, logical, false)
	local dst = build_rotated_dest_quad(
		joint_screen,
		logical,
		pose.scale,
		pose.rotation,
		pose.donor_uv,
		pose.flip_x,
		pose.flip_y
	)
	-- Gate3D: stretch along cut tangent so Host/Donor interface lengths match.
	if graft.seam_align then
		apply_tangent_stretch(
			dst,
			joint_screen,
			graft.cut_normal,
			graft.seam_normal_scale or 1,
			graft.seam_tangent_scale or 1
		)
	end
	-- Original colors: Gate3C once used cyan to prove donor was drawn; Gate3D
	-- needs true palette so interface gaps are readable.
	local color = tint_k or KColor(1, 1, 1, 1)

	local padded_w = (slot.image.GetPaddedWidth and slot.image:GetPaddedWidth()) or logical
	local padded_h = (slot.image.GetPaddedHeight and slot.image:GetPaddedHeight()) or logical
	local logical_w = (slot.image.GetWidth and slot.image:GetWidth()) or logical
	local logical_h = (slot.image.GetHeight and slot.image:GetHeight()) or logical

	if graft.use_clip then
		local shader = load_clip_shader()
		if shader and slot.image.RenderWithShader then
			local ok, err = pcall(function()
				slot.image:RenderWithShader(src, dst, color, shader, {
					TextureSize = { padded_w, padded_h },
					LogicalSize = { logical_w, logical_h },
					CutOrigin = { graft.cut_origin[1] or 0.5, graft.cut_origin[2] or 0.5 },
					CutNormal = { graft.cut_normal[1] or 1, graft.cut_normal[2] or 0 },
					KeepSign = graft.keep_sign or -1,
					Feather = graft.feather or 0,
				})
			end)
			if ok then
				_status.gate2_ok = true
				_status.last_blit_mode = "clip"
				if graft.complementary or graft.align == "host_center" then
					_status.gate3c_ok = true
					_status.last_blit_mode = "splice_donor_clip"
					if graft.seam_align and graft.interface_local then
						-- Do NOT force gate3d_ok here — residual math / RT dumps own diagnostic truth.
						_status.last_blit_mode = "splice_align"
					end
				end
				return
			end
			set_error("RenderWithShader failed: " .. tostring(err))
			_status.last_blit_mode = "clip_fail_fallback"
		else
			_status.last_blit_mode = "clip_unavailable_fallback"
			if not shader then
				set_error(_status.last_error or "clip shader unavailable")
			end
		end
	end

	if slot.image.Render then
		pcall(function()
			slot.image:Render(src, dst, color)
		end)
		if not graft.use_clip then
			_status.last_blit_mode = "full"
		end
	end
end

local function render_seam_at(joint_screen, host_normal, tint_color)
	if not ensure_seam_sprites() then return end
	local n = host_normal
	if not n or n:Length() < 1e-4 then
		n = Vector(1, 0)
	else
		n = n:Normalized()
	end
	local tangent = Vector(-n.Y, n.X)
	local seam_rot = angle_of(tangent)
	local col = tint_color or Color(1, 1, 1, 1)

	local function draw(spr, anim, pos, rot, sx, sy)
		spr:SetFrame(anim, 0)
		spr.Rotation = rot or 0
		spr.Scale = Vector(sx or 1, sy or 1)
		spr.Color = col
		spr.Offset = Vector(0, 0)
		spr:Render(pos, Vector(0, 0), Vector(0, 0))
		spr.Scale = Vector(1, 1)
		spr.Rotation = 0
		spr.Color = Color(1, 1, 1, 1)
	end

	draw(_seam.wound, "WoundSmall", joint_screen, seam_rot, 1.1, 1.0)
	local spacing = 5
	for i = -1, 1 do
		local p = joint_screen + tangent * (i * spacing)
		draw(_seam.stitch, "Stitch", p, seam_rot, 1, 1)
	end
	local thread_a = joint_screen - tangent * (spacing * 1.35)
	local thread_b = joint_screen + tangent * (spacing * 1.35)
	draw(_seam.thread, "Thread", thread_a, seam_rot, 0.7, 0.85)
	draw(_seam.thread, "Thread", thread_b, seam_rot + 180, 0.7, 0.85)
	draw(_seam.knot, "Knot", joint_screen + n * 1.5, seam_rot, 0.9, 0.9)
end

function M.render_for_host(host, order, render_offset)
	if not host_visible(host) then return end
	local list = _grafts[GetPtrHash(host)]
	if not list then return end
	order = order or "front"
	render_offset = render_offset or Vector(0, 0)
	local tint_k, tint_c = host_tint(host)
	local to = _takeovers[GetPtrHash(host)]
	local formula = resolve_screen_formula(to)

	for i = 1, #list do
		local graft = list[i]
		local pose = resolve_pose(host, graft)
		local joint_screen = entity_callback_screen_pos(pose.host_joint_world, render_offset, formula)
		-- Screen delta is computed EVERY render from RT-local interface points.
		-- Never reuse a baked seam_align_screen across Update/Render frames.
		if graft.seam_align then
			local delta = compute_seam_delta_at_render(to, graft, pose, joint_screen, render_offset, formula)
			if delta then
				joint_screen = joint_screen + delta
			end
		end
		_status.last_draw_order = tostring(graft.draw_order)
		_status.last_host_flip_x = pose.host_flip_x == true

		if graft.draw_order == order then
			-- Complementary / Gate3D: keep donor's own palette (do not multiply by Host Color).
			local graft_tint = tint_k
			if graft.complementary or graft.seam_align or graft.align == "host_center" then
				graft_tint = KColor(1, 1, 1, 1)
			end
			blit_graft_image(graft, joint_screen, pose, graft_tint)
			if graft.use_host_edge and graft.use_clip and pose.edge_source and pose.edge_source ~= "size" and pose.edge_source ~= "offset" then
				_status.gate2_5_ok = true
				_status.gate3_ok = true -- transitional alias
			end
		end

		if order == "front" and graft.show_seam then
			render_seam_at(joint_screen, pose.host_normal, tint_c)
		end
	end
end


--- Gate3A: cancel default NPC draw; blit a baked copy of host:GetSprite().
function M.begin_host_takeover(host, opts)
	opts = opts or {}
	if not host or not api_ready() then return nil end
	local key = GetPtrHash(host)
	-- Clean prior graft on this host so we only test takeover.
	if _grafts[key] then
		for i = 1, #_grafts[key] do
			release_target(_grafts[key][i].target)
		end
		_grafts[key] = nil
	end
	if _takeovers[key] then
		release_target(_takeovers[key].target)
	end
	local size = opts.target_size or M.TARGET_SIZE
	local target = acquire_target(size)
	if not target then return nil end
	local use_clip = opts.use_clip == true
	local to = {
		host = host,
		target = target,
		size = size,
		baked = false,
		mode = opts.mode or (use_clip and "clip" or "full"),
		use_clip = use_clip,
		cut_origin = opts.cut_origin or { 0.5, 0.5 },
		cut_normal = opts.cut_normal or { 1, 0 },
		keep_sign = opts.keep_sign or -1,
		feather = opts.feather or 0,
		-- verify_mode: "match" | "tint" | "blank" | "parity"
		-- parity: keep vanilla draw; overlay RT at 50% tint for formula A/B audit.
		verify_mode = opts.verify_mode or (use_clip and "match" or "tint"),
		show_marker = opts.show_marker ~= false,
		splice = opts.splice == true,
		seam_align = opts.seam_align == true,
		visual_dirty = true,
		geometry_dirty = true,
		last_visual_key = nil,
		screen_pos_formula = opts.screen_pos_formula or _status.screen_pos_formula or "B",
		cancel_vanilla = opts.cancel_vanilla,
	}
	if to.verify_mode == "parity" then
		to.cancel_vanilla = false
		to.show_marker = opts.show_marker ~= false
	elseif to.cancel_vanilla == nil then
		to.cancel_vanilla = true
	end
	if to.splice then
		to.mode = "splice"
	end
	if to.cancel_vanilla ~= false then
		suppress_host_engine_shadow(to, host)
	end
	_takeovers[key] = to
	_status.last_takeover_mode = to.mode
	_status.last_verify_mode = to.verify_mode
	_status.screen_pos_formula = to.screen_pos_formula
	-- Bake immediately so the next PRE/POST render is not blank (ImGui click
	-- often happens while Update is paused / between ticks).
	bake_one_takeover(to)
	return to
end

function M.end_host_takeover(host)
	if not host then return end
	local key = GetPtrHash(host)
	local to = _takeovers[key]
	if not to then return end
	restore_host_engine_shadow(to, host)
	release_target(to.target)
	_takeovers[key] = nil
end

bake_one_takeover = function(to)
	if not to then return false end
	local host = to.host
	if not host or not host:Exists() then
		return false
	end
	to.host = host
	local spr = host:GetSprite()
	local slot = to.target
	if not spr or not slot then
		return false
	end
	local key = sprite_frame_key(spr)
	local need_bake = to.visual_dirty == true
		or to.baked ~= true
		or to.last_visual_key ~= key
		or to.dirty == true
	if to.freeze_bake and to.baked and not to.dirty and not to.visual_dirty then
		need_bake = false
	end
	if not need_bake then
		_status.last_bake_ok = true
		_perf.bake_skips = (_perf.bake_skips or 0) + 1
		return true
	end
	local size = slot.size
	local center = Vector(size * 0.5, size * 0.5)
	if to.cancel_vanilla ~= false then
		suppress_host_engine_shadow(to, host)
	end
	local ok, err = pcall(function()
		Renderer.RenderToImage(slot.image, function(controller)
			if controller and controller.Clear then
				controller:Clear()
			end
			render_sprite_without_shadow(spr, center)
		end)
	end)
	_perf.bakes = (_perf.bakes or 0) + 1
	if ok then
		local frame_changed = to.last_visual_key ~= key
		to.baked = true
		to.dirty = false
		to.visual_dirty = false
		to.last_visual_key = key
		_status.last_bake_ok = true
		if to.mode == "full" or not to.use_clip then
			_status.gate3a_ok = true
		end
		if to.seam_align and frame_changed then
			to.geometry_dirty = true
			to.seam_align_dirty = true
			to.geom_cache = nil
		end
		return true
	end
	set_error("Host RenderToImage failed: " .. tostring(err))
	to.baked = false
	return false
end

local function bake_all_takeovers()
	if not next(_takeovers) then return end
	for key, to in pairs(_takeovers) do
		local host = to.host
		if not host or not host:Exists() then
			restore_host_engine_shadow(to, host)
			release_target(to.target)
			_takeovers[key] = nil
		else
			bake_one_takeover(to)
		end
	end
end

local function draw_takeover_marker(screen, label)
	-- Keep Gate3A/B proof markers; Gate3D sets show_marker=false so the seam stays visible.
	if not screen then return end
	pcall(function()
		Isaac.RenderText(label or "3A", screen.X - 10, screen.Y - 56, 0, 1, 1, 1)
	end)
end

local function blit_takeover_full(host, to, render_offset)
	local slot = to.target
	if not slot or not slot.image or not to.baked then
		_status.last_blit_mode = "takeover_unbaked"
		if to.show_marker ~= false then
			local po = host.PositionOffset or Vector(0, 0)
			local formula = resolve_screen_formula(to)
			local screen = entity_callback_screen_pos(host.Position + po, render_offset or Vector(0, 0), formula)
			draw_takeover_marker(screen, "UNBAKED")
		end
		return
	end
	render_offset = render_offset or Vector(0, 0)
	local po = host.PositionOffset or Vector(0, 0)
	local formula = resolve_screen_formula(to)
	local screen = entity_callback_screen_pos(host.Position + po, render_offset, formula)
	local logical = slot.size
	local half = logical * 0.5
	local tl = Vector(screen.X - half, screen.Y - half)
	local verify = to.verify_mode or "match"
	if verify ~= "blank" then
		local src = SourceQuad.NewFromRectangle(Vector(0, 0), logical, logical, false)
		local dst = DestinationQuad.NewFromRectangle(tl, logical, logical)
		local tint
		if verify == "parity" then
			-- Translucent green overlay on top of vanilla — ghosting = formula wrong.
			-- Strong green; must be drawn in POST so vanilla does not cover it.
			tint = KColor(0.05, 1.0, 0.15, 0.72)
		elseif verify == "tint" then
			tint = KColor(0.15, 1.0, 0.25, 1)
		else
			tint = KColor(1, 1, 1, 1)
		end
		local padded_w = (slot.image.GetPaddedWidth and slot.image:GetPaddedWidth()) or logical
		local padded_h = (slot.image.GetPaddedHeight and slot.image:GetPaddedHeight()) or logical
		local logical_w = (slot.image.GetWidth and slot.image:GetWidth()) or logical
		local logical_h = (slot.image.GetHeight and slot.image:GetHeight()) or logical
		local drew = false
		if to.use_clip then
			local shader = load_clip_shader()
			if shader and slot.image.RenderWithShader then
				local ok, err = pcall(function()
					slot.image:RenderWithShader(src, dst, tint, shader, {
						TextureSize = { padded_w, padded_h },
						LogicalSize = { logical_w, logical_h },
						CutOrigin = { to.cut_origin[1] or 0.5, to.cut_origin[2] or 0.5 },
						CutNormal = { to.cut_normal[1] or 1, to.cut_normal[2] or 0 },
						KeepSign = to.keep_sign or -1,
						Feather = to.feather or 0,
					})
				end)
				if ok then
					drew = true
					_status.gate3b_ok = true
					_status.last_blit_mode = (verify == "tint") and "takeover_clip_tint" or "takeover_clip"
				else
					set_error("Host clip RenderWithShader failed: " .. tostring(err))
					_status.last_blit_mode = "takeover_clip_fail"
				end
			else
				_status.last_blit_mode = "takeover_clip_unavailable"
				if not shader then
					set_error(_status.last_error or "clip shader unavailable")
				end
			end
		end
		-- Gate3B: never fall back to full blit on clip failure (would hide the bug).
		if not drew and not to.use_clip then
			pcall(function()
				slot.image:Render(src, dst, tint)
			end)
			if verify == "parity" then
				_status.last_blit_mode = "takeover_parity_" .. tostring(formula)
			elseif verify == "tint" then
				_status.last_blit_mode = "takeover_tint"
			else
				_status.last_blit_mode = "takeover_full"
			end
		end
	else
		-- Cancel-only: default NPC is suppressed; nothing drawn → body disappears.
		_status.last_blit_mode = "takeover_blank"
	end
	if to.show_marker ~= false then
		local label = "3A"
		if verify == "parity" then
			label = "PARITY-" .. tostring(formula)
		elseif verify == "blank" then
			label = "3A-BLANK"
		elseif (to.splice or to.mode == "splice") and to.seam_align then
			label = "3D-ALIGN"
		elseif to.splice or to.mode == "splice" then
			label = "3C-SPLICE"
		elseif to.use_clip then
			label = "3B-CLIP"
		end
		draw_takeover_marker(screen, label)
	end
	_status.last_verify_mode = verify

	-- Live parity HUD: compare paused vs running with the same formula.
	if verify == "parity" then
		local scroll = room_scroll_offset()
		local off = render_offset or Vector(0, 0)
		local paused = false
		pcall(function()
			paused = Game():IsPaused() == true
		end)
		_status.last_parity = {
			formula = formula,
			frame = Game():GetFrameCount(),
			paused = paused,
			pos = { host.Position.X, host.Position.Y },
			po = { po.X, po.Y },
			callback_offset = { off.X, off.Y },
			scroll = { scroll.X, scroll.Y },
			screen = { screen.X, screen.Y },
		}
		pcall(function()
			Isaac.RenderText(
				string.format(
					"PARITY %s %s f=%d off=(%.1f,%.1f) scroll=(%.1f,%.1f)",
					formula, paused and "PAUSE" or "RUN",
					_status.last_parity.frame,
					off.X, off.Y, scroll.X, scroll.Y
				),
				screen.X - 90, screen.Y - 72, 1, 1, 0.2, 1
			)
		end)
	end
end

function M.debug_takeover_nearest(opts)
	opts = opts or {}
	local player = Isaac.GetPlayer(0)
	if not player then return false, "no player" end
	local best, best_d
	local ents = Isaac.GetRoomEntities()
	for i = 1, #ents do
		local e = ents[i]
		local npc = e and e:ToNPC()
		if npc and npc:Exists() and not npc:IsDead() and npc:IsVulnerableEnemy() and not npc:IsBoss() then
			local d = (npc.Position - player.Position):Length()
			if not best_d or d < best_d then
				best, best_d = npc, d
			end
		end
	end
	if not best then return false, "no host enemy" end
	-- Isolate takeover: drop all grafts/takeovers first.
	M.clear_all()
	local use_clip = opts.use_clip == true
	local to = M.begin_host_takeover(best, {
		mode = use_clip and "clip" or "full",
		use_clip = use_clip,
		cut_origin = opts.cut_origin,
		cut_normal = opts.cut_normal,
		keep_sign = opts.keep_sign,
		feather = opts.feather,
		verify_mode = opts.verify_mode or (use_clip and "match" or "tint"),
		show_marker = opts.show_marker ~= false,
		screen_pos_formula = opts.screen_pos_formula,
		cancel_vanilla = opts.cancel_vanilla,
	})
	if not to then return false, _status.last_error or "takeover failed" end
	return true, best, to
end


--- Gate3C: host clipped half + donor complementary half; same plane; centers aligned.
function M.debug_splice_nearest(opts)
	opts = opts or {}
	local player = Isaac.GetPlayer(0)
	if not player then return false, "no player" end
	local best, best_d
	local ents = Isaac.GetRoomEntities()
	for i = 1, #ents do
		local e = ents[i]
		local npc = e and e:ToNPC()
		if npc and npc:Exists() and not npc:IsDead() and npc:IsVulnerableEnemy() and not npc:IsBoss() then
			local d = (npc.Position - player.Position):Length()
			if not best_d or d < best_d then
				best, best_d = npc, d
			end
		end
	end
	if not best then return false, "no host enemy" end

	local rad = opts.cut_angle_rad
	if rad == nil and opts.cut_angle_deg ~= nil then
		rad = math.rad(opts.cut_angle_deg)
	end
	rad = rad or 0
	local normal = opts.cut_normal or { math.cos(rad), math.sin(rad) }
	local origin = opts.cut_origin or { 0.5, 0.5 }
	local host_sign = opts.host_keep_sign or 1
	local donor_sign = opts.donor_keep_sign or -1
	local donor_id = opts.donor_id or "fly_wing"

	M.clear_all()
	local to = M.begin_host_takeover(best, {
		mode = "splice",
		splice = true,
		use_clip = true,
		cut_origin = origin,
		cut_normal = normal,
		keep_sign = host_sign,
		feather = opts.feather or 0,
		verify_mode = opts.verify_mode or "match",
		show_marker = opts.show_marker ~= false,
	})
	if not to then return false, _status.last_error or "host takeover failed" end

	local seam_align = opts.seam_align == true
	local graft = M.attach(best, donor_id, {
		use_clip = true,
		cut_origin = origin,
		cut_normal = normal,
		keep_sign = donor_sign,
		feather = opts.feather or 0,
		align = "host_center",
		complementary = true,
		seam_align = seam_align,
		use_host_edge = false,
		draw_order = "front",
		show_seam = false,
		donor_offset = { 0, 0 },
		rotation = 0,
		scale = opts.donor_scale or 1,
	})
	if not graft then return false, _status.last_error or "donor attach failed" end
	to.seam_align = seam_align
	-- Gate3D: do NOT freeze RT/sprite — pixels must keep animating.
	-- Host+Donor cut_origin lock after first refresh; interface/scale still per-frame.
	if seam_align then
		to.freeze_bake = false
		to.dirty = true
		to.seam_align_dirty = true
		to.cut_origin_locked = false
		to.seam_geometry_locked = false
		to.show_marker = false
		graft.freeze_bake = false
		graft.freeze_sprite = false
		graft.dirty = true
		graft.seam_align_dirty = true
		graft.cut_origin_locked = false
		graft.seam_geometry_locked = false
	end
	-- Bake both RTs now so the very next PRE render already has donor pixels.
	bake_all_targets()
	bake_all_takeovers()
	if seam_align then
		refresh_seam_align(to, graft)
		to.seam_align_dirty = false
		graft.seam_align_dirty = false
		-- Leave unlocked: POST_UPDATE rebake keeps refreshing seam.
		to.seam_geometry_locked = false
		graft.seam_geometry_locked = false
	end
	return true, best, to, graft
end

--- Baseline gameplay splice: movement half (host sprite) + attack half (donor sprite).
--- Fixed cut_angle=0, host_keep_sign=-1, donor_keep_sign=+1 unless overridden.
--- Reuses Gate3C/3D complementary path; does not rewrite compositor.
function M.attach_profile_pair(friend, movement_profile, attack_profile, opts)
	opts = opts or {}
	if not friend or not api_ready() then
		return nil
	end
	if type(movement_profile) ~= "table" or type(attack_profile) ~= "table" then
		set_error("attach_profile_pair: profiles required")
		return nil
	end
	local move_src = movement_profile.source or {}
	local path, err = resolve_anm2(
		tonumber(move_src.type),
		tonumber(move_src.variant) or 0,
		tonumber(move_src.subtype) or 0
	)
	if not path then
		set_error(err or "movement anm2 resolve failed")
		return nil
	end
	local spr = friend:GetSprite()
	if not spr then
		set_error("friend has no sprite")
		return nil
	end
	local ok_load = pcall(function()
		spr:Load(path, true)
	end)
	if not ok_load then
		set_error("failed to load movement anm2")
		return nil
	end
	play_donor_anim(spr, {
		animation_candidates = (movement_profile.runtime_visual and movement_profile.runtime_visual.animation_candidates)
			or (movement_profile.visual and movement_profile.visual.animation_candidates)
			or { "Idle", "Walk", "Fly", "WalkHoriz" },
	})

	local cut_angle = tonumber(opts.cut_angle) or 0
	local rad = math.rad(cut_angle)
	local normal = opts.cut_normal or { math.cos(rad), math.sin(rad) }
	local origin = opts.cut_origin or { 0.5, 0.5 }
	local host_sign = opts.host_keep_sign
	if host_sign == nil then host_sign = 1 end
	local donor_sign = opts.donor_keep_sign
	if donor_sign == nil then donor_sign = -1 end

	M.end_host_takeover(friend)
	M.detach(friend)

	local to = M.begin_host_takeover(friend, {
		mode = "splice",
		splice = true,
		use_clip = true,
		cut_origin = origin,
		cut_normal = normal,
		keep_sign = host_sign,
		feather = opts.feather or 0,
		verify_mode = opts.verify_mode or "match",
		show_marker = opts.show_marker == true,
		seam_align = opts.seam_align ~= false,
	})
	if not to then
		return nil
	end
	to.movement_profile = movement_profile
	to.attack_profile = attack_profile

	local graft = M.attach_visual_source(friend, attack_profile, {
		use_clip = true,
		cut_origin = origin,
		cut_normal = normal,
		keep_sign = donor_sign,
		feather = opts.feather or 0,
		align = "host_center",
		complementary = true,
		seam_align = opts.seam_align ~= false,
		use_host_edge = false,
		draw_order = "front",
		show_seam = false,
		donor_offset = { 0, 0 },
		rotation = 0,
		scale = opts.donor_scale or 1,
	})
	if not graft then
		M.end_host_takeover(friend)
		return nil
	end
	graft.attack_profile = attack_profile
	graft.movement_profile = movement_profile
	to.seam_align = opts.seam_align ~= false
	if to.seam_align then
		to.freeze_bake = false
		to.dirty = true
		to.seam_align_dirty = true
		to.cut_origin_locked = false
		to.seam_geometry_locked = false
		to.show_marker = false
		graft.freeze_bake = false
		graft.freeze_sprite = false
		graft.dirty = true
		graft.seam_align_dirty = true
		graft.cut_origin_locked = false
		graft.seam_geometry_locked = false
	end
	bake_all_targets()
	bake_all_takeovers()
	if to.seam_align then
		refresh_seam_align(to, graft)
		to.seam_align_dirty = false
		graft.seam_align_dirty = false
		to.seam_geometry_locked = false
		graft.seam_geometry_locked = false
	end
	_status.last_takeover_mode = "profile_pair"
	return to, graft
end

-- ---------------------------------------------------------------------------
-- Pure UI preview path — adapter over sprite_splice (no private seam math).
-- Bestiary sprites + BestiaryScale/Offset stay as the visual source.
-- Splice uses the same fixed-seam / centerline / NodePair scale policy as live
-- Runtime Stitch, WITHOUT Entity registration (already baked by Bestiary).
-- ---------------------------------------------------------------------------

local bestiary_visual = require("Qing_Remaster_scripts.auxiliary.runtime_stitch_bestiary_visual")

--- UI-preview geometry: fixed seam + measured centerline spans. No live Entity
--- silhouette registration; no geometry_prior / reference_span blend.
local PREVIEW_GEOMETRY_POLICY = {
	fixed_seam_plane = true,
	seam_normal_anchor = 0,
	stable_cut = true,
	geometry_node_cache = true,
	node_pair_scale = true,
	pose_geometry_cache = false,
	pose_registration_cache = false,
	silhouette_axis_registration = false,
	visual_center_registration = false,
	tangent_align = "range_mid",
	sample_step = 1,
	collect_cut_candidates = false,
	fixed_body_scale = false,
	min_scale = 0.35,
	max_scale = 2.5,
}

--- Create a screen-space stitched preview from two profiles (bestiary sprites).
--- Uses the same sprite_splice.solve_pair fixed-seam path as live stitch.
function M.create_profile_preview(movement_profile, attack_profile, opts)
	opts = opts or {}
	if not api_ready() then return nil end
	if type(movement_profile) ~= "table" or type(attack_profile) ~= "table" then
		set_error("create_profile_preview: profiles required")
		return nil
	end
	local host_vis, herr = bestiary_visual.build_from_source(movement_profile.source)
	if not host_vis then
		set_error(herr or "host bestiary build failed")
		return nil
	end
	local donor_vis, derr = bestiary_visual.build_from_source(attack_profile.source)
	if not donor_vis then
		bestiary_visual.destroy(host_vis)
		set_error(derr or "donor bestiary build failed")
		return nil
	end
	local pair, perr = sprite_splice.create({
		size = opts.target_size or M.TARGET_SIZE,
		cut_normal = opts.cut_normal or { 1, 0 },
		feather = opts.feather or 0,
		geometry_policy = opts.geometry_policy or PREVIEW_GEOMETRY_POLICY,
		host = {
			sprite = host_vis.sprite,
			draw = bestiary_visual.make_draw(host_vis),
			keep_sign = (opts.host_keep_sign ~= nil) and opts.host_keep_sign or 1,
			-- No reference_span: scale from measured Bestiary-frame centerline only.
			profile_kind = "movement",
			profile_id = movement_profile.id,
			ignore_geometry_frames = movement_profile.visual
				and movement_profile.visual.ignore_geometry_frames,
		},
		donor = {
			sprite = donor_vis.sprite,
			draw = bestiary_visual.make_draw(donor_vis),
			keep_sign = (opts.donor_keep_sign ~= nil) and opts.donor_keep_sign or -1,
			profile_kind = "attack",
			profile_id = attack_profile.id,
			ignore_geometry_frames = attack_profile.visual
				and attack_profile.visual.ignore_geometry_frames,
		},
	})
	if not pair then
		bestiary_visual.destroy(host_vis)
		bestiary_visual.destroy(donor_vis)
		set_error(perr or "sprite_splice.create failed")
		return nil
	end
	local preview = {
		host_visual = host_vis,
		donor_visual = donor_vis,
		pair = pair,
		move_id = movement_profile.id,
		attack_id = attack_profile.id,
		movement_profile = movement_profile,
		attack_profile = attack_profile,
		preview_w = opts.preview_w or 92,
		preview_h = opts.preview_h or 76,
		preview_max_scale = opts.preview_max_scale or 1.35,
		baked = pair.solution ~= nil,
		diag = nil,
		last_update_frame = nil,
	}
	sprite_splice.fit_to_box(pair, preview.preview_w, preview.preview_h, {
		max_scale = preview.preview_max_scale,
	})
	local d = sprite_splice.get_diagnostics(pair)
	preview.diag = d and {
		host_span = d.host_span or d.host_ref_span,
		donor_span = d.donor_span or d.donor_ref_span,
		frame_ratio = d.frame_ratio,
		final_scale = d.final_ratio,
		clamped = d.clamped,
		seam_residual = d.normal_residual,
		fit_scale = pair.presentation and pair.presentation.fit_scale,
		fit_common_offset = pair.presentation and pair.presentation.common_offset,
		geometry_policy = "preview_fixed_seam",
	} or nil
	return preview
end

function M.update_profile_preview(preview)
	if not preview or not preview.pair then return false end
	local frame = Game():GetFrameCount()
	if preview.last_update_frame == frame and preview.baked then
		return true
	end
	preview.last_update_frame = frame
	if preview.host_visual then bestiary_visual.update(preview.host_visual) end
	if preview.donor_visual then bestiary_visual.update(preview.donor_visual) end
	-- Keep pair sprite refs in sync with bestiary sprites.
	preview.pair.host.sprite = preview.host_visual and preview.host_visual.sprite
	preview.pair.donor.sprite = preview.donor_visual and preview.donor_visual.sprite
	preview.pair.host.draw = bestiary_visual.make_draw(preview.host_visual)
	preview.pair.donor.draw = bestiary_visual.make_draw(preview.donor_visual)
	local ok = sprite_splice.update(preview.pair)
	preview.baked = ok and preview.pair.solution ~= nil
	if not preview.baked then
		set_error(preview.pair.last_error or "preview update failed")
		return false
	end
	sprite_splice.fit_to_box(preview.pair, preview.preview_w, preview.preview_h, {
		max_scale = preview.preview_max_scale,
	})
	local d = sprite_splice.get_diagnostics(preview.pair)
	preview.diag = d and {
		host_span = d.host_span or d.host_ref_span,
		donor_span = d.donor_span or d.donor_ref_span,
		frame_ratio = d.frame_ratio,
		final_scale = d.final_ratio,
		clamped = d.clamped,
		seam_residual = d.normal_residual,
		fit_scale = preview.pair.presentation and preview.pair.presentation.fit_scale,
		fit_common_offset = preview.pair.presentation and preview.pair.presentation.common_offset,
		host_cut_origin = preview.pair.solution.host.cut_origin,
		donor_cut_origin = preview.pair.solution.donor.cut_origin,
		geometry_policy = "preview_fixed_seam",
	} or nil
	return true
end

function M.render_profile_preview(preview, screen_pos, highlight_mode)
	if not preview or not preview.pair or not screen_pos or not preview.baked then return end
	sprite_splice.render(preview.pair, screen_pos, {
		presentation = preview.pair.presentation,
		highlight = highlight_mode and true or false,
	})
end

function M.destroy_profile_preview(preview)
	if not preview then return end
	if preview.pair then
		sprite_splice.destroy(preview.pair)
		preview.pair = nil
	end
	bestiary_visual.destroy(preview.host_visual)
	bestiary_visual.destroy(preview.donor_visual)
	preview.host_visual = nil
	preview.donor_visual = nil
	preview.baked = false
	preview.diag = nil
	preview.last_update_frame = nil
end

function M.get_preview_diag(preview)
	return preview and preview.diag or nil
end

--- Probe-oriented snapshot of the central Bestiary preview (filter + presentation).
function M.get_preview_trace(preview)
	if not preview or not preview.pair then
		return nil
	end
	local pair = preview.pair
	local geom = sprite_splice.get_geometry_trace(pair) or sprite_splice.build_geometry_trace(pair)
	local pres = pair.presentation or {}
	local sol = pair.solution
	local diag = sol and sol.diagnostics or {}
	local Sc = geom and geom.scale or {}
	local Sol = geom and geom.solution or {}

	local function side_pack(side_tr, side_obj)
		side_tr = side_tr or {}
		local gf = side_tr.geometry_frame_filter or {}
		local cl = side_tr.centerline or {}
		local spr = side_obj and (side_obj.sprite or (side_obj.entity and side_obj.entity.GetSprite and side_obj.entity:GetSprite()))
		local anim = gf.anim or side_tr.anim
		local frame = gf.frame
		if frame == nil then
			frame = side_tr.sprite_frame
		end
		if (anim == nil or frame == nil) and spr then
			anim = anim or (spr.GetAnimation and spr:GetAnimation()) or nil
			if frame == nil and spr.GetFrame then
				frame = spr:GetFrame()
			end
		end
		return {
			anim = anim,
			frame = frame,
			profile_id = gf.profile_id or (side_obj and side_obj.profile_id),
			profile_kind = gf.profile_kind or (side_obj and side_obj.profile_kind),
			ignore_map_present = gf.ignore_map_present == true,
			ignore_map_source = gf.ignore_map_source,
			ignore_anim_present = gf.ignore_anim_present == true,
			ignore_frame_match = gf.ignore_frame_match == true,
			geometry_frame_ignored = gf.geometry_frame_ignored == true,
			ignore_source = gf.ignore_source,
			current_geometry_node_key = gf.current_geometry_node_key
				or side_tr.last_geometry_node_key,
			geometry_used_node_key = gf.geometry_used_node_key
				or side_tr.last_geometry_node_key,
			last_good_geometry_node_key = gf.last_good_geometry_node_key
				or side_tr.last_good_geometry_node_key,
			last_good_span = gf.last_good_span,
			last_good_mid = gf.last_good_mid,
			geometry_source = gf.geometry_source,
			centerline_st = cl.st or cl.centerline_st,
			centerline_ed = cl.ed or cl.centerline_ed,
			centerline_span = cl.span or cl.centerline_span or side_tr.interface_span,
			centerline_mid = cl.mid or cl.centerline_mid
				or (side_tr.interface and side_tr.interface.range_mid_t_px),
			crop_key = side_tr.crop_key or (side_obj and side_obj.last_geometry_node and side_obj.last_geometry_node.crop_key),
			flip_x = side_tr.flip_x,
			geometry_node_anim = side_tr.anim or anim,
			geometry_node_frame = side_tr.sprite_frame or frame,
		}
	end

	return {
		channel = "preview",
		frame = Game():GetFrameCount(),
		move_id = preview.move_id,
		attack_id = preview.attack_id,
		baked = preview.baked == true,
		host = side_pack(geom and geom.host, pair.host),
		donor = side_pack(geom and geom.donor, pair.donor),
		pair = {
			node_pair_key = Sc.node_pair_key or (pair.last_pose_geom_diag and pair.last_pose_geom_diag.pose_key),
			scale = tonumber(Sc.cached_pair_scale) or tonumber(Sc.body_scale) or tonumber(diag.final_ratio),
			host_span = tonumber(preview.diag and preview.diag.host_span)
				or tonumber(Sc.host_ref_span),
			donor_span = tonumber(preview.diag and preview.diag.donor_span)
				or tonumber(Sc.donor_ref_span),
			tangent_slide = Sol.tangent_slide or diag.tangent_slide,
			normal_residual = Sol.normal_residual or diag.normal_residual,
		},
		presentation = {
			fit_scale = tonumber(pres.fit_scale) or (preview.diag and preview.diag.fit_scale),
			common_offset = pres.common_offset
				or (preview.diag and preview.diag.fit_common_offset),
			host_final_offset = pres.host_offset,
			donor_final_offset = pres.donor_offset,
			host_scale = pres.host_scale,
			donor_scale = pres.donor_scale,
			union_center = pres.union_center,
		},
		geometry_trace = geom,
	}
end

--- Live-update cut plane on active Host takeovers (Gate3B slider).
function M.set_takeover_cut(opts)
	opts = opts or {}
	local n = 0
	for _, to in pairs(_takeovers) do
		-- Angle slider must not overwrite locked content-center cut origins.
		if opts.cut_origin and not to.cut_origin_locked then
			to.cut_origin = opts.cut_origin
		end
		if opts.cut_normal then to.cut_normal = opts.cut_normal end
		if opts.keep_sign ~= nil then to.keep_sign = opts.keep_sign end
		if opts.feather ~= nil then to.feather = opts.feather end
		if opts.use_clip ~= nil then
			to.use_clip = opts.use_clip == true
			if not to.splice then
				to.mode = to.use_clip and "clip" or "full"
			end
		end
		if to.seam_align then
			-- Cut-angle change: unlock once so S/translation recompute for the new normal.
			to.seam_geometry_locked = false
			to.seam_align_dirty = true
			to.geometry_dirty = true
			to.geom_cache = nil
			_donor_geom_cache = {}
		end
		n = n + 1
	end
	for _, list in pairs(_grafts) do
		for i = 1, #list do
			local graft = list[i]
			if graft.complementary or graft.align == "host_center" then
				-- Do not stomp per-sprite cut_origin from the angle slider.
				if opts.cut_origin and not graft.cut_origin_locked then
					graft.cut_origin = opts.cut_origin
				end
				if opts.cut_normal then graft.cut_normal = opts.cut_normal end
				if opts.feather ~= nil then graft.feather = opts.feather end
				if graft.seam_align then
					graft.seam_geometry_locked = false
					graft.seam_align_dirty = true
					graft.geometry_dirty = true
					graft.geom_cache = nil
				end
				n = n + 1
			end
		end
	end
	refresh_all_seam_aligns()
	for _, to in pairs(_takeovers) do
		if to.seam_align then
			to.seam_align_dirty = false
			to.seam_geometry_locked = true
		end
	end
	for _, list in pairs(_grafts) do
		for i = 1, #list do
			local g = list[i]
			if g.seam_align then
				g.seam_align_dirty = false
				g.seam_geometry_locked = true
			end
		end
	end
	return n
end

local function export_paths(name)
	return {
		"mods/Qing_remaster/codex_work/logs/" .. name,
		"../mods/Qing_remaster/codex_work/logs/" .. name,
	}
end

--- Read CreateImage / spritesheet texels. RGON docs say f32 RGBA for Image,
-- but some paths return u8 RGBA (4 bytes/pix) like spritesheets. Detect by size.
local function read_texel_blob(image, size)
	if not image or not image.GetTexelRegion then
		return nil, "GetTexelRegion unavailable"
	end
	_perf.texel_reads = (_perf.texel_reads or 0) + 1
	local ok, data = pcall(function()
		return image:GetTexelRegion(0, 0, size, size)
	end)
	if not ok or type(data) ~= "string" then
		return nil, "GetTexelRegion failed: " .. tostring(data)
	end
	local pixels = size * size
	local bytes = #data
	local fmt, bpp
	if bytes >= pixels * 16 then
		fmt, bpp = "f32", 16
	elseif bytes >= pixels * 4 then
		fmt, bpp = "u8", 4
	else
		return nil, string.format("short texel bytes=%d need>=%d", bytes, pixels * 4)
	end
	-- Row stride: tight size, or padded width if the blob is clearly wider.
	local row = size
	local padded = size
	if image.GetPaddedWidth then
		local pw = tonumber(image:GetPaddedWidth()) or size
		if pw > size and bytes >= pw * size * bpp then
			padded = pw
			row = pw
		end
	end
	return {
		data = data,
		bytes = bytes,
		fmt = fmt,
		bpp = bpp,
		size = size,
		row = row,
		padded = padded,
	}, nil
end

local function texel_alpha_at(blob, x, y)
	local row = blob.row or blob.size
	local idx = y * row + x
	if blob.fmt == "f32" then
		local off = idx * 16 + 1
		if off + 15 > #blob.data then return 0 end
		local a = string.unpack("<f", blob.data, off + 12)
		return a or 0
	end
	local off = idx * 4 + 4 -- 1-based alpha byte
	return (string.byte(blob.data, off) or 0) / 255
end

local function texel_luma_at(blob, x, y)
	local row = blob.row or blob.size
	local idx = y * row + x
	if blob.fmt == "f32" then
		local off = idx * 16 + 1
		if off + 15 > #blob.data then return 0 end
		local r = string.unpack("<f", blob.data, off) or 0
		local g = string.unpack("<f", blob.data, off + 4) or 0
		local b = string.unpack("<f", blob.data, off + 8) or 0
		return (r + g + b) / 3
	end
	local off = idx * 4 + 1
	local r = (string.byte(blob.data, off) or 0) / 255
	local g = (string.byte(blob.data, off + 1) or 0) / 255
	local b = (string.byte(blob.data, off + 2) or 0) / 255
	return (r + g + b) / 3
end

--- Soft foot oval: mid alpha + dark. Solid body ink (incl. black flies) usually a>=0.55.
local function is_soft_shadow_texel(blob, x, y, a)
	if not a or a < 0.05 or a >= 0.55 then
		return false
	end
	return texel_luma_at(blob, x, y) < 0.18
end

local function analyze_image_alpha_blob(blob, size, step)
	step = step or 2
	if not blob then return nil, "no blob" end
	local minx, miny, maxx, maxy = size, size, -1, -1
	local nonzero = 0
	for y = 0, size - 1, step do
		for x = 0, size - 1, step do
			local a = texel_alpha_at(blob, x, y)
			if a > 0.18 and not is_soft_shadow_texel(blob, x, y, a) then
				nonzero = nonzero + 1
				if x < minx then minx = x end
				if y < miny then miny = y end
				if x > maxx then maxx = x end
				if y > maxy then maxy = y end
			end
		end
	end
	return {
		size = size,
		step = step,
		nonzero_samples = nonzero,
		fmt = blob.fmt,
		bytes = blob.bytes,
		bbox = (maxx >= 0) and { minx = minx, miny = miny, maxx = maxx, maxy = maxy } or nil,
		_blob = blob,
	}, nil
end

local function analyze_image_alpha(image, size, step)
	step = step or 2
	local blob, berr = read_texel_blob(image, size)
	if not blob then return nil, berr end
	return analyze_image_alpha_blob(blob, size, step)
end


--- Measure keep-side cut INTERFACE. Gate3D stretches donor so keep_span matches Host.
local function analyze_cut_interface(image, size, cut_origin, cut_normal, keep_sign, step, opt_blob, clip_bbox)
	step = step or 2
	local blob = opt_blob
	if not blob then
		local berr
		blob, berr = read_texel_blob(image, size)
		if not blob then return nil, berr end
	end
	-- Skip soft foot-shadow fringe that can survive layer strip.
	local ALPHA_MIN = 0.18
	local ox = (cut_origin and cut_origin[1]) or 0.5
	local oy = (cut_origin and cut_origin[2]) or 0.5
	local nx = (cut_normal and cut_normal[1]) or 1
	local ny = (cut_normal and cut_normal[2]) or 0
	local nlen = math.sqrt(nx * nx + ny * ny)
	if nlen < 1e-6 then
		nx, ny = 1, 0
	else
		nx, ny = nx / nlen, ny / nlen
	end
	local sign = keep_sign or -1
	if math.abs(sign) < 1e-6 then sign = -1 end
	local tx, ty = -ny, nx
	local band = 2 / size -- ~2px cut-band; keep fallback => degraded

	local sumx, sumy, count = 0, 0, 0
	local t_min, t_max = nil, nil
	local keep_t_min, keep_t_max = nil, nil
	local keep_sumx, keep_sumy, keep_count = 0, 0, 0
	local minx, miny, maxx, maxy = size, size, -1, -1
	local nonzero = 0

	local x0, y0, x1, y1 = 0, 0, size - 1, size - 1
	if clip_bbox then
		x0 = math.max(0, tonumber(clip_bbox.minx) or 0)
		y0 = math.max(0, tonumber(clip_bbox.miny) or 0)
		x1 = math.min(size - 1, tonumber(clip_bbox.maxx) or (size - 1))
		y1 = math.min(size - 1, tonumber(clip_bbox.maxy) or (size - 1))
	end
	-- Narrow to cut-plane strip (~±3px) while keeping full tangent extent of bbox.
	do
		local band_px = 3
		local cx = ((cut_origin and cut_origin[1]) or 0.5) * size
		local cy = ((cut_origin and cut_origin[2]) or 0.5) * size
		local nnx = (cut_normal and cut_normal[1]) or 1
		local nny = (cut_normal and cut_normal[2]) or 0
		if math.abs(nnx) >= math.abs(nny) then
			x0 = math.max(x0, math.floor(cx - band_px))
			x1 = math.min(x1, math.ceil(cx + band_px))
		else
			y0 = math.max(y0, math.floor(cy - band_px))
			y1 = math.min(y1, math.ceil(cy + band_px))
		end
		if x1 < x0 or y1 < y0 then
			x0, y0, x1, y1 = 0, 0, size - 1, size - 1
		end
	end
	for y = y0, y1, step do
		for x = x0, x1, step do
			local a = texel_alpha_at(blob, x, y)
			if a > ALPHA_MIN and not is_soft_shadow_texel(blob, x, y, a) then
				nonzero = nonzero + 1
				if x < minx then minx = x end
				if y < miny then miny = y end
				if x > maxx then maxx = x end
				if y > maxy then maxy = y end
				local u = (x + 0.5) / size
				local v = (y + 0.5) / size
				local side = (u - ox) * nx + (v - oy) * ny
				local prod = side * sign
				if prod <= 0 then
					keep_count = keep_count + 1
					keep_sumx = keep_sumx + x
					keep_sumy = keep_sumy + y
					local tproj = (u - ox) * tx + (v - oy) * ty
					if keep_t_min == nil or tproj < keep_t_min then keep_t_min = tproj end
					if keep_t_max == nil or tproj > keep_t_max then keep_t_max = tproj end
					if math.abs(side) <= band then
						sumx = sumx + x
						sumy = sumy + y
						count = count + 1
						if t_min == nil or tproj < t_min then t_min = tproj end
						if t_max == nil or tproj > t_max then t_max = tproj end
					end
				end
			end
		end
	end

	local bbox = (maxx >= 0) and { minx = minx, miny = miny, maxx = maxx, maxy = maxy } or nil
	if keep_count < 1 then
		return {
			bbox = bbox,
			nonzero_samples = nonzero,
			count = 0,
			keep_count = 0,
			interface_span_px = 0,
			keep_span_px = 0,
			edge_centroid_from_center = { 0, 0 },
			keep_centroid_from_center = { 0, 0 },
			mode = "empty",
			fmt = blob.fmt,
			bytes = blob.bytes,
		}, nil
	end

	local band_span = 0
	if t_min ~= nil and t_max ~= nil then
		band_span = (t_max - t_min) * size
	end
	local keep_span = 0
	if keep_t_min ~= nil and keep_t_max ~= nil then
		keep_span = (keep_t_max - keep_t_min) * size
	end
	-- Band empty → use keep-side tangent span for stretch only (do not fake edge centroid).
	if band_span < 2 and keep_span >= 2 then
		band_span = keep_span
	end
	-- Last-resort span from full opaque bbox along tangent axis dominance.
	if keep_span < 2 and bbox then
		local bw = bbox.maxx - bbox.minx + 1
		local bh = bbox.maxy - bbox.miny + 1
		-- Upright cut (normal ~ horizontal) → vertical span = height.
		keep_span = math.abs(ty) >= math.abs(tx) and bh or bw
		if band_span < 2 then
			band_span = keep_span
		end
	end

	local half = size * 0.5
	local kcx = keep_sumx / keep_count
	local kcy = keep_sumy / keep_count
	local mode = "keep"
	local ecx, ecy = kcx, kcy
	if count >= 3 then
		mode = "band"
		ecx = sumx / count
		ecy = sumy / count
	end
	return {
		bbox = bbox,
		nonzero_samples = nonzero,
		count = count,
		keep_count = keep_count,
		interface_span_px = band_span,
		keep_span_px = keep_span,
		edge_centroid_from_center = { ecx - half, ecy - half },
		keep_centroid_from_center = { kcx - half, kcy - half },
		mode = mode,
		fmt = blob.fmt,
		bytes = blob.bytes,
	}, nil
end

local function content_center_uv(bbox, size)
	return splice_geometry.resolve_content_cut_origin(bbox, size)
end

--- Stretch DestinationQuad corners along cut axes (no Rotate dependency).
-- sn: along cut normal (thickness). st: along cut tangent (interface / 纵向).
apply_tangent_stretch = function(dst, joint_screen, cut_normal, scale_along_normal, scale_along_tangent)
	if not dst or not dst.GetTopLeft or not dst.SetTopLeft then
		return
	end
	local nx = (cut_normal and cut_normal[1]) or 1
	local ny = (cut_normal and cut_normal[2]) or 0
	local nlen = math.sqrt(nx * nx + ny * ny)
	if nlen < 1e-6 then
		nx, ny = 1, 0
	else
		nx, ny = nx / nlen, ny / nlen
	end
	local tx, ty = -ny, nx
	local sn = scale_along_normal or 1
	local st = scale_along_tangent or 1
	if math.abs(sn - 1) < 1e-4 and math.abs(st - 1) < 1e-4 then
		return
	end
	local jx, jy = joint_screen.X, joint_screen.Y
	local function map_corner(p)
		local rx = p.X - jx
		local ry = p.Y - jy
		local along_n = rx * nx + ry * ny
		local along_t = rx * tx + ry * ty
		return Vector(
			jx + nx * (along_n * sn) + tx * (along_t * st),
			jy + ny * (along_n * sn) + ty * (along_t * st)
		)
	end
	dst:SetTopLeft(map_corner(dst:GetTopLeft()))
	dst:SetTopRight(map_corner(dst:GetTopRight()))
	dst:SetBottomLeft(map_corner(dst:GetBottomLeft()))
	dst:SetBottomRight(map_corner(dst:GetBottomRight()))
end

--- Render-time seam delta from RT-local geometry (never cache screen space).
-- Order: scale (pose) → lock cut origins → tangent-only interface slide.
-- Do NOT 2D-match band centroids: they sit on opposite keep sides and yank the cut.
compute_seam_delta_at_render = function(to, graft, pose, joint_screen, render_offset, formula)
	if not graft then
		return nil
	end
	local hc = (to and to.cut_local) or graft.host_cut_local
	local dc = graft.cut_local
	local hi = (to and to.interface_local) or graft.host_interface_local
	local di = graft.interface_local
	if not hc or not dc or not hi or not di then
		return nil
	end
	local S = (pose and pose.scale) or (graft.scale or 1)
	local cn = (to and to.cut_normal) or graft.cut_normal or { 1, 0 }
	local nx, ny = cn[1] or 1, cn[2] or 0
	local nlen = math.sqrt(nx * nx + ny * ny)
	if nlen < 1e-6 then nx, ny = 1, 0 else nx, ny = nx / nlen, ny / nlen end
	local tx, ty = -ny, nx
	local hcx, hcy = hc[1] or 0, hc[2] or 0
	local dcx, dcy = dc[1] or 0, dc[2] or 0
	local hx, hy = hi[1] or 0, hi[2] or 0
	local dx, dy = di[1] or 0, di[2] or 0
	local ox = hcx - dcx * S
	local oy = hcy - dcy * S
	local host_t = (hx - hcx) * tx + (hy - hcy) * ty
	local donor_t = (dx * S + ox - hcx) * tx + (dy * S + oy - hcy) * ty
	local dt = host_t - donor_t
	ox = ox + tx * dt
	oy = oy + ty * dt
	local cut_dx = hcx - (dcx * S + ox)
	local cut_dy = hcy - (dcy * S + oy)
	local residual = math.abs(cut_dx * nx + cut_dy * ny)
	local host_mode = (to and to.interface_mode) or graft.host_interface_mode or "unknown"
	local donor_mode = graft.interface_mode or "unknown"
	local degraded = host_mode ~= "band" or donor_mode ~= "band"
	local paused = false
	pcall(function()
		paused = Game():IsPaused() == true
	end)
	_status.last_render_align = {
		formula = formula or resolve_screen_formula(to),
		frame = Game():GetFrameCount(),
		paused = paused,
		host_cut_local = { hcx, hcy },
		donor_cut_local = { dcx, dcy },
		host_interface_local = { hx, hy },
		donor_interface_local = { dx, dy },
		scale_S = S,
		delta = { ox, oy },
		tangent_slide = dt,
		residual = residual,
		degraded = degraded,
		host_mode = host_mode,
		donor_mode = donor_mode,
	}
	_status.last_residual_error_px = residual
	_status.last_math_ok = (not degraded) and residual <= 0.5
	return Vector(ox, oy)
end

--- One GetTexelRegion → analysis via sprite_splice_geometry (Gate3D compat wrapper).
sample_side_geometry = function(image, size, cut_origin, cut_normal, keep_sign)
	local analysis, err = splice_geometry.analyze_source(image, size, {
		cut_normal = cut_normal,
		keep_sign = keep_sign,
		cut_origin = cut_origin,
		-- When a seed origin is provided and already locked by caller, skip re-center.
		lock_content_center = cut_origin == nil,
	})
	_perf.geometry_analyzes = (_perf.geometry_analyzes or 0) + 1
	if not analysis then return nil, err end
	return {
		alpha = analysis.alpha,
		iface = analysis._iface or analysis.interface,
		bbox = analysis.bbox,
		analysis = analysis,
	}, nil
end

--- Gate3D DIAGNOSTIC alignment (IN PROGRESS — do not mark PASS).
-- 1) Host/Donor each get their OWN content-center cut_origin (never share UV).
-- 2) Bake stores RT-local interface points + scale only (no seam_align_screen).
-- 3) PRE_NPC_RENDER computes screen delta each frame from destination transforms.
-- 4) Residual after translate recorded for probe (target <= 0.5px; band mode required).
refresh_seam_align = function(to, graft)
	if not to or not graft or not graft.complementary then
		return false
	end
	if not (graft.seam_align or to.seam_align) then
		return false
	end
	local host_slot = to.target
	local donor_slot = graft.target
	if not host_slot or not host_slot.image or not to.baked then
		_status.last_seam_align = "fail:host_unbaked"
		return false
	end
	if not donor_slot or not donor_slot.image or not graft.baked then
		_status.last_seam_align = "fail:donor_unbaked"
		return false
	end
	local host_size = to.size or host_slot.size
	local donor_size = graft.size or donor_slot.size

	-- Cache host/donor interface geometry; donor metrics shared across grafts.
	local function ensure_host_geom()
		if to.geom_cache and to.geom_cache.iface and not to.geometry_dirty and not to.seam_align_dirty then
			return to.geom_cache.alpha, to.geom_cache.iface
		end
		if not to.cut_origin_locked then
			local pre, perr = sample_side_geometry(
				host_slot.image, host_size, to.cut_origin, to.cut_normal, to.keep_sign or -1
			)
			if not pre then return nil, nil, perr end
			if pre.alpha and pre.alpha.bbox then
				to.cut_origin = content_center_uv(pre.alpha.bbox, host_size)
				to.cut_origin_locked = true
			end
		end
		local sample, serr = sample_side_geometry(
			host_slot.image, host_size, to.cut_origin, to.cut_normal, to.keep_sign or -1
		)
		if not sample then return nil, nil, serr end
		to.geom_cache = { alpha = sample.alpha, iface = sample.iface }
		to.geometry_dirty = false
		return sample.alpha, sample.iface
	end

	local function ensure_donor_geom()
		if graft.geom_cache and graft.geom_cache.iface and not graft.geometry_dirty and not graft.seam_align_dirty then
			return graft.geom_cache.alpha, graft.geom_cache.iface
		end
		local vkey = graft.last_visual_key or sprite_frame_key(graft.sprite)
		if not graft.cut_origin_locked then
			local pre, perr = sample_side_geometry(
				donor_slot.image, donor_size, graft.cut_origin, graft.cut_normal, graft.keep_sign or 1
			)
			if not pre then return nil, nil, perr end
			if pre.alpha and pre.alpha.bbox then
				graft.cut_origin = content_center_uv(pre.alpha.bbox, donor_size)
				graft.cut_origin_locked = true
			else
				graft.cut_origin = graft.cut_origin or { 0.5, 0.5 }
			end
		end
		local dkey = donor_geom_cache_key(graft, vkey)
		local shared = _donor_geom_cache[dkey]
		local alpha, iface
		if shared then
			_perf.donor_geom_hits = (_perf.donor_geom_hits or 0) + 1
			alpha, iface = shared.alpha, shared.iface
			if shared.cut_origin then
				graft.cut_origin = { shared.cut_origin[1], shared.cut_origin[2] }
			end
		else
			_perf.donor_geom_misses = (_perf.donor_geom_misses or 0) + 1
			local sample, serr = sample_side_geometry(
				donor_slot.image, donor_size, graft.cut_origin, graft.cut_normal, graft.keep_sign or 1
			)
			if not sample then
				return nil, nil, serr
			end
			alpha, iface = sample.alpha, sample.iface
			_donor_geom_cache[dkey] = {
				cut_origin = { graft.cut_origin[1], graft.cut_origin[2] },
				alpha = alpha,
				iface = iface,
			}
		end
		graft.geom_cache = { alpha = alpha, iface = iface }
		graft.geometry_dirty = false
		return alpha, iface
	end

	local host_alpha, host_if, herr = ensure_host_geom()
	local donor_alpha, donor_if, derr = ensure_donor_geom()
	if not host_if or not donor_if then
		_status.last_seam_align = "fail:" .. tostring(herr or derr)
		_status.gate3d_ok = false
		return false
	end
	local hn = math.max(host_if.count or 0, host_if.keep_count or 0, host_if.nonzero_samples or 0)
	local dn = math.max(donor_if.count or 0, donor_if.keep_count or 0, donor_if.nonzero_samples or 0)
	if hn < 1 or dn < 1 then
		_status.last_seam_align = string.format(
			"fail:empty_iface host_n=%d donor_n=%d host_fmt=%s/%s donor_fmt=%s/%s",
			hn, dn,
			tostring(host_if.fmt), tostring(host_if.bytes),
			tostring(donor_if.fmt), tostring(donor_if.bytes)
		)
		_status.gate3d_ok = false
		graft.seam_align_screen = nil -- deprecated; never cache screen delta
		graft.interface_local = nil
		graft.seam_tangent_scale = 1
		graft.seam_normal_scale = 1
		return false
	end

	-- Canonical solve via sprite_splice_geometry (same math as UI / standalone).
	local host_analysis = {
		size = host_size,
		bbox = host_alpha and host_alpha.bbox,
		alpha = host_alpha,
		cut_origin = to.cut_origin or { 0.5, 0.5 },
		cut_local = nil,
		keep_sign = to.keep_sign or -1,
		interface = {
			mode = host_if.mode,
			span_px = host_if.keep_span_px or host_if.interface_span_px or 0,
			interface_span_px = host_if.interface_span_px or 0,
			keep_span_px = host_if.keep_span_px or 0,
			centroid_local = host_if.edge_centroid_from_center or host_if.keep_centroid_from_center or { 0, 0 },
			edge_centroid_from_center = host_if.edge_centroid_from_center,
			keep_centroid_from_center = host_if.keep_centroid_from_center,
			count = host_if.count,
			keep_count = host_if.keep_count,
			nonzero_samples = host_if.nonzero_samples,
			fmt = host_if.fmt,
			bytes = host_if.bytes,
		},
		_iface = host_if,
	}
	do
		local o = host_analysis.cut_origin
		host_analysis.cut_local = {
			((o[1] or 0.5) - 0.5) * host_size,
			((o[2] or 0.5) - 0.5) * host_size,
		}
	end
	local donor_analysis = {
		size = donor_size,
		bbox = donor_alpha and donor_alpha.bbox,
		alpha = donor_alpha,
		cut_origin = graft.cut_origin or { 0.5, 0.5 },
		cut_local = nil,
		keep_sign = graft.keep_sign or 1,
		interface = {
			mode = donor_if.mode,
			span_px = donor_if.keep_span_px or donor_if.interface_span_px or 0,
			interface_span_px = donor_if.interface_span_px or 0,
			keep_span_px = donor_if.keep_span_px or 0,
			centroid_local = donor_if.edge_centroid_from_center or donor_if.keep_centroid_from_center or { 0, 0 },
			edge_centroid_from_center = donor_if.edge_centroid_from_center,
			keep_centroid_from_center = donor_if.keep_centroid_from_center,
			count = donor_if.count,
			keep_count = donor_if.keep_count,
			nonzero_samples = donor_if.nonzero_samples,
			fmt = donor_if.fmt,
			bytes = donor_if.bytes,
		},
		_iface = donor_if,
	}
	do
		local o = donor_analysis.cut_origin
		donor_analysis.cut_local = {
			((o[1] or 0.5) - 0.5) * donor_size,
			((o[2] or 0.5) - 0.5) * donor_size,
		}
	end

	local move_p = to.movement_profile or graft.movement_profile
	local atk_p = graft.attack_profile or to.attack_profile
	local solution, serr = splice_geometry.solve_pair(host_analysis, donor_analysis, {
		cut_normal = to.cut_normal or graft.cut_normal or { 1, 0 },
		host_reference_span = stitch_geometry.reference_span(move_p),
		donor_reference_span = stitch_geometry.reference_span(atk_p),
		base_scale = tonumber(graft.base_scale) or 1,
	})
	if not solution then
		_status.last_seam_align = "fail:solve:" .. tostring(serr)
		_status.gate3d_ok = false
		return false
	end

	local diag = solution.diagnostics or {}
	local frame_ratio_out = tonumber(diag.frame_ratio) or 1
	local reference_ratio = tonumber(diag.reference_ratio) or 1
	local ratio = tonumber(diag.final_ratio) or 1
	local clamped = diag.clamped == true
	local base = tonumber(diag.base_scale) or 1
	local donor_scale = solution.donor.scale or (base * ratio)
	graft.scale = donor_scale
	graft.seam_tangent_scale = 1
	graft.seam_normal_scale = 1
	graft.seam_scale_ratio = ratio
	graft.geom_diag = {
		host_ref_span = diag.host_ref_span,
		donor_ref_span = diag.donor_ref_span,
		frame_ratio = frame_ratio_out,
		reference_ratio = reference_ratio,
		final_scale = ratio,
		clamped = clamped,
		base_scale = base,
		host_scale_factor = nil,
		S = nil,
		seam_residual = nil,
	}

	local hsf = host_scale_factor(to.host)
	-- Entity screen adapter: pose scale may include host Sprite.Scale factor.
	local S = donor_scale * hsf
	if graft.geom_diag then
		graft.geom_diag.host_scale_factor = hsf
		graft.geom_diag.S = S
	end
	local nx = solution.cut_normal[1] or 1
	local ny = solution.cut_normal[2] or 0
	local tx = solution.tangent[1] or -ny
	local ty = solution.tangent[2] or nx
	local cut_angle_deg = math.deg(math.atan(ny, nx))

	local h_origin = solution.host.cut_origin
	local d_origin = solution.donor.cut_origin
	to.cut_origin = { h_origin[1], h_origin[2] }
	graft.cut_origin = { d_origin[1], d_origin[2] }
	to.cut_origin_locked = true
	graft.cut_origin_locked = true

	local host_seam_x = solution.host.cut_local[1] or 0
	local host_seam_y = solution.host.cut_local[2] or 0
	local donor_seam_x = solution.donor.cut_local[1] or 0
	local donor_seam_y = solution.donor.cut_local[2] or 0
	local hx = solution.host.interface_local[1] or 0
	local hy = solution.host.interface_local[2] or 0
	local dx = solution.donor.interface_local[1] or 0
	local dy = solution.donor.interface_local[2] or 0
	local hs = tonumber(diag.host_span) or 0
	local ds = tonumber(diag.donor_span) or 0

	to.cut_local = { host_seam_x, host_seam_y }
	graft.cut_local = { donor_seam_x, donor_seam_y }
	graft.host_cut_local = { host_seam_x, host_seam_y }
	to.cut_normal = { nx, ny }
	graft.cut_normal = { nx, ny }
	to.interface_local = { hx, hy }
	graft.interface_local = { dx, dy }
	graft.host_interface_local = { hx, hy }
	to.interface_mode = host_if.mode
	graft.interface_mode = donor_if.mode
	graft.host_interface_mode = host_if.mode
	to.interface_span_px = host_if.interface_span_px or hs
	graft.interface_span_px = donor_if.interface_span_px or ds
	local degraded = (host_if.mode ~= "band") or (donor_if.mode ~= "band")
	graft.degraded = degraded
	graft.seam_align_screen = nil

	-- Diagnostic residual with entity S (includes host_scale_factor).
	local ox = host_seam_x - donor_seam_x * S
	local oy = host_seam_y - donor_seam_y * S
	local host_t = (hx - host_seam_x) * tx + (hy - host_seam_y) * ty
	local donor_t = (dx * S + ox - host_seam_x) * tx + (dy * S + oy - host_seam_y) * ty
	local dt = host_t - donor_t
	ox = ox + tx * dt
	oy = oy + ty * dt
	local donor_iface_ax = dx * S + ox
	local donor_iface_ay = dy * S + oy
	local iface_dx = hx - donor_iface_ax
	local iface_dy = hy - donor_iface_ay
	local iface_sep = math.sqrt(iface_dx * iface_dx + iface_dy * iface_dy)
	local iface_sep_n = iface_dx * nx + iface_dy * ny
	local iface_sep_t = iface_dx * tx + iface_dy * ty
	local cut_dx = host_seam_x - (donor_seam_x * S + ox)
	local cut_dy = host_seam_y - (donor_seam_y * S + oy)
	local cut_resid_n = cut_dx * nx + cut_dy * ny
	local cut_resid_t = cut_dx * tx + cut_dy * ty
	local cut_residual = math.sqrt(cut_dx * cut_dx + cut_dy * cut_dy)
	-- Math OK = band modes + cut-plane normal residual ~0.
	local math_ok = (not degraded) and math.abs(cut_resid_n) <= 0.5
	_status.last_residual_error_px = math.abs(cut_resid_n)
	_status.last_math_ok = math_ok
	_status.gate3d_phase = "diagnostic"
	_status.gate3d_ok = false
	if graft.geom_diag then
		graft.geom_diag.seam_residual = {
			cut_n = cut_resid_n,
			cut_t = cut_resid_t,
			iface_sep = iface_sep,
			iface_n = iface_sep_n,
			iface_t = iface_sep_t,
		}
	end

	local function bbox_tbl(b)
		if not b then return nil end
		return { minx = b.minx, miny = b.miny, maxx = b.maxx, maxy = b.maxy }
	end
	_diag.frame = Game():GetFrameCount()
	_diag.host = {
		rt_size = host_size,
		bbox = bbox_tbl(host_alpha and host_alpha.bbox) or bbox_tbl(host_if.bbox),
		content_center_uv = { h_origin[1], h_origin[2] },
		content_center_px = {
			(h_origin[1] or 0.5) * host_size,
			(h_origin[2] or 0.5) * host_size,
		},
		cut_origin_uv = { h_origin[1], h_origin[2] },
		cut_origin_px_from_center = { host_seam_x, host_seam_y },
		interface_centroid_from_center = { hx, hy },
		interface_span_px = host_if.interface_span_px or 0,
		keep_span_px = hs,
		keep_centroid_from_center = host_if.keep_centroid_from_center,
		mode = host_if.mode,
		nonzero = host_alpha and host_alpha.nonzero_samples or host_if.nonzero_samples,
	}
	_diag.donor = {
		rt_size = donor_size,
		bbox = bbox_tbl(donor_alpha and donor_alpha.bbox) or bbox_tbl(donor_if.bbox),
		content_center_uv = { d_origin[1], d_origin[2] },
		content_center_px = {
			(d_origin[1] or 0.5) * donor_size,
			(d_origin[2] or 0.5) * donor_size,
		},
		cut_origin_uv = { d_origin[1], d_origin[2] },
		cut_origin_px_from_center = { donor_seam_x, donor_seam_y },
		interface_centroid_from_center = { dx, dy },
		interface_span_px = donor_if.interface_span_px or 0,
		keep_span_px = ds,
		keep_centroid_from_center = donor_if.keep_centroid_from_center,
		mode = donor_if.mode,
		nonzero = donor_alpha and donor_alpha.nonzero_samples or donor_if.nonzero_samples,
		frame_ratio = frame_ratio_out,
		reference_ratio = reference_ratio,
		scale_ratio = ratio,
		scale_clamped = clamped,
		base_scale = base,
		host_scale_factor = hsf,
		screen_scale_S = S,
	}
	_diag.final = {
		align = "render_time_interface_point",
		degraded = degraded,
		host_interface_mode = host_if.mode,
		donor_interface_mode = donor_if.mode,
		cut_normal = { nx, ny },
		cut_angle_deg = cut_angle_deg,
		host_interface_rel = { hx, hy },
		donor_interface_before_rel = { dx * S, dy * S },
		computed_translation = { ox, oy },
		donor_interface_after_rel = { donor_iface_ax, donor_iface_ay },
		-- Primary math metric: cut-plane normal residual (must be ~0).
		cut_plane_normal_residual_px = cut_resid_n,
		cut_plane_tangent_residual_px = cut_resid_t,
		cut_residual_error_px = cut_residual,
		-- Informative only: opposite-side band centroids (grows with S).
		iface_normal_separation_px = iface_sep_n,
		iface_tangent_separation_px = iface_sep_t,
		iface_separation_px = iface_sep,
		residual_error_px = math.abs(cut_resid_n),
		scale_clamped = clamped,
		frame_ratio = frame_ratio_out,
		reference_ratio = reference_ratio,
		scale_ratio = ratio,
		base_scale = base,
		host_scale_factor = hsf,
		screen_scale_S = S,
		math_ok = math_ok,
	}

	_status.last_seam_align = string.format(
		"DIAG ang=%.0f frameS=%.2f refS=%.2f finalS=%.2f%s hostSpan=%.1f donorSpan=%.1f off=(%.1f,%.1f) cutN=%.2f ifaceN=%.1f hUV=(%.3f,%.3f) dUV=(%.3f,%.3f)",
		tonumber(cut_angle_deg) or 0,
		tonumber(frame_ratio_out) or 1,
		tonumber(reference_ratio) or 1,
		tonumber(ratio) or 1,
		clamped and "(CLAMP)" or "",
		tonumber(hs) or 0,
		tonumber(ds) or 0,
		tonumber(ox) or 0,
		tonumber(oy) or 0,
		tonumber(cut_resid_n) or 0,
		tonumber(iface_sep_n) or 0,
		tonumber(h_origin[1]) or 0.5,
		tonumber(h_origin[2]) or 0.5,
		tonumber(d_origin[1]) or 0.5,
		tonumber(d_origin[2]) or 0.5
	)
	return true
end


refresh_all_seam_aligns = function()
	for key, to in pairs(_takeovers) do
		if to.seam_align then
			local list = _grafts[key]
			if list then
				for i = 1, #list do
					local graft = list[i]
					if graft.complementary and graft.seam_align then
						refresh_seam_align(to, graft)
					end
				end
			end
		end
	end
end



local function write_bytes(path, bytes)
	local f = assert(io.open(path, "wb"))
	f:write(bytes)
	f:close()
end

local function try_write(paths, bytes)
	local last_err
	for i = 1, #paths do
		local ok, err = pcall(function()
			write_bytes(paths[i], bytes)
		end)
		if ok then
			return true, paths[i]
		end
		last_err = err
	end
	return false, tostring(last_err)
end

local function texel_rgb_u8(blob, x, y)
	local row = blob.row or blob.size
	local idx = y * row + x
	local r, g, b, a = 0, 0, 0, 0
	if blob.fmt == "f32" then
		local off = idx * 16 + 1
		if off + 15 > #blob.data then return 0, 0, 0, 0 end
		r = math.floor(math.max(0, math.min(1, string.unpack("<f", blob.data, off) or 0)) * 255 + 0.5)
		g = math.floor(math.max(0, math.min(1, string.unpack("<f", blob.data, off + 4) or 0)) * 255 + 0.5)
		b = math.floor(math.max(0, math.min(1, string.unpack("<f", blob.data, off + 8) or 0)) * 255 + 0.5)
		a = math.floor(math.max(0, math.min(1, string.unpack("<f", blob.data, off + 12) or 0)) * 255 + 0.5)
	else
		local off = idx * 4 + 1
		r = string.byte(blob.data, off) or 0
		g = string.byte(blob.data, off + 1) or 0
		b = string.byte(blob.data, off + 2) or 0
		a = string.byte(blob.data, off + 3) or 0
	end
	return r, g, b, a
end

--- Write binary PPM (RGB) + PGM (alpha) so RT contents are visually inspectable.
local function encode_rt_ppm_pgm(image, size, mark)
	local blob, err = read_texel_blob(image, size)
	if not blob then return nil, nil, err end
	local rgb = { string.format("P6\n%d %d\n255\n", size, size) }
	local a8 = { string.format("P5\n%d %d\n255\n", size, size) }
	local rgb_parts = {}
	local a_parts = {}
	-- Lua string concat in loop is slow; build via table of chars in chunks.
	local function flush_chunk(parts, buf)
		parts[#parts + 1] = table.concat(buf)
		for i = 1, #buf do buf[i] = nil end
	end
	local rbuf, abuf = {}, {}
	local n = 0
	for y = 0, size - 1 do
		for x = 0, size - 1 do
			local r, g, b, a = texel_rgb_u8(blob, x, y)
			-- Optional debug marks: content bbox / centers drawn by caller via mark table.
			if mark then
				if mark.bbox and x >= mark.bbox.minx and x <= mark.bbox.maxx and y >= mark.bbox.miny and y <= mark.bbox.maxy then
					if x == mark.bbox.minx or x == mark.bbox.maxx or y == mark.bbox.miny or y == mark.bbox.maxy then
						r, g, b = 255, 40, 40
					end
				end
				if mark.center and math.abs(x - mark.center[1]) <= 1 and math.abs(y - mark.center[2]) <= 1 then
					r, g, b = 255, 220, 0
				end
				if mark.seam and math.abs(x - mark.seam[1]) <= 1 and math.abs(y - mark.seam[2]) <= 1 then
					r, g, b = 40, 220, 255
				end
			end
			rbuf[#rbuf + 1] = string.char(r, g, b)
			abuf[#abuf + 1] = string.char(a)
			n = n + 1
			if n >= 512 then
				flush_chunk(rgb_parts, rbuf)
				flush_chunk(a_parts, abuf)
				n = 0
			end
		end
	end
	if n > 0 then
		flush_chunk(rgb_parts, rbuf)
		flush_chunk(a_parts, abuf)
	end
	local ppm = rgb[1] .. table.concat(rgb_parts)
	local pgm = a8[1] .. table.concat(a_parts)
	return ppm, pgm, nil, blob
end

local function dump_sprite_layers(sprite, role)
	local out = {}
	if not sprite then
		return out
	end
	for_each_sprite_layer(sprite, function(layer)
		local id = #out
		if layer.GetLayerID then
			local ok, v = pcall(function() return layer:GetLayerID() end)
			if ok and v ~= nil then id = v end
		end
		local name = ""
		if layer.GetName then
			local ok, v = pcall(function() return layer:GetName() end)
			if ok and type(v) == "string" then name = v end
		end
		local sheet = ""
		if layer.GetSpritesheetPath then
			local ok, v = pcall(function() return layer:GetSpritesheetPath() end)
			if ok and type(v) == "string" then sheet = v end
		end
		local visible = true
		if layer.IsVisible then
			local ok, v = pcall(function() return layer:IsVisible() end)
			if ok then visible = v ~= false end
		end
		local skip = layer_looks_like_shadow(layer)
		out[#out + 1] = {
			role = role,
			layer_id = id,
			name = name,
			spritesheet_path = sheet,
			visible = visible,
			skipped_as_shadow = skip,
		}
	end)
	return out
end

local function json_escape(s)
	s = tostring(s or "")
	s = s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r")
	return s
end

local function json_num(n)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return "null"
	end
	return string.format("%.6g", n)
end

local function json_vec2(v)
	if not v then return "null" end
	local x = type(v) == "table" and (v[1] or v.x) or nil
	local y = type(v) == "table" and (v[2] or v.y) or nil
	return string.format('{"x":%s,"y":%s}', json_num(x), json_num(y))
end

local function json_bbox(b)
	if not b then return "null" end
	return string.format(
		'{"minx":%s,"miny":%s,"maxx":%s,"maxy":%s}',
		json_num(b.minx), json_num(b.miny), json_num(b.maxx), json_num(b.maxy)
	)
end

local function encode_diag_json(payload)
	-- Hand-rolled compact JSON (avoid depending on json module).
	local L = {}
	local function add(s) L[#L + 1] = s end
	add("{")
	add('"schema":"runtime_stitch_gate3d_diagnostic",')
	add('"schema_version":1,')
	add(string.format('"frame":%d,', payload.frame or 0))
	add(string.format('"residual_error_px":%s,', json_num(payload.residual_error_px)))
	add(string.format('"cut_residual_error_px":%s,', json_num(payload.cut_residual_error_px)))
	add(string.format('"math_ok":%s,', payload.math_ok and "true" or "false"))
	add(string.format('"gate3d_phase":"%s",', json_escape(payload.gate3d_phase or "diagnostic")))
	add('"host":{')
	local h = payload.host or {}
	add(string.format('"rt_size":%s,', json_num(h.rt_size)))
	add('"bbox":' .. json_bbox(h.bbox) .. ",")
	add('"content_center_uv":' .. json_vec2(h.content_center_uv) .. ",")
	add('"content_center_px":' .. json_vec2(h.content_center_px) .. ",")
	add('"cut_origin_uv":' .. json_vec2(h.cut_origin_uv) .. ",")
	add('"cut_origin_px_from_center":' .. json_vec2(h.cut_origin_px_from_center) .. ",")
	add('"interface_centroid_from_center":' .. json_vec2(h.interface_centroid_from_center) .. ",")
	add(string.format('"interface_span_px":%s,', json_num(h.interface_span_px)))
	add(string.format('"keep_span_px":%s,', json_num(h.keep_span_px)))
	add(string.format('"mode":"%s",', json_escape(h.mode)))
	add(string.format('"nonzero":%s', json_num(h.nonzero)))
	add("},")
	add('"donor":{')
	local d = payload.donor or {}
	add(string.format('"rt_size":%s,', json_num(d.rt_size)))
	add('"bbox":' .. json_bbox(d.bbox) .. ",")
	add('"content_center_uv":' .. json_vec2(d.content_center_uv) .. ",")
	add('"content_center_px":' .. json_vec2(d.content_center_px) .. ",")
	add('"cut_origin_uv":' .. json_vec2(d.cut_origin_uv) .. ",")
	add('"cut_origin_px_from_center":' .. json_vec2(d.cut_origin_px_from_center) .. ",")
	add('"interface_centroid_from_center":' .. json_vec2(d.interface_centroid_from_center) .. ",")
	add(string.format('"interface_span_px":%s,', json_num(d.interface_span_px)))
	add(string.format('"keep_span_px":%s,', json_num(d.keep_span_px)))
	add(string.format('"mode":"%s",', json_escape(d.mode)))
	add(string.format('"nonzero":%s,', json_num(d.nonzero)))
	add(string.format('"frame_ratio":%s,', json_num(d.frame_ratio)))
	add(string.format('"reference_ratio":%s,', json_num(d.reference_ratio)))
	add(string.format('"scale_ratio":%s,', json_num(d.scale_ratio)))
	add(string.format('"base_scale":%s,', json_num(d.base_scale)))
	add(string.format('"host_scale_factor":%s,', json_num(d.host_scale_factor)))
	add(string.format('"scale_clamped":%s,', d.scale_clamped and "true" or "false"))
	add(string.format('"screen_scale_S":%s', json_num(d.screen_scale_S)))
	add("},")
	add('"final":{')
	local f = payload.final or {}
	add(string.format('"align":"%s",', json_escape(f.align)))
	add('"cut_normal":' .. json_vec2(f.cut_normal) .. ",")
	add(string.format('"cut_angle_deg":%s,', json_num(f.cut_angle_deg)))
	add('"host_interface_rel":' .. json_vec2(f.host_interface_rel) .. ",")
	add('"donor_interface_before_rel":' .. json_vec2(f.donor_interface_before_rel) .. ",")
	add('"computed_translation":' .. json_vec2(f.computed_translation) .. ",")
	add('"donor_interface_after_rel":' .. json_vec2(f.donor_interface_after_rel) .. ",")
	add(string.format('"cut_plane_normal_residual_px":%s,', json_num(f.cut_plane_normal_residual_px)))
	add(string.format('"cut_plane_tangent_residual_px":%s,', json_num(f.cut_plane_tangent_residual_px)))
	add(string.format('"cut_residual_error_px":%s,', json_num(f.cut_residual_error_px)))
	add(string.format('"iface_normal_separation_px":%s,', json_num(f.iface_normal_separation_px)))
	add(string.format('"iface_tangent_separation_px":%s,', json_num(f.iface_tangent_separation_px)))
	add(string.format('"iface_separation_px":%s,', json_num(f.iface_separation_px)))
	add(string.format('"residual_error_px":%s,', json_num(f.residual_error_px)))
	add(string.format('"frame_ratio":%s,', json_num(f.frame_ratio)))
	add(string.format('"reference_ratio":%s,', json_num(f.reference_ratio)))
	add(string.format('"scale_ratio":%s,', json_num(f.scale_ratio)))
	add(string.format('"base_scale":%s,', json_num(f.base_scale)))
	add(string.format('"host_scale_factor":%s,', json_num(f.host_scale_factor)))
	add(string.format('"screen_scale_S":%s,', json_num(f.screen_scale_S)))
	add(string.format('"scale_clamped":%s,', f.scale_clamped and "true" or "false"))
	add(string.format('"math_ok":%s', f.math_ok and "true" or "false"))
	add("},")
	add('"layers":[')
	local layers = payload.layers or {}
	for i = 1, #layers do
		local Lr = layers[i]
		if i > 1 then add(",") end
		add(string.format(
			'{"role":"%s","layer_id":%s,"name":"%s","spritesheet_path":"%s","visible":%s,"skipped_as_shadow":%s}',
			json_escape(Lr.role),
			json_num(Lr.layer_id),
			json_escape(Lr.name),
			json_escape(Lr.spritesheet_path),
			Lr.visible and "true" or "false",
			Lr.skipped_as_shadow and "true" or "false"
		))
	end
	add("],")
	add('"files":{')
	local files = payload.files or {}
	add(string.format('"host_rgb":"%s",', json_escape(files.host_rgb)))
	add(string.format('"host_alpha":"%s",', json_escape(files.host_alpha)))
	add(string.format('"donor_rgb":"%s",', json_escape(files.donor_rgb)))
	add(string.format('"donor_alpha":"%s"', json_escape(files.donor_alpha)))
	add("}")
	add("}")
	return table.concat(L)
end

function M.set_diag_overlay(on)
	_diag.overlay = on == true
end

function M.get_diag_snapshot()
	return {
		overlay = _diag.overlay == true,
		frame = _diag.frame,
		host = _diag.host,
		donor = _diag.donor,
		final = _diag.final,
		layers = _diag.layers,
		residual_error_px = _status.last_residual_error_px,
		gate3d_phase = _status.gate3d_phase,
		last_seam_align = _status.last_seam_align,
	}
end

--- Gate3D diagnostic export: Host/Donor RT (PPM+PGM), layer dump, geometry JSON.
-- Truth = files on disk. Code claims about shadow skip are not evidence.
function M.export_gate3d_diagnostics()
	_status.last_diag_path = nil
	_status.last_diag_error = nil
	local host, to, graft
	for key, v in pairs(_takeovers) do
		to = v
		host = v.host
		local list = _grafts[key]
		if list then
			for i = 1, #list do
				if list[i].complementary then
					graft = list[i]
					break
				end
			end
		end
		break
	end
	if not to or not host then
		_status.last_diag_error = "no active takeover"
		return false, _status.last_diag_error
	end
	if not graft then
		_status.last_diag_error = "no complementary graft"
		return false, _status.last_diag_error
	end
	-- Refresh align so _diag geometry matches current RTs.
	refresh_seam_align(to, graft)

	local host_slot = to.target
	local donor_slot = graft.target
	local host_size = to.size or (host_slot and host_slot.size) or M.TARGET_SIZE
	local donor_size = graft.size or (donor_slot and donor_slot.size) or M.TARGET_SIZE

	local host_mark = nil
	if _diag.host then
		host_mark = {
			bbox = _diag.host.bbox,
			center = _diag.host.content_center_px,
			seam = {
				((_diag.host.cut_origin_uv and _diag.host.cut_origin_uv[1]) or 0.5) * host_size,
				((_diag.host.cut_origin_uv and _diag.host.cut_origin_uv[2]) or 0.5) * host_size,
			},
		}
	end
	local donor_mark = nil
	if _diag.donor then
		donor_mark = {
			bbox = _diag.donor.bbox,
			center = _diag.donor.content_center_px,
			seam = {
				((_diag.donor.cut_origin_uv and _diag.donor.cut_origin_uv[1]) or 0.5) * donor_size,
				((_diag.donor.cut_origin_uv and _diag.donor.cut_origin_uv[2]) or 0.5) * donor_size,
			},
		}
	end

	local host_ppm, host_pgm, herr = encode_rt_ppm_pgm(host_slot and host_slot.image, host_size, host_mark)
	if not host_ppm then
		_status.last_diag_error = "host RT encode: " .. tostring(herr)
		return false, _status.last_diag_error
	end
	local donor_ppm, donor_pgm, derr = encode_rt_ppm_pgm(donor_slot and donor_slot.image, donor_size, donor_mark)
	if not donor_ppm then
		_status.last_diag_error = "donor RT encode: " .. tostring(derr)
		return false, _status.last_diag_error
	end

	local host_spr = host.GetSprite and host:GetSprite() or nil
	local donor_spr = graft.sprite
	local layers = {}
	local hl = dump_sprite_layers(host_spr, "host")
	local dl = dump_sprite_layers(donor_spr, "donor")
	for i = 1, #hl do layers[#layers + 1] = hl[i] end
	for i = 1, #dl do layers[#layers + 1] = dl[i] end
	_diag.layers = layers

	local files = {}
	local ok1, p1 = try_write(export_paths("runtime_stitch_gate3d_host.ppm"), host_ppm)
	local ok2, p2 = try_write(export_paths("runtime_stitch_gate3d_host_alpha.pgm"), host_pgm)
	local ok3, p3 = try_write(export_paths("runtime_stitch_gate3d_donor.ppm"), donor_ppm)
	local ok4, p4 = try_write(export_paths("runtime_stitch_gate3d_donor_alpha.pgm"), donor_pgm)
	if not (ok1 and ok2 and ok3 and ok4) then
		_status.last_diag_error = "image write failed: " .. tostring(p1 or p2 or p3 or p4)
		return false, _status.last_diag_error
	end
	files.host_rgb = p1
	files.host_alpha = p2
	files.donor_rgb = p3
	files.donor_alpha = p4

	local payload = {
		frame = Game():GetFrameCount(),
		gate3d_phase = "diagnostic",
		residual_error_px = _diag.final and _diag.final.residual_error_px,
		cut_residual_error_px = _diag.final and _diag.final.cut_residual_error_px,
		math_ok = _diag.final and _diag.final.math_ok,
		host = _diag.host,
		donor = _diag.donor,
		final = _diag.final,
		layers = layers,
		files = files,
	}
	local body = encode_diag_json(payload)
	local okj, pj = try_write(export_paths("runtime_stitch_gate3d_diagnostic.json"), body)
	local okl, pl = try_write(export_paths("runtime_stitch_layers.json"), encode_diag_json({
		frame = payload.frame,
		gate3d_phase = "diagnostic",
		layers = layers,
		host = {},
		donor = {},
		final = {},
		files = {},
	}))
	if not okj then
		_status.last_diag_error = "json write failed: " .. tostring(pj)
		return false, _status.last_diag_error
	end
	_status.last_diag_path = pj
	_status.last_diag_error = nil
	return true, pj, payload
end

local function draw_diag_cross(screen, r, g, b)
	-- Tiny cross only — letters like "J" sit on the seam and hide the endpoint.
	if not screen then return end
	pcall(function()
		Isaac.RenderText("+", screen.X - 2, screen.Y - 5, r or 1, g or 1, b or 0, 1)
	end)
end

function M.render_diag_overlay(host, render_offset)
	if not _diag.overlay or not host or not _diag.final then
		return
	end
	render_offset = render_offset or Vector(0, 0)
	local po = host.PositionOffset or Vector(0, 0)
	local joint = entity_callback_screen_pos(host.Position + po, render_offset)
	local f = _diag.final
	local hi = f.host_interface_rel or { 0, 0 }
	local di = f.donor_interface_after_rel or { 0, 0 }
	local tr = f.computed_translation or { 0, 0 }
	local host_pt = Vector(joint.X + (hi[1] or 0), joint.Y + (hi[2] or 0))
	local donor_pt = Vector(joint.X + (di[1] or 0), joint.Y + (di[2] or 0))
	-- Only host + aligned donor seam points. No joint "J", no pre-align "D0".
	draw_diag_cross(host_pt, 1, 0.25, 0.25)
	draw_diag_cross(donor_pt, 0.25, 1, 0.25)
	-- Status above body: bake preview + live render-time align (pause vs run).
	local live = _status.last_render_align
	local live_delta = live and live.delta or tr
	local live_resid = live and live.residual
	if live_resid == nil then
		live_resid = tonumber(f.residual_error_px) or -1
	end
	local mode_h = (live and live.host_mode) or (f.host_interface_mode or "?")
	local mode_d = (live and live.donor_mode) or (f.donor_interface_mode or "?")
	local paused = live and live.paused
	pcall(function()
		Isaac.RenderText(
			string.format(
				"3D %s resid=%.2f d=(%.1f,%.1f) %s/%s%s",
				paused and "PAUSE" or "RUN",
				tonumber(live_resid) or -1,
				(live_delta and live_delta[1]) or (tr[1] or 0),
				(live_delta and live_delta[2]) or (tr[2] or 0),
				tostring(mode_h),
				tostring(mode_d),
				(live and live.degraded) and " DEG" or ""
			),
			joint.X - 70, joint.Y - 70, 1, 1, 0.25, 1
		)
	end)
end


--- Dump current Gate3A takeover bake + host meta into codex_work/logs.
function M.export_takeover_snapshot()
	_status.last_export_path = nil
	_status.last_export_error = nil
	_status.last_export_nonzero = 0
	local host, to
	for _, v in pairs(_takeovers) do
		to = v
		host = v.host
		break
	end
	if not to or not host then
		_status.last_export_error = "no active takeover"
		return false, _status.last_export_error
	end
	local slot = to.target
	local alpha, aerr = analyze_image_alpha(slot and slot.image, to.size or M.TARGET_SIZE, 2)
	if not alpha then
		_status.last_export_error = aerr or "alpha analyze failed"
		return false, _status.last_export_error
	end
	_status.last_export_nonzero = alpha.nonzero_samples or 0
	local spr = host.GetSprite and host:GetSprite() or nil
	local payload = {
		schema = "runtime_stitch_gate3a_snapshot",
		schema_version = 1,
		probe = "runtime_stitch",
		frame = Game():GetFrameCount(),
		host = {
			type = host.Type,
			variant = host.Variant,
			subtype = host.SubType,
			init_seed = host.InitSeed,
			visible = host.Visible ~= false,
			position = { x = host.Position.X, y = host.Position.Y },
			position_offset = {
				x = (host.PositionOffset and host.PositionOffset.X) or 0,
				y = (host.PositionOffset and host.PositionOffset.Y) or 0,
			},
		},
		sprite = spr and {
			animation = spr.GetAnimation and spr:GetAnimation() or nil,
			frame = spr.GetFrame and spr:GetFrame() or nil,
			flip_x = spr.FlipX == true,
			flip_y = spr.FlipY == true,
			scale = spr.Scale and { x = spr.Scale.X, y = spr.Scale.Y } or nil,
			color = spr.Color and { r = spr.Color.R, g = spr.Color.G, b = spr.Color.B, a = spr.Color.A } or nil,
		} or nil,
		takeover = {
			mode = to.mode,
			verify_mode = to.verify_mode,
			baked = to.baked == true,
			size = to.size,
		},
		alpha = alpha,
		status = M.get_status(),
	}
	local body = require("json").encode(payload)
	-- Prefer engine json if present; fallback to minimal hand JSON via Isaac.
	if type(body) ~= "string" then
		-- REPENTOGON / Isaac often expose JSON via Isaac or DKJSON-like; build a tiny encoder.
		body = string.format(
			'{"schema":"runtime_stitch_gate3a_snapshot","frame":%d,"host":"%d/%d/%d","verify":"%s","baked":%s,"nonzero":%d,"blit":"%s","err":%s}',
			payload.frame,
			payload.host.type, payload.host.variant, payload.host.subtype,
			tostring(to.verify_mode),
			tostring(to.baked == true),
			alpha.nonzero_samples or 0,
			tostring(_status.last_blit_mode),
			_status.last_error and string.format("%q", _status.last_error) or "null"
		)
	end
	local name = "runtime_stitch_gate3a.json"
	local last_err
	for _, path in ipairs(export_paths(name)) do
		local ok, err = pcall(function()
			local f = assert(io.open(path, "w"))
			f:write(body)
			f:close()
		end)
		if ok then
			_status.last_export_path = path
			return true, path, payload
		end
		last_err = err
	end
	_status.last_export_error = "write failed: " .. tostring(last_err)
	return false, _status.last_export_error
end

function M.debug_attach_nearest(donor_id, use_clip, overrides)
	local player = Isaac.GetPlayer(0)
	if not player then return false, "no player" end
	local best, best_d
	local ents = Isaac.GetRoomEntities()
	for i = 1, #ents do
		local e = ents[i]
		local npc = e and e:ToNPC()
		if npc and npc:Exists() and not npc:IsDead() and npc:IsVulnerableEnemy() and not npc:IsBoss() then
			local d = (npc.Position - player.Position):Length()
			if not best_d or d < best_d then
				best, best_d = npc, d
			end
		end
	end
	if not best then return false, "no host enemy" end
	-- Organ/graft tests must not leave a Host takeover canceling default draw.
	clear_takeovers()
	local opts = {}
	for k, v in pairs(overrides or {}) do
		opts[k] = v
	end
	if opts.use_clip == nil then
		opts.use_clip = use_clip ~= false
	end
	local graft = M.attach(best, donor_id or "fly_wing", opts)
	if not graft then return false, _status.last_error or "attach failed" end
	return true, best, graft
end

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		perf_roll_window()
		if next(_grafts) then
			bake_all_targets()
		end
		if next(_takeovers) then
			bake_all_takeovers()
		end
		-- Geometry only when visual frame or cut config dirtied the seam.
		local need_seam = false
		for _, to in pairs(_takeovers) do
			if to.seam_align and (to.seam_align_dirty or to.geometry_dirty) then
				need_seam = true
				break
			end
		end
		if not need_seam then
			for _, list in pairs(_grafts) do
				for i = 1, #list do
					local g = list[i]
					if g.seam_align and (g.seam_align_dirty or g.geometry_dirty) then
						need_seam = true
						break
					end
				end
				if need_seam then break end
			end
		end
		if need_seam then
			refresh_all_seam_aligns()
			for _, to in pairs(_takeovers) do
				to.seam_align_dirty = false
			end
			for _, list in pairs(_grafts) do
				for i = 1, #list do
					list[i].seam_align_dirty = false
				end
			end
		else
			_perf.geometry_skips = (_perf.geometry_skips or 0) + 1
		end
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_NPC_RENDER,
	params = nil,
	Function = function(_, ent, offset)
		if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
		local npc = ent and ent:ToNPC()
		if not npc then return end
		local key = GetPtrHash(npc)
		local to = _takeovers[key]
		if to then
			to.host = npc
			if npc.Visible == false then
				return false
			end
			-- cancel_vanilla=false: leave default NPC draw alone.
			if to.cancel_vanilla == false then
				return
			end
			-- Engine shadow off; draw one full shadow, then spliced body/donor.
			suppress_host_engine_shadow(to, npc)
			draw_full_host_shadow(npc, to, offset)
			blit_takeover_full(npc, to, offset)
			M.render_diag_overlay(npc, offset)
			-- PRE return false may skip POST_NPC_RENDER for this entity.
			-- Gate3C complementary donor must be drawn here or it never appears.
			if next(_grafts) then
				M.render_for_host(npc, "behind", offset)
				M.render_for_host(npc, "front", offset)
			end
			-- Cancel default NPC body. Engine shadow already suppressed above.
			return false
		end
		if next(_grafts) then
			M.render_for_host(npc, "behind", offset)
		end
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NPC_RENDER,
	params = nil,
	Function = function(_, ent, offset)
		if not next(_grafts) then return end
		if Game():GetRoom():GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end
		local npc = ent and ent:ToNPC()
		if not npc then return end
		M.render_for_host(npc, "front", offset)
	end,
})

table.insert(M.ToCall, #M.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		M.clear_all()
	end,
})

return M
