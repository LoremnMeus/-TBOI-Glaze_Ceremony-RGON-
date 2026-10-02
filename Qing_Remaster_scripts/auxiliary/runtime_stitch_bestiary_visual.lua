-- EntityConfig bestiary presentation helper for Runtime Stitch UI.
-- UI panels must use GetBestiary* — never hand-rolled animation_candidates.

local M = {}

local function cfg_of(type_id, variant, subtype)
	if not EntityConfig or not EntityConfig.GetEntity then
		return nil, "EntityConfig.GetEntity missing"
	end
	local ok, cfg = pcall(function()
		return EntityConfig.GetEntity(type_id, variant or 0, subtype or 0)
	end)
	if not ok or not cfg then
		return nil, "GetEntity failed"
	end
	return cfg
end

function M.build(type_id, variant, subtype)
	type_id = tonumber(type_id)
	if not type_id then return nil, "missing type" end
	variant = tonumber(variant) or 0
	subtype = tonumber(subtype) or 0
	local cfg, err = cfg_of(type_id, variant, subtype)
	if not cfg then return nil, err end

	local path, anim, overlay, offset, scale
	pcall(function()
		if cfg.GetBestiaryAnm2Path then path = cfg:GetBestiaryAnm2Path() end
	end)
	pcall(function()
		if cfg.GetBestiaryAnimation then anim = cfg:GetBestiaryAnimation() end
	end)
	pcall(function()
		if cfg.GetBestiaryOverlay then overlay = cfg:GetBestiaryOverlay() end
	end)
	pcall(function()
		if cfg.GetBestiaryOffset then offset = cfg:GetBestiaryOffset() end
	end)
	pcall(function()
		if cfg.GetBestiaryScale then scale = cfg:GetBestiaryScale() end
	end)

	if type(path) ~= "string" or path == "" then
		pcall(function()
			if cfg.GetAnm2Path then path = cfg:GetAnm2Path() end
		end)
	end
	if type(path) ~= "string" or path == "" then
		return nil, "empty bestiary/anm2 path"
	end
	if type(anim) ~= "string" or anim == "" then
		anim = "Idle"
	end
	scale = tonumber(scale) or 1
	if scale <= 0 then scale = 1 end
	offset = offset or Vector(0, 0)

	local spr = Sprite()
	local ok_load = pcall(function()
		spr:Load(path, true)
	end)
	if not ok_load then
		return nil, "Sprite:Load failed for " .. tostring(path)
	end
	pcall(function()
		spr:Play(anim, true)
	end)
	if type(overlay) == "string" and overlay ~= "" then
		pcall(function()
			spr:PlayOverlay(overlay, true)
		end)
	end

	return {
		sprite = spr,
		offset = offset,
		scale = scale,
		path = path,
		anim = anim,
		overlay = overlay,
		type = type_id,
		variant = variant,
		subtype = subtype,
	}
end

function M.build_from_source(source)
	if type(source) ~= "table" then return nil, "missing source" end
	return M.build(source.type, source.variant, source.subtype)
end

function M.update(visual)
	if not visual or not visual.sprite then return end
	-- Dedup on Game frame (30 Hz). Safe even if a consumer calls Update twice per render.
	local frame = Game():GetFrameCount()
	if visual.last_update_frame == frame then
		return
	end
	visual.last_update_frame = frame
	pcall(function()
		visual.sprite:Update()
	end)
end

local function apply_pose(visual, scale_mul)
	local spr = visual.sprite
	local base = tonumber(visual.scale) or 1
	local s = base * (tonumber(scale_mul) or 1)
	local off = visual.offset or Vector(0, 0)
	return spr, s, off
end

--- Render bestiary visual at screen position (sprite pivot). Single draw only.
function M.render(visual, pos, scale_mul, color)
	if not visual or not visual.sprite or not pos then return end
	local spr, s, off = apply_pose(visual, scale_mul)
	local prev = spr.Scale
	local prev_c = spr.Color
	spr.Scale = Vector(s, s)
	if color then
		spr.Color = color
	end
	pcall(function()
		spr:Render(pos + off * s, Vector.Zero, Vector.Zero)
	end)
	spr.Scale = prev or Vector(1, 1)
	spr.Color = prev_c or Color(1, 1, 1, 1)
end

-- Color-only highlight modes. NEVER multi-draw / NEVER change geometry.
local HIGHLIGHT_COLORS = {
	hover = Color(1, 1, 1, 1, 0.30, 0.30, 0.12),
	locked = Color(1, 0.88, 0.55, 1, 0.18, 0.12, 0),
	hover_locked = Color(1, 0.95, 0.62, 1, 0.32, 0.24, 0.05),
}

function M.color_for_mode(mode)
	return HIGHLIGHT_COLORS[mode] or Color(1, 1, 1, 1)
end

--- Single-draw highlight via Color. Kept for API stability; does not offset-copy.
function M.render_highlight(visual, pos, scale_mul, mode, _highlight_offset)
	M.render(visual, pos, scale_mul, M.color_for_mode(mode))
end

--- Draw callback for sprite_splice bake (applies BestiaryScale + Offset).
--- Still uses Sprite:Render — only presentation offset/scale differs from native.
--- Not a RenderLayer / shadowless path.
function M.make_draw(visual)
	return function(spr, center)
		if not visual then
			spr:Render(center, Vector.Zero, Vector.Zero)
			return
		end
		local base = tonumber(visual.scale) or 1
		local off = visual.offset or Vector(0, 0)
		local prev = spr.Scale
		spr.Scale = Vector(base, base)
		spr:Render(center + off * base, Vector.Zero, Vector.Zero)
		spr.Scale = prev or Vector(1, 1)
	end
end

--- Draw bestiary visual into an RT slot, applying official scale+offset.
--- Used by UI preview bake so center matches side columns.
function M.bake_to_slot(visual, slot, render_sprite_fn)
	if not visual or not visual.sprite or not slot or not slot.image then
		return false
	end
	if type(render_sprite_fn) ~= "function" then
		return false
	end
	local size = slot.size
	local center = Vector(size * 0.5, size * 0.5)
	local spr, s, off = apply_pose(visual, 1)
	local prev = spr.Scale
	spr.Scale = Vector(s, s)
	local ok, err = pcall(function()
		Renderer.RenderToImage(slot.image, function(controller)
			if controller and controller.Clear then
				controller:Clear()
			end
			render_sprite_fn(spr, center + off * s)
		end)
	end)
	spr.Scale = prev or Vector(1, 1)
	return ok == true, err
end

function M.destroy(visual)
	if not visual then return end
	visual.sprite = nil
end

return M
