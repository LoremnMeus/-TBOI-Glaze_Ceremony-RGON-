-- Generic Sprite → Image bake + complementary clip blit for sprite_splice.
-- Does not know Entity / NPC / WorldToScreen. Consumer supplies draw callback.

local M = {
	TARGET_SIZE = 128,
	SHADER_PATH = "shaders/suture_runtime_clip",
}

local _shader = nil
local _shader_failed = false
local _pool = {}
local _last_error = nil

local function set_error(msg)
	_last_error = msg
end

function M.get_last_error()
	return _last_error
end

local function api_ready()
	if not REPENTOGON then
		set_error("REPENTOGON missing")
		return false
	end
	if not Renderer or not Renderer.CreateImage or not Renderer.RenderToImage then
		set_error("Renderer.CreateImage / RenderToImage unavailable")
		return false
	end
	return true
end

function M.api_ready()
	return api_ready()
end

function M.load_clip_shader()
	if _shader then
		return _shader
	end
	if _shader_failed or not api_ready() or not Renderer.LoadShader then
		return nil
	end
	local fmt = Renderer.VertexAttributeFormat
	if not fmt then
		_shader_failed = true
		set_error("VertexAttributeFormat missing")
		return nil
	end
	local ok, shader_or_err = pcall(function()
		return Renderer.LoadShader(M.SHADER_PATH, {
			{ "Position", fmt.POSITION },
			{ "Color", fmt.COLOR },
			{ "TexCoord", fmt.TEX_COORD },
			{ "TextureSize", fmt.VEC2 },
			{ "LogicalSize", fmt.VEC2 },
			{ "CutOrigin", fmt.VEC2 },
			{ "CutNormal", fmt.VEC2 },
			{ "KeepSign", fmt.FLOAT },
			{ "Feather", fmt.FLOAT },
		})
	end)
	if not ok or not shader_or_err then
		_shader_failed = true
		set_error("LoadShader failed: " .. tostring(shader_or_err))
		return nil
	end
	_shader = shader_or_err
	return _shader
end

function M.acquire_source(size)
	size = tonumber(size) or M.TARGET_SIZE
	local bucket = _pool[size]
	if not bucket then
		bucket = {}
		_pool[size] = bucket
	end
	for i = 1, #bucket do
		local slot = bucket[i]
		if not slot.busy then
			slot.busy = true
			return slot
		end
	end
	if not api_ready() then return nil end
	local name = string.format("qing_sprite_splice_rt_%d_%d", size, #bucket + 1)
	local ok, image = pcall(function()
		return Renderer.CreateImage(size, size, name)
	end)
	if not ok or not image then
		set_error("CreateImage failed: " .. tostring(image))
		return nil
	end
	local slot = { image = image, size = size, busy = true, name = name }
	bucket[#bucket + 1] = slot
	return slot
end

function M.release_source(slot)
	if slot then
		slot.busy = false
	end
end

--[[
Capture modes:

  entity_render (production live NPC):
    EntityNPC:Render(rt_offset) inside Renderer.RenderToImage
    Treat Entity render as a black box. Never Visible writes, never Sprite:Update,
    never RenderLayer.

  sprite_render (UI / generic Sprite consumer):
    Sprite:Render() inside Renderer.RenderToImage

Forbidden in all production capture:
  - RenderLayer enumeration
  - manual layer filtering / shadow heuristics
  - temporary layer visibility mutation
  - manual overlay recreation
  - writing Entity.Visible
]]

--- Sprite bake for UI / non-entity sources.
--- Returns ok, capture_mode ("sprite_render" | "custom").
function M.bake_sprite(slot, sprite, opts)
	opts = opts or {}
	if not slot or not slot.image or not sprite then
		return false, nil
	end

	local draw = opts.draw
	local capture_mode = "sprite_render"
	if type(draw) == "function" then
		capture_mode = "custom"
	else
		draw = function(spr, center)
			spr:Render(center, Vector.Zero, Vector.Zero)
		end
	end

	local size = slot.size
	local center = Vector(size * 0.5, size * 0.5)

	local ok, err = pcall(function()
		Renderer.RenderToImage(slot.image, function(controller)
			if controller and controller.Clear then
				controller:Clear()
			end
			draw(sprite, center)
		end)
	end)

	if not ok then
		set_error("bake_sprite failed: " .. tostring(err))
		slot.capture_mode = nil
		return false, nil
	end
	slot.capture_mode = capture_mode
	return true, capture_mode
end

--- Cache schema:
---   v1 = status-inclusive capture (charm heart in RT)
---   v2 = render-time charm suppression workaround
---   v3 = FRIENDLY-only linkees (superseded; broke friendly AI)
---   v4 = full-image charm pixel sanitizer (superseded; too expensive)
---   v5 = centerline-only scale + per-side GeometryNode analysis cache
M.GEOMETRY_CACHE_VERSION = 7

--- Live native Entity capture into RT.
--- Inverts Formula B so Entity:Render(callbackOffset) lands at RT center.
--- opts.wrap(fn): optional reentrancy guard around ent:Render (adapter ownership).
--- opts.registration_offset: optional Vector/table added to render_offset (seam normal
---   compensation computed by sprite_visual_registration; applied here so geometry sees
---   a registered RT, not a root-jittered silhouette).
--- Does not write Position / PositionOffset / Visible / Sprite / EntityFlags.
--- Returns ok, capture_mode ("entity_render").
function M.capture_entity(slot, ent, opts)
	opts = opts or {}
	if not slot or not slot.image or not ent then
		return false, nil
	end
	if not ent.Exists or not ent:Exists() then
		set_error("capture_entity: entity missing")
		return false, nil
	end
	if not ent.Render then
		set_error("capture_entity: Entity:Render unavailable")
		return false, nil
	end

	local size = slot.size
	local center = Vector(size * 0.5, size * 0.5)
	local room = Game():GetRoom()
	local screen = Isaac.WorldToScreen(ent.Position + ent.PositionOffset)
		- room:GetRenderScrollOffset()
	local reg = opts.registration_offset
	local rx, ry = 0, 0
	if reg ~= nil then
		if type(reg) == "userdata" or type(reg) == "table" then
			rx = tonumber(reg.X or reg.x or reg[1]) or 0
			ry = tonumber(reg.Y or reg.y or reg[2]) or 0
		end
	end
	local render_offset = center - screen + Vector(rx, ry)
	local wrap = opts.wrap

	local ok, err = pcall(function()
		Renderer.RenderToImage(slot.image, function(controller)
			if controller and controller.Clear then
				controller:Clear()
			end
			local function do_render()
				ent:Render(render_offset)
			end
			if type(wrap) == "function" then
				wrap(do_render)
			else
				do_render()
			end
		end)
	end)

	if not ok then
		set_error("capture_entity failed: " .. tostring(err))
		slot.capture_mode = nil
		slot.registration = nil
		return false, nil
	end
	slot.capture_mode = "entity_render"
	slot.registration = opts.registration_diag
	return true, "entity_render"
end

--- Debug-only helper.
--- Canonical Runtime Stitch capture MUST NOT use this function.
--- Sprite:Render() is the authoritative source capture path.
--- Kept for experimental layer / shadow probes only.
local function layer_looks_like_shadow(layer)
	if not layer then
		return false
	end
	local name
	if layer.GetName then
		local ok, v = pcall(function()
			return layer:GetName()
		end)
		if ok then
			name = v
		end
	end
	if type(name) ~= "string" then
		return false
	end
	local lower = string.lower(name)
	return lower == "shadow" or string.find(lower, "shadow", 1, true) ~= nil
end

local function for_each_sprite_layer(sprite, fn)
	if not sprite or not sprite.GetLayerCount then
		return
	end
	local ok, count = pcall(function()
		return sprite:GetLayerCount()
	end)
	if not ok or not count then
		return
	end
	for i = 0, count - 1 do
		local layer
		if sprite.GetLayer then
			local ok2, v = pcall(function()
				return sprite:GetLayer(i)
			end)
			if ok2 then
				layer = v
			end
		end
		if layer then
			fn(layer, i)
		end
	end
end

--- Debug-only / experimental. Production Runtime Stitch MUST NOT call this.
function M.render_sprite_shadowless(sprite, center)
	if not sprite or not center then
		return
	end
	local restored = {}
	local can_toggle = false
	for_each_sprite_layer(sprite, function(layer)
		if not layer_looks_like_shadow(layer) then
			return
		end
		if not (layer.SetVisible and layer.IsVisible) then
			return
		end
		can_toggle = true
		local ok, was = pcall(function()
			return layer:IsVisible()
		end)
		if ok then
			restored[#restored + 1] = { layer = layer, visible = was ~= false }
			pcall(function()
				layer:SetVisible(false)
			end)
		end
	end)
	if can_toggle and #restored > 0 then
		pcall(function()
			sprite:Render(center)
		end)
		for i = 1, #restored do
			local entry = restored[i]
			pcall(function()
				entry.layer:SetVisible(entry.visible)
			end)
		end
		return
	end
	-- Debug fallback only — not production capture.
	local layers = {}
	for_each_sprite_layer(sprite, function(layer)
		layers[#layers + 1] = layer
	end)
	if sprite.RenderLayer and #layers > 0 then
		local rendered_any = false
		for i = 1, #layers do
			local layer = layers[i]
			if not layer_looks_like_shadow(layer) then
				local id = i - 1
				if layer.GetLayerID then
					local ok, v = pcall(function()
						return layer:GetLayerID()
					end)
					if ok and v ~= nil then
						id = v
					end
				end
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
					rendered_any = true
					pcall(function()
						sprite:RenderLayer(id, center, Vector(0, 0), Vector(0, 0))
					end)
				end
			end
		end
		if rendered_any then
			return
		end
	end
	pcall(function()
		sprite:Render(center)
	end)
end

--- Blit a full (unclipped) baked RT to screen. Used by parity probes.
function M.render_full(slot, screen_pos, opts)
	opts = opts or {}
	if not slot or not slot.image or not screen_pos then
		return false
	end
	local scale = tonumber(opts.scale) or 1
	local logical = slot.size
	local draw = logical * scale
	local half = draw * 0.5
	local tl = Vector(screen_pos.X - half, screen_pos.Y - half)
	local tint = opts.tint or KColor(1, 1, 1, 1)
	local src = SourceQuad.NewFromRectangle(Vector(0, 0), logical, logical, false)
	local dest = DestinationQuad.NewFromRectangle(tl, draw, draw)
	pcall(function()
		slot.image:Render(src, dest, tint)
	end)
	return true
end

--- Export unclipped source RT as PPM text (for capture-vs-geometry diagnosis).
function M.export_source_ppm(slot)
	if not slot or not slot.image or not slot.image.GetTexelRegion then
		return nil, "slot/image unavailable"
	end
	local size = slot.size
	local ok, data = pcall(function()
		return slot.image:GetTexelRegion(0, 0, size, size)
	end)
	if not ok or not data then
		return nil, "GetTexelRegion failed: " .. tostring(data)
	end
	local lines = { "P3", string.format("%d %d", size, size), "255" }
	local n = size * size
	for i = 0, n - 1 do
		local c = data[i]
		local r, g, b = 0, 0, 0
		if c then
			r = math.floor((c.Red or c.R or 0) * 255 + 0.5)
			g = math.floor((c.Green or c.G or 0) * 255 + 0.5)
			b = math.floor((c.Blue or c.B or 0) * 255 + 0.5)
		end
		lines[#lines + 1] = string.format("%d %d %d", r, g, b)
	end
	return table.concat(lines, "\n") .. "\n"
end

--- Blit one complementary half with clip shader.
--- opts: cut_origin, cut_normal, keep_sign, feather, scale, offset {x,y},
---       tint (KColor), flip_y, reflect_flip_mode (0=none, 1=destination, 2=source)
--- WATER_REFLECT production uses mode 2: SourceQuad FlipY + clip-plane Y mirror.
--- DestinationQuad must stay an upright rectangle (inverted dest geometry is culled
--- silently by ImageUtils::SubmitQuadForShader — pcall still succeeds).
function M.render_half(slot, screen_pos, opts)
	opts = opts or {}
	if not slot or not slot.image or not screen_pos then
		return false
	end
	local scale = tonumber(opts.scale) or 1
	local offset = opts.offset or { 0, 0 }
	local ox = offset[1] or offset.x or 0
	local oy = offset[2] or offset.y or 0

	local cut_origin = opts.cut_origin or { 0.5, 0.5 }
	local cut_normal = opts.cut_normal or { 1, 0 }
	local cox = cut_origin[1] or 0.5
	local coy = cut_origin[2] or 0.5
	local cnx = cut_normal[1] or 1
	local cny = cut_normal[2] or 0

	-- 0=none, 1=destination (A/B), 2=source (production default when flip_y)
	local flip_mode = 0
	if opts.flip_y then
		local m = tonumber(opts.reflect_flip_mode)
		if m == 0 or m == 1 or m == 2 then
			flip_mode = m
		else
			flip_mode = 2
		end
	end

	local do_offset_mirror = flip_mode == 1 or flip_mode == 2
	local do_src_flip = flip_mode == 2
	local do_dst_flip = flip_mode == 1
	local do_clip_mirror = flip_mode == 2

	if do_offset_mirror then
		oy = -oy
	end
	if do_clip_mirror then
		-- UV Y mirror: point (x,y) → (x, 1-y); normal (nx,ny) → (nx, -ny)
		coy = 1.0 - coy
		cny = -cny
	end

	local logical = slot.size
	local draw = logical * scale
	local half = draw * 0.5
	local tl = Vector(screen_pos.X - half + ox, screen_pos.Y - half + oy)
	local src = SourceQuad.NewFromRectangle(Vector(0, 0), logical, logical, false)
	if do_src_flip and src.Flip then
		src:Flip(false, true)
	end
	-- DestinationQuad always built upright; Flip only for A/B mode 1.
	local dst = DestinationQuad.NewFromRectangle(tl, draw, draw)
	if do_dst_flip and dst.Flip then
		dst:Flip(false, true)
	end

	local tint = opts.tint or KColor(1, 1, 1, 1)
	local keep_sign = (opts.keep_sign ~= nil) and opts.keep_sign or -1
	local feather = opts.feather or 0
	local padded_w = (slot.image.GetPaddedWidth and slot.image:GetPaddedWidth()) or logical
	local padded_h = (slot.image.GetPaddedHeight and slot.image:GetPaddedHeight()) or logical
	local logical_w = (slot.image.GetWidth and slot.image:GetWidth()) or logical
	local logical_h = (slot.image.GetHeight and slot.image:GetHeight()) or logical
	local shader = M.load_clip_shader()
	if shader and slot.image.RenderWithShader then
		local ok = pcall(function()
			slot.image:RenderWithShader(src, dst, tint, shader, {
				TextureSize = { padded_w, padded_h },
				LogicalSize = { logical_w, logical_h },
				CutOrigin = { cox, coy },
				CutNormal = { cnx, cny },
				KeepSign = keep_sign,
				Feather = feather,
			})
		end)
		-- pcall success ≠ pixels submitted; SubmitQuadForShader may cull silently.
		return ok == true
	end
	pcall(function()
		slot.image:Render(src, dst, tint)
	end)
	return false
end

local function round_key_num(v, digits)
	v = tonumber(v) or 0
	digits = digits or 3
	local m = 10 ^ digits
	return math.floor(v * m + 0.5) / m
end

--- Overlay only when GetOverlayAnimation() is non-empty (actually playing/rendering).
--- Do not treat GetOverlayFrame() alone as proof of overlay presence.
function M.get_rendered_overlay_pose(sprite)
	if not sprite or not sprite.GetOverlayAnimation then
		return "", -1, false
	end
	local ok_anim, anim = pcall(function()
		return sprite:GetOverlayAnimation()
	end)
	if not ok_anim or not anim or anim == "" then
		return "", -1, false
	end
	local frame = -1
	if sprite.GetOverlayFrame then
		local ok_frame, value = pcall(function()
			return sprite:GetOverlayFrame()
		end)
		if ok_frame then
			frame = tonumber(value) or -1
		end
	end
	return anim, frame, true
end

--- Pose key for scale cache: base anim+frame + rendered overlay only.
--- Excludes Position / PositionOffset / Scale / Rotation / Flip / StateFrame.
function M.get_pose_key(sprite)
	if not sprite then
		return "nil"
	end
	local anim = ""
	local frame = -1
	pcall(function()
		anim = sprite:GetAnimation() or ""
		frame = sprite:GetFrame() or -1
	end)
	local oanim, oframe = M.get_rendered_overlay_pose(sprite)
	return table.concat({
		tostring(anim),
		tostring(frame),
		tostring(oanim),
		tostring(oframe),
	}, ":")
end

--- Discrete GeometryNode identity (Stitch Edition Combination semantics).
--- Includes: anim + discrete frame + overlay + Flip + crop fingerprint.
--- Excludes: Interpolated Position / Scale / Rotation (runtime transform only).
function M.get_geometry_node_info(sprite)
	local info = {
		anim = "",
		frame = -1,
		overlay_anim = "",
		overlay_frame = -1,
		overlay_rendered = false,
		flip_x = 0,
		flip_y = 0,
		crop_key = "",
		key = "nil",
	}
	if not sprite then
		return info
	end
	local anim, frame = "", -1
	local fx, fy = 0, 0
	pcall(function()
		anim = sprite:GetAnimation() or ""
		frame = sprite:GetFrame() or -1
		fx = sprite.FlipX and 1 or 0
		fy = sprite.FlipY and 1 or 0
	end)
	local oanim, oframe, has_overlay = M.get_rendered_overlay_pose(sprite)
	-- Crop fingerprint from visible layers (CombinationID proxy). Stable under Position lerp.
	local crops = {}
	pcall(function()
		if not (sprite.GetCurrentAnimationData and sprite.GetLayerFrameData) then
			return
		end
		local anim_data = sprite:GetCurrentAnimationData()
		if not anim_data or not anim_data.GetAllLayers then
			return
		end
		local layers = anim_data:GetAllLayers()
		if type(layers) ~= "table" then
			return
		end
		for _, layer in pairs(layers) do
			if layer and layer.GetLayerID then
				local lid = layer:GetLayerID()
				local fd = sprite:GetLayerFrameData(lid)
				if fd and fd.IsVisible and fd:IsVisible() and fd.GetCrop then
					local c = fd:GetCrop()
					local w = fd.GetWidth and fd:GetWidth() or 0
					local h = fd.GetHeight and fd:GetHeight() or 0
					local px = fd.GetPivot and fd:GetPivot()
					crops[#crops + 1] = table.concat({
						tostring(lid),
						tostring(round_key_num(c and c.X, 1)),
						tostring(round_key_num(c and c.Y, 1)),
						tostring(round_key_num(w, 1)),
						tostring(round_key_num(h, 1)),
						tostring(round_key_num(px and px.X, 1)),
						tostring(round_key_num(px and px.Y, 1)),
					}, ",")
				end
			end
		end
	end)
	table.sort(crops)
	local crop_key = table.concat(crops, "|")
	info.anim = anim
	info.frame = frame
	info.overlay_anim = oanim
	info.overlay_frame = oframe
	info.overlay_rendered = has_overlay == true
	info.flip_x = fx
	info.flip_y = fy
	info.crop_key = crop_key
	info.visible_layer_count = #crops
	local charm_tag = "cf1"
	do
		local ok_cf, charm_filter = pcall(require, "Qing_Remaster_scripts.auxiliary.runtime_stitch_charm_filter")
		if ok_cf and charm_filter and charm_filter.cache_tag then
			charm_tag = tostring(charm_filter.cache_tag())
		end
	end
	info.charm_filter_tag = charm_tag
	info.key = table.concat({
		"v" .. tostring(M.GEOMETRY_CACHE_VERSION or 4),
		charm_tag,
		tostring(anim),
		tostring(frame),
		tostring(oanim),
		tostring(oframe),
		tostring(fx),
		tostring(fy),
		crop_key,
	}, ":")
	info.geometry_cache_version = M.GEOMETRY_CACHE_VERSION or 4
	return info
end

--- Structured pose for diagnostics / UI.
function M.get_pose_info(sprite)
	local node = M.get_geometry_node_info(sprite)
	return {
		anim = node.anim,
		frame = node.frame,
		overlay_rendered = node.overlay_rendered,
		overlay_anim = node.overlay_anim,
		overlay_frame = node.overlay_frame,
		flip_x = node.flip_x,
		flip_y = node.flip_y,
		crop_key = node.crop_key,
		geometry_node_key = node.key,
		key = M.get_pose_key(sprite),
	}
end

--- Silhouette key only. Color / Position / Offset must not be included.
--- Includes Scale.X/Y and Rotation (rounded) so bake refreshes on pose scale/rotate.
function M.sprite_frame_key(sprite)
	if not sprite then
		return "nil"
	end
	local anim, frame, oanim, oframe, fx, fy = "?", -1, "", -1, 0, 0
	local sx, sy, rot = 1, 1, 0
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
		local sc = sprite.Scale
		if sc then
			sx = sc.X or 1
			sy = sc.Y or 1
		end
		rot = sprite.Rotation or 0
	end)
	return table.concat({
		tostring(anim),
		tostring(frame),
		tostring(oanim),
		tostring(oframe),
		tostring(fx),
		tostring(fy),
		tostring(round_key_num(sx, 3)),
		tostring(round_key_num(sy, 3)),
		tostring(round_key_num(rot, 2)),
	}, ":")
end

return M
