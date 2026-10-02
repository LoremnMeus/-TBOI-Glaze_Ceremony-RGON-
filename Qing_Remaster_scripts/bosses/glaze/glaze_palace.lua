-- Glaze Palace: Boss visual / spatial subsystem (not an attack, not a phase).
-- State lives on ctx.palace only. Attacks may only use get_anchor* APIs.

local Assets = require("Qing_Remaster_scripts.bosses.glaze.glaze_visual_assets")

local Palace = {}

local BUILD_SPAN = 0.18
local COLLAPSE_SPAN = 0.22
local BUILD_SPEED = 0.035
local COLLAPSE_SPEED = 0.028

local KIND_SCALE = {
	block = Vector(1.0, 1.0),
	long = Vector(1.0, 2.0),
	diamond = Vector(1.1, 1.1),
	triangle = Vector(0.9, 0.9),
	window = Vector(0.75, 1.75),
	crown_tip = Vector(0.5, 1.25),
}

-- Lazy: Color is an Isaac API; headless tests load this module before Color exists.
local PALETTES = nil
local function get_palettes()
	if PALETTES then return PALETTES end
	PALETTES = {
		normal = {
			Color(0.35, 0.85, 1.00, 0.92),
			Color(0.45, 0.55, 1.00, 0.92),
			Color(0.75, 0.40, 0.95, 0.92),
			Color(1.00, 0.45, 0.70, 0.92),
			Color(1.00, 0.82, 0.35, 0.92),
		},
		broken = {
			Color(0.55, 0.60, 0.65, 0.55),
			Color(0.50, 0.55, 0.70, 0.50),
			Color(0.60, 0.50, 0.55, 0.45),
			Color(0.45, 0.45, 0.50, 0.40),
			Color(0.70, 0.65, 0.50, 0.40),
		},
	}
	return PALETTES
end

-- Fixed hand layout relative to room center. mirror_of duplicates with X flip.
local LAYOUT = {
	{
		id = "top_left",
		origin = Vector(-180, -95),
		pieces = {
			{kind = "long", x = 0, y = 0, rot = 0, tags = {}},
			{kind = "block", x = 16, y = 28, rot = 0, tags = {}},
			{kind = "window", x = 8, y = 52, rot = 0, tags = {"mirror", "ray"}, anchor = "TOP_LEFT_WINDOW"},
			{kind = "diamond", x = 28, y = 78, rot = 45, tags = {"mirror", "ray"}, anchor = "LEFT_DIAMOND"},
			{kind = "crown_tip", x = 28, y = 100, rot = 0, tags = {}},
		},
	},
	{
		id = "top",
		origin = Vector(0, -115),
		pieces = {
			{kind = "block", x = -24, y = 0, rot = 0, tags = {}},
			{kind = "block", x = 0, y = 0, rot = 0, tags = {}},
			{kind = "block", x = 24, y = 0, rot = 0, tags = {}},
			{kind = "triangle", x = 0, y = -18, rot = 0, tags = {}},
			{kind = "window", x = 0, y = 28, rot = 0, tags = {"mirror", "ray"}, anchor = "TOP_WINDOW"},
			{kind = "diamond", x = 0, y = 56, rot = 45, tags = {"mirror"}, anchor = "TOP_DIAMOND"},
		},
	},
	{
		id = "top_right",
		mirror_of = "top_left",
	},
	{
		id = "left_high",
		origin = Vector(-200, -20),
		pieces = {
			{kind = "long", x = 0, y = 0, rot = 90, tags = {}},
			{kind = "block", x = 24, y = -8, rot = 0, tags = {}},
			{kind = "diamond", x = 40, y = 12, rot = 45, tags = {"mirror", "ray"}, anchor = "LEFT_HIGH_DIAMOND"},
		},
	},
	{
		id = "left_low",
		origin = Vector(-175, 70),
		pieces = {
			{kind = "block", x = 0, y = 0, rot = 0, tags = {}},
			{kind = "long", x = 16, y = 8, rot = 15, tags = {}},
			{kind = "window", x = 8, y = 36, rot = 0, tags = {"mirror"}, anchor = "LEFT_LOW_WINDOW"},
		},
	},
	{
		id = "right_high",
		mirror_of = "left_high",
	},
	{
		id = "right_low",
		mirror_of = "left_low",
	},
	{
		id = "bottom_left",
		origin = Vector(-150, 105),
		pieces = {
			{kind = "block", x = 0, y = 0, rot = 0, tags = {}, remnant = true},
			{kind = "triangle", x = 18, y = 10, rot = 180, tags = {}, remnant = true},
			{kind = "crown_tip", x = 8, y = 28, rot = 20, tags = {}, remnant = true},
		},
	},
	{
		id = "bottom_right",
		mirror_of = "bottom_left",
	},
}

local function clamp(v, a, b)
	if v < a then return a end
	if v > b then return b end
	return v
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function ease(t)
	t = clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function inverse_lerp(a, b, v)
	if math.abs(b - a) < 1e-6 then return v >= b and 1 or 0 end
	return (v - a) / (b - a)
end

local function color_lerp(a, b, t)
	local c = Color(
		lerp(a.R, b.R, t),
		lerp(a.G, b.G, t),
		lerp(a.B, b.B, t),
		lerp(a.A, b.A, t)
	)
	return c
end

local function mirror_layout(src, id)
	local out = {id = id, origin = Vector(-src.origin.X, src.origin.Y), pieces = {}}
	for i, piece in ipairs(src.pieces) do
		local copy = {
			kind = piece.kind,
			x = -piece.x,
			y = piece.y,
			rot = -piece.rot,
			tags = piece.tags,
			remnant = piece.remnant,
		}
		if piece.anchor then
			copy.anchor = piece.anchor:gsub("LEFT", "RIGHT"):gsub("left", "right")
			if copy.anchor == piece.anchor and piece.anchor:find("TOP_") then
				-- TOP_LEFT_WINDOW → TOP_RIGHT_WINDOW already handled by LEFT→RIGHT
			elseif piece.anchor == "LEFT_DIAMOND" then
				copy.anchor = "RIGHT_DIAMOND"
			elseif piece.anchor == "LEFT_HIGH_DIAMOND" then
				copy.anchor = "RIGHT_HIGH_DIAMOND"
			elseif piece.anchor == "LEFT_LOW_WINDOW" then
				copy.anchor = "RIGHT_LOW_WINDOW"
			end
		end
		out.pieces[i] = copy
	end
	return out
end

local function resolved_layout()
	local by_id = {}
	local list = {}
	for _, entry in ipairs(LAYOUT) do
		if entry.mirror_of then
			local src = by_id[entry.mirror_of]
			local mirrored = mirror_layout(src, entry.id)
			by_id[entry.id] = mirrored
			list[#list + 1] = mirrored
		else
			by_id[entry.id] = entry
			list[#list + 1] = entry
		end
	end
	return list
end

local RESOLVED = resolved_layout()

local function ensure_sprite(piece)
	if piece.sprite then return piece.sprite end
	local spr = Sprite()
	spr:Load(Assets.Palace.anm2, true)
	local anim = Assets.Palace.animations[piece.kind] or Assets.Palace.animations.block
	spr:Play(anim, true)
	piece.sprite = spr
	return spr
end

local function build_pieces(palace)
	palace.pieces = {}
	palace.anchors = {}
	local order = 0
	local total = 0
	for _, group in ipairs(RESOLVED) do
		total = total + #group.pieces
	end
	local index = 0
	for _, group in ipairs(RESOLVED) do
		for i, def in ipairs(group.pieces) do
			index = index + 1
			local build_order = (index - 1) / math.max(1, total - 1)
			local collapse_order = 1 - build_order * 0.85
			if def.remnant then collapse_order = 1.2 end
			local piece = {
				id = group.id .. "." .. string.format("%02d", i),
				kind = def.kind,
				anchor_group = group.id,
				local_pos = group.origin + Vector(def.x, def.y),
				base_rotation = def.rot or 0,
				rotation = def.rot or 0,
				scale = KIND_SCALE[def.kind] or Vector(1, 1),
				color_index = ((index + (palace.layout_seed % 5)) % 5) + 1,
				build_order = build_order,
				collapse_order = clamp(collapse_order, 0, 1.2),
				attack_tags = def.tags or {},
				remnant = def.remnant == true,
				anchor_name = def.anchor,
				sprite = nil,
				collapse_offset = Vector.Zero,
			}
			palace.pieces[#palace.pieces + 1] = piece
			if def.anchor then
				palace.anchors[def.anchor] = {
					id = def.anchor,
					piece_id = piece.id,
					tags = def.tags or {},
					local_pos = piece.local_pos,
					orientation = Vector(math.cos(math.rad(piece.base_rotation)), math.sin(math.rad(piece.base_rotation))),
				}
			end
		end
	end
end

local function room_center(ctx)
	if ctx.center then return ctx.center end
	if ctx.room and ctx.room.GetCenterPos then return ctx.room:GetCenterPos() end
	return Game():GetRoom():GetCenterPos()
end

local function piece_world_pos(ctx, piece)
	return room_center(ctx) + piece.local_pos + (piece.collapse_offset or Vector.Zero)
end

local function piece_build_t(palace, piece)
	return clamp(inverse_lerp(piece.build_order, piece.build_order + BUILD_SPAN, palace.build), 0, 1)
end

local function piece_collapse_t(palace, piece)
	local collapse = 1 - palace.stability
	return clamp(inverse_lerp(piece.collapse_order, piece.collapse_order + COLLAPSE_SPAN, collapse), 0, 1)
end

function Palace.create(ctx)
	local palace = {
		active = false,
		build = 0,
		target_build = 0,
		stability = 1,
		target_stability = 1,
		palette_mode = "normal",
		layout_seed = (ctx.boss and ctx.boss.InitSeed) or (ctx.hash or 1),
		pieces = {},
		anchors = {},
		debug = {
			show_anchors = false,
			show_piece_ids = false,
			show_attack_anchor = false,
		},
	}
	ctx.palace = palace
	build_pieces(palace)
	return palace
end

function Palace.reset(ctx)
	if not ctx.palace then
		Palace.create(ctx)
		return ctx.palace
	end
	local palace = ctx.palace
	palace.active = false
	palace.build = 0
	palace.target_build = 0
	palace.stability = 1
	palace.target_stability = 1
	palace.palette_mode = "normal"
	for _, piece in ipairs(palace.pieces) do
		piece.collapse_offset = Vector.Zero
		piece.rotation = piece.base_rotation
	end
	return palace
end

function Palace.begin_build(ctx)
	if not ctx.palace then Palace.create(ctx) end
	local palace = ctx.palace
	palace.active = true
	palace.target_build = 1
	palace.target_stability = 1
	palace.stability = 1
	palace.palette_mode = "normal"
end

function Palace.begin_collapse(ctx)
	if not ctx.palace then return end
	local palace = ctx.palace
	palace.active = true
	palace.target_build = 1
	palace.build = math.max(palace.build, 0.85)
	palace.target_stability = 0
	palace.palette_mode = "broken"
end

function Palace.set_build(ctx, value)
	if not ctx.palace then Palace.create(ctx) end
	local palace = ctx.palace
	palace.build = clamp(value, 0, 1)
	palace.target_build = palace.build
	palace.active = palace.build > 0.001 or palace.target_build > 0.001
end

function Palace.set_stability(ctx, value)
	if not ctx.palace then Palace.create(ctx) end
	local palace = ctx.palace
	palace.stability = clamp(value, 0, 1)
	palace.target_stability = palace.stability
	palace.active = true
	if palace.stability < 0.5 then palace.palette_mode = "broken" end
end

function Palace.set_palette(ctx, mode)
	if not ctx.palace then return end
	if mode ~= "normal" and mode ~= "broken" then return end
	ctx.palace.palette_mode = mode
end

function Palace.update(ctx)
	local palace = ctx.palace
	if not palace or not palace.active then return end
	if palace.build < palace.target_build then
		palace.build = math.min(palace.target_build, palace.build + BUILD_SPEED)
	elseif palace.build > palace.target_build then
		palace.build = math.max(palace.target_build, palace.build - BUILD_SPEED)
	end
	if palace.stability > palace.target_stability then
		palace.stability = math.max(palace.target_stability, palace.stability - COLLAPSE_SPEED)
	elseif palace.stability < palace.target_stability then
		palace.stability = math.min(palace.target_stability, palace.stability + COLLAPSE_SPEED)
	end
	for _, piece in ipairs(palace.pieces) do
		local ct = piece_collapse_t(palace, piece)
		if ct > 0 and not piece.remnant then
			local ang = piece.base_rotation + ct * 25 * (((piece.color_index % 2) == 0) and 1 or -1)
			piece.rotation = ang
			piece.collapse_offset = Vector(0, 1):Rotated(piece.color_index * 72) * (ct * 18)
		elseif piece.remnant and ct > 0 then
			piece.rotation = piece.base_rotation + ct * 12
			piece.collapse_offset = Vector(0, ct * 6)
		else
			piece.rotation = piece.base_rotation
			piece.collapse_offset = Vector.Zero
		end
	end
end

local function piece_color(palace, piece, build_t, collapse_t)
	local palettes = get_palettes()
	local normal = palettes.normal[piece.color_index]
	local broken = palettes.broken[piece.color_index]
	local mix = palace.palette_mode == "broken" and 1 or (1 - palace.stability)
	local base = color_lerp(normal, broken, clamp(mix, 0, 1))
	local alpha = ease(build_t) * (piece.remnant and (0.25 + 0.35 * (1 - clamp(collapse_t, 0, 1))) or (1 - ease(collapse_t)))
	if not piece.remnant and collapse_t >= 1 then alpha = 0 end
	base.A = base.A * alpha
	return base
end

function Palace.render(ctx)
	local palace = ctx.palace
	if not palace or not palace.active then return end
	if palace.build <= 0.001 and palace.target_build <= 0.001 then return end
	local scroll = Game():GetRoom():GetRenderScrollOffset()
	for _, piece in ipairs(palace.pieces) do
		local build_t = piece_build_t(palace, piece)
		local collapse_t = piece_collapse_t(palace, piece)
		if build_t > 0.001 then
			local spr = ensure_sprite(piece)
			local world = piece_world_pos(ctx, piece)
			local screen = Isaac.WorldToScreen(world) - scroll
			local scale_mul = lerp(0.4, 1.0, ease(build_t))
			spr.Scale = Vector(piece.scale.X * scale_mul, piece.scale.Y * scale_mul)
			spr.Rotation = piece.rotation
			spr.Color = piece_color(palace, piece, build_t, collapse_t)
			spr:Render(screen, Vector.Zero, Vector.Zero)
			if palace.debug.show_piece_ids then
				Isaac.RenderText(piece.id, screen.X - 20, screen.Y - 10, 1, 1, 1, 0.8)
			elseif palace.debug.show_attack_anchor and piece.anchor_name then
				Isaac.RenderText(piece.anchor_name, screen.X - 24, screen.Y - 12, 0.7, 1, 1, 0.9)
			end
		end
	end
	if palace.debug.show_anchors then
		for id, anchor in pairs(palace.anchors) do
			local pos = Isaac.WorldToScreen(room_center(ctx) + anchor.local_pos) - scroll
			Isaac.RenderText("[" .. id .. "]", pos.X - 30, pos.Y - 8, 1, 0.85, 0.4, 1)
		end
	end
end

function Palace.get_anchor(ctx, name)
	local palace = ctx.palace
	if not palace or not palace.active or palace.build < 0.35 then return nil end
	local anchor = palace.anchors[name]
	if not anchor then return nil end
	return {
		id = anchor.id,
		position = room_center(ctx) + anchor.local_pos,
		orientation = Vector(anchor.orientation.X, anchor.orientation.Y),
	}
end

function Palace.get_anchor_position(ctx, name)
	local a = Palace.get_anchor(ctx, name)
	return a and a.position or nil
end

function Palace.get_available_anchors(ctx, tag)
	local palace = ctx.palace
	local out = {}
	if not palace or not palace.active or palace.build < 0.35 then return out end
	for id, anchor in pairs(palace.anchors) do
		local ok = true
		if tag then
			ok = false
			for _, t in ipairs(anchor.tags) do
				if t == tag then ok = true; break end
			end
		end
		if ok then
			out[#out + 1] = {
				id = id,
				position = room_center(ctx) + anchor.local_pos,
				orientation = Vector(anchor.orientation.X, anchor.orientation.Y),
			}
		end
	end
	return out
end

function Palace.inspect(ctx)
	local palace = ctx.palace
	if not palace then
		return {active = false, build = 0, stability = 1, palette = "normal", piece_count = 0, visible_piece_count = 0, anchor_count = 0}
	end
	local visible = 0
	for _, piece in ipairs(palace.pieces) do
		if piece_build_t(palace, piece) > 0.05 and piece_collapse_t(palace, piece) < 0.99 then
			visible = visible + 1
		elseif piece.remnant and piece_build_t(palace, piece) > 0.05 then
			visible = visible + 1
		end
	end
	local anchors = 0
	for _ in pairs(palace.anchors) do anchors = anchors + 1 end
	return {
		active = palace.active,
		build = palace.build,
		stability = palace.stability,
		palette = palace.palette_mode,
		piece_count = #palace.pieces,
		visible_piece_count = visible,
		anchor_count = anchors,
	}
end

function Palace.cleanup(ctx)
	if not ctx.palace then return end
	for _, piece in ipairs(ctx.palace.pieces or {}) do
		piece.sprite = nil
	end
	ctx.palace = nil
end

return Palace
