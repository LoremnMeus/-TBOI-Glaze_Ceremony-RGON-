-- Quest Log v2 visual primitives (code placeholders).
-- Layout / node semantics live in quest_panel.lua.
-- Future sprites only replace ornament / marker renderers via STYLE flags.
--
-- Art rules (placeholders):
-- 1. Default stroke width = 1px.
-- 2. All coordinates integer-snapped.
-- 3. No antialiased math circles — use pixel octagons.
-- 4. No large translucent backgrounds.
-- 5. Ornaments = horizontal lines, diamonds, short ticks only.
-- 6. Markers = 9×9 pixel octagons; completion uses shape, not color alone.
-- 7. Connector lines only link steps inside one continuous task chain.
-- 8. Ornament brightness stays below body text.

local pixel_ui = require("Qing_Remaster_scripts.auxiliary.pixel_ui")

local draw = {
	STYLE = {
		use_sprite_ornament = false,
		use_sprite_marker = false,
		-- Paper background: "parts" | "debug" | "legacy"
		-- Default: 1:1 Top/Middle/Bottom from questpage.png (never stretch).
		paper = "parts",
	},
	COLORS = {
		ornament = KColor(0.78, 0.69, 0.47, 0.95),
		ornament_dim = KColor(0.42, 0.39, 0.33, 0.70),
		title = KColor(1.0, 0.95, 0.76, 1.0),
		chapter = KColor(0.75, 0.82, 1.0, 0.95),
		text = KColor(0.90, 0.91, 0.94, 0.95),
		secondary = KColor(0.67, 0.69, 0.75, 0.85),
		note = KColor(0.62, 0.64, 0.70, 0.80),
		completed = KColor(0.67, 0.90, 0.70, 0.95),
		current = KColor(1.0, 0.91, 0.54, 1.0),
		pending = KColor(0.72, 0.73, 0.78, 0.90),
		unknown = KColor(0.48, 0.49, 0.54, 0.75),
		connector = KColor(0.36, 0.37, 0.41, 0.58),
		footer = KColor(0.55, 0.56, 0.60, 0.70),
		section = KColor(0.62, 0.64, 0.70, 0.85),
	},
	MARKER_R = 4, -- 9×9 footprint
	STEP_ROW_H = 16,
}

local function P(x)
	return math.floor((x or 0) + 0.5)
end

local function V(x, y)
	return Vector(P(x), P(y))
end

function draw.P(x)
	return P(x)
end

function draw.V(x, y)
	return V(x, y)
end

local function line(a, b, col, width)
	if not Isaac.DrawLine then return end
	col = col or draw.COLORS.ornament
	Isaac.DrawLine(a, b, col, col, width or 1)
end

function draw.line(a, b, col, width)
	line(a, b, col, width)
end

--- Filled diamond via scanlines (radius 2–3 is fine).
local function fill_diamond(cx, cy, radius, col)
	local r = math.max(1, P(radius))
	for dy = -r, r do
		local half = r - math.abs(dy)
		line(V(cx - half, cy + dy), V(cx + half, cy + dy), col, 1)
	end
end

local function outline_diamond(cx, cy, radius, col)
	local r = math.max(1, P(radius))
	local top = V(cx, cy - r)
	local right = V(cx + r, cy)
	local bottom = V(cx, cy + r)
	local left = V(cx - r, cy)
	line(top, right, col, 1)
	line(right, bottom, col, 1)
	line(bottom, left, col, 1)
	line(left, top, col, 1)
end

function draw.diamond(cx, cy, radius, col, filled)
	if filled then
		fill_diamond(cx, cy, radius, col or draw.COLORS.ornament)
	else
		outline_diamond(cx, cy, radius, col or draw.COLORS.ornament)
	end
end

local function touch(ctx, x1, y1, x2, y2)
	if not ctx then return end
	x1, y1, x2, y2 = P(x1), P(y1), P(x2), P(y2)
	if x2 < x1 then x1, x2 = x2, x1 end
	if y2 < y1 then y1, y2 = y2, y1 end
	ctx.min_x = math.min(ctx.min_x or x1, x1)
	ctx.min_y = math.min(ctx.min_y or y1, y1)
	ctx.max_x = math.max(ctx.max_x or x2, x2)
	ctx.max_y = math.max(ctx.max_y or y2, y2)
end

function draw.touch_bounds(ctx, x1, y1, x2, y2)
	touch(ctx, x1, y1, x2, y2)
end

function draw.touch_text(ctx, x, y, text, scale)
	scale = scale or 1
	local w = pixel_ui.measure_text(text or "", scale)
	local h = pixel_ui.measure_line_height(scale)
	touch(ctx, x, y, x + w, y + h)
end

--- ────◇◆◇────  任 务  ────◇◆◇────
local function draw_header_placeholder(ctx, title)
	local y = ctx.y
	local cx = ctx.cx
	local outer = math.floor(ctx.width / 2)
	local inner = 34
	local col_main = draw.COLORS.ornament
	local col_dim = draw.COLORS.ornament_dim

	-- Outer arms
	line(V(cx - outer, y), V(cx - inner - 14, y), col_dim, 1)
	line(V(cx + inner + 14, y), V(cx + outer, y), col_dim, 1)

	-- Left cluster: small outline, big filled, small outline
	outline_diamond(cx - inner - 8, y, 2, col_main)
	fill_diamond(cx - inner - 2, y, 3, col_main)
	outline_diamond(cx - inner + 4, y, 2, col_main)

	-- Right cluster (mirror)
	outline_diamond(cx + inner - 4, y, 2, col_main)
	fill_diamond(cx + inner + 2, y, 3, col_main)
	outline_diamond(cx + inner + 8, y, 2, col_main)

	pixel_ui.draw_text_centered(
		cx, y - 5, title or "", 1, draw.COLORS.title,
		{context = "QuestPanel.header"}
	)
	draw.touch_text(ctx, cx - 20, y - 5, title or "", 1)
	touch(ctx, cx - outer, y - 4, cx + outer, y + 4)

	ctx.y = y + 16
end

function draw.header(ctx, title)
	if draw.STYLE.use_sprite_ornament then
		return draw_header_placeholder(ctx, title)
	end
	return draw_header_placeholder(ctx, title)
end

--- Medium toast ornament: ──◇◆◇──  (no title text; caller draws body below)
--- Returns the Y used (center of ornament) for layout.
function draw.ornament_medium(cx, y, opts)
	opts = opts or {}
	cx, y = P(cx), P(y)
	local half = opts.half_width or 28
	local col = opts.color or draw.COLORS.ornament
	local dim = opts.dim or draw.COLORS.ornament_dim
	line(V(cx - half, y), V(cx - 10, y), dim, 1)
	line(V(cx + 10, y), V(cx + half, y), dim, 1)
	outline_diamond(cx - 6, y, 2, col)
	fill_diamond(cx, y, 3, col)
	outline_diamond(cx + 6, y, 2, col)
	if opts.ctx then
		touch(opts.ctx, cx - half, y - 4, cx + half, y + 4)
	end
	return y
end

--- Small Pause entry prompt (two centered rows):
---   ◇ Q ◇
---    任务
--- Ornament centerline is derived from font line height (not hard-coded y+4).
function draw.quest_entry_prompt(pos, key, label, opts)
	opts = opts or {}
	pos = pos or Vector(0, 0)
	local cx = P(pos.X)
	local key_y = P(pos.Y) + P(opts.key_y_offset or 0)
	local col = opts.color or draw.COLORS.ornament
	local text_col = opts.text_color or draw.COLORS.title
	if opts.alpha then
		local a = opts.alpha
		col = KColor(0.78, 0.69, 0.47, a)
		text_col = KColor(1.0, 0.95, 0.76, a)
	end

	local key_str = tostring(key or "Q")
	local scale = 1
	local line_h = pixel_ui.measure_line_height(scale)
	local key_w = pixel_ui.measure_text(key_str, scale)
	local diamond_r = 2
	local diamond_w = diamond_r * 2 + 1
	local gap = 4
	local total_w = diamond_w + gap + key_w + gap + diamond_w
	local left = cx - math.floor(total_w / 2)

	-- Visual center of the key glyph row (font baseline → mid of line box).
	local key_center_y = key_y + math.floor(line_h / 2) + P(opts.ornament_y_offset or 0)
	local key_glyph_y = key_y + P(opts.key_glyph_y_offset or -3)

	outline_diamond(left + diamond_r, key_center_y, diamond_r, col)
	pixel_ui.draw_text(
		V(left + diamond_w + gap, key_glyph_y), key_str, scale, text_col,
		{context = opts.context or "Quest.entry_prompt"}
	)
	outline_diamond(
		left + diamond_w + gap + key_w + gap + diamond_r,
		key_center_y, diamond_r, col
	)

	local row_gap = opts.row_gap
	if row_gap == nil then row_gap = 10 end
	local label_y = key_y + P(row_gap) + P(opts.label_y_offset or 0)
	if label and label ~= "" then
		pixel_ui.draw_text_centered(
			cx, label_y, label, scale, text_col,
			{context = opts.context or "Quest.entry_prompt"}
		)
	end

	if opts.debug_guides and Isaac.DrawLine then
		local guide = KColor(0.3, 0.9, 1.0, 0.7)
		line(V(cx, key_y - 2), V(cx, label_y + line_h), guide, 1)
		line(V(left - 2, key_center_y), V(left + total_w + 2, key_center_y), guide, 1)
	end

	if opts.ctx then
		local lw = pixel_ui.measure_text(label or "", scale)
		touch(opts.ctx, cx - math.max(total_w, lw) * 0.5, key_y, cx + math.max(total_w, lw) * 0.5, label_y + line_h)
	end
end

--- Compatibility alias → two-line entry prompt.
function draw.key_prompt(pos, key, label, opts)
	return draw.quest_entry_prompt(pos, key, label, opts)
end

--- Toast header + optional kind tint. Body lines drawn by caller or via draw.toast_card.
function draw.toast_header(cx, y, kind, opts)
	opts = opts or {}
	local a = opts.alpha
	if a == nil then a = 1 end
	local col = draw.COLORS.ornament
	if kind == "complete" then
		col = draw.COLORS.completed
	elseif kind == "side" or kind == "discover" then
		col = draw.COLORS.chapter
	elseif kind == "progress" or kind == "update" then
		col = KColor(0.92, 0.84, 0.55, 0.95)
	else
		col = draw.COLORS.current
	end
	if a < 0.999 then
		col = KColor(col.Red, col.Green, col.Blue, (col.Alpha or 1) * a)
	end
	local dim = draw.COLORS.ornament_dim
	if a < 0.999 then
		dim = KColor(dim.Red, dim.Green, dim.Blue, (dim.Alpha or 1) * a)
	end
	draw.ornament_medium(cx, y, {
		color = col,
		dim = dim,
		half_width = opts.half_width or 26,
		ctx = opts.ctx,
	})
	return y + 10
end

--- ────◇  section  ◇────
local function draw_section_placeholder(ctx, title)
	local y = ctx.y
	local cx = ctx.cx
	local half = math.floor(ctx.width / 2) - 4
	local col = draw.COLORS.section
	local dim = draw.COLORS.ornament_dim
	local tw = pixel_ui.measure_text(title or "", 1)
	local gap = math.floor(tw * 0.5) + 10

	line(V(cx - half, y), V(cx - gap - 6, y), dim, 1)
	line(V(cx + gap + 6, y), V(cx + half, y), dim, 1)
	outline_diamond(cx - gap - 2, y, 2, col)
	outline_diamond(cx + gap + 2, y, 2, col)

	pixel_ui.draw_text_centered(
		cx, y - 5, title or "", 1, col,
		{context = "QuestPanel.section"}
	)
	draw.touch_text(ctx, cx - gap, y - 5, title or "", 1)
	touch(ctx, cx - half, y - 3, cx + half, y + 3)
	ctx.y = y + 14
end

function draw.section_title(ctx, title)
	if draw.STYLE.use_sprite_ornament then
		return draw_section_placeholder(ctx, title)
	end
	return draw_section_placeholder(ctx, title)
end

--- Pixel octagon outline (9×9 footprint, r≈4).
local function draw_marker_outline(cx, cy, col)
	-- top / bottom flats
	line(V(cx - 2, cy - 4), V(cx + 2, cy - 4), col, 1)
	line(V(cx - 2, cy + 4), V(cx + 2, cy + 4), col, 1)
	-- left / right flats
	line(V(cx - 4, cy - 2), V(cx - 4, cy + 2), col, 1)
	line(V(cx + 4, cy - 2), V(cx + 4, cy + 2), col, 1)
	-- bevels
	line(V(cx - 2, cy - 4), V(cx - 4, cy - 2), col, 1)
	line(V(cx + 2, cy - 4), V(cx + 4, cy - 2), col, 1)
	line(V(cx - 4, cy + 2), V(cx - 2, cy + 4), col, 1)
	line(V(cx + 4, cy + 2), V(cx + 2, cy + 4), col, 1)
end

--- Staircase check inside marker.
local function draw_check(cx, cy, col)
	-- left leg
	line(V(cx - 2, cy), V(cx - 1, cy + 1), col, 1)
	line(V(cx - 1, cy + 1), V(cx, cy + 2), col, 1)
	-- right leg
	line(V(cx, cy + 2), V(cx + 1, cy + 1), col, 1)
	line(V(cx + 1, cy + 1), V(cx + 2, cy), col, 1)
	line(V(cx + 2, cy), V(cx + 3, cy - 1), col, 1)
end

--- Public: small staircase check (toast / panel reuse).
function draw.check_mark(cx, cy, col)
	cx, cy = P(cx), P(cy)
	draw_check(cx, cy, col or draw.COLORS.completed)
end

--- Title with ✓ prefix. Returns next Y (below the line).
function draw.completed_title(pos, text, opts)
	opts = opts or {}
	pos = pos or Vector(0, 0)
	local scale = opts.scale or 1
	local col = opts.color or draw.COLORS.completed
	local x, y = P(pos.X), P(pos.Y)
	local line_h = pixel_ui.measure_line_height(scale)
	draw.check_mark(x + 3, y + math.floor(line_h * 0.45), col)
	pixel_ui.draw_text(
		V(x + 10, y), text or "", scale, col,
		{context = opts.context or "Quest.completed_title"}
	)
	return y + (opts.row_h or line_h)
end

--- Objective text with 1px mid-line strikethrough (not Unicode combining marks).
function draw.completed_text(pos, text, opts)
	opts = opts or {}
	pos = pos or Vector(0, 0)
	local scale = opts.scale or 1
	local col = opts.color or draw.COLORS.secondary
	local x, y = P(pos.X), P(pos.Y)
	local str = text or ""
	pixel_ui.draw_text(V(x, y), str, scale, col, {
		context = opts.context or "Quest.completed_text",
	})
	local w = pixel_ui.measure_text(str, scale)
	local line_h = pixel_ui.measure_line_height(scale)
	local mid = y + math.floor(line_h * 0.45)
	local strike = opts.strike_color or KColor(
		col.Red or 0.67, col.Green or 0.69, col.Blue or 0.75,
		(col.Alpha or 0.85) * 0.95
	)
	line(V(x, mid), V(x + math.max(1, w), mid), strike, 1)
	return y + (opts.row_h or line_h)
end

--- state: "completed" | "known" | "unknown" | "progress" | "current"
local function draw_marker_placeholder(cx, cy, state, number, ctx)
	cx, cy = P(cx), P(cy)
	local col = draw.COLORS.pending
	if state == "completed" then
		col = draw.COLORS.completed
	elseif state == "unknown" then
		col = draw.COLORS.unknown
	elseif state == "current" or state == "progress" then
		col = draw.COLORS.current
	end

	draw_marker_outline(cx, cy, col)
	touch(ctx, cx - 5, cy - 5, cx + 5, cy + 5)

	if state == "completed" then
		draw_check(cx, cy, col)
	elseif state == "unknown" then
		pixel_ui.draw_text_centered(
			cx, cy - 5, "?", 1, col,
			{context = "QuestPanel.marker"}
		)
	elseif state == "progress" or state == "current" then
		-- Inner 2×2 block
		line(V(cx - 1, cy - 1), V(cx + 1, cy - 1), col, 1)
		line(V(cx - 1, cy), V(cx + 1, cy), col, 1)
		line(V(cx - 1, cy + 1), V(cx + 1, cy + 1), col, 1)
	elseif number ~= nil then
		pixel_ui.draw_text_centered(
			cx, cy - 5, tostring(number), 1, col,
			{context = "QuestPanel.marker"}
		)
	end
end

function draw.marker(cx, cy, state, number, ctx)
	if draw.STYLE.use_sprite_marker then
		-- Future: draw_marker_sprite(...)
		return draw_marker_placeholder(cx, cy, state, number, ctx)
	end
	return draw_marker_placeholder(cx, cy, state, number, ctx)
end

function draw.connector(x, y1, y2, ctx)
	local col = draw.COLORS.connector
	line(V(x, y1), V(x, y2), col, 1)
	touch(ctx, x, y1, x, y2)
end

function draw.material_text_color(state)
	if state == "completed" then return draw.COLORS.completed end
	if state == "unknown" then return draw.COLORS.unknown end
	if state == "current" or state == "progress" then return draw.COLORS.current end
	return draw.COLORS.pending
end

-- ---- Quest paper background (1:1 Top + N×Middle + Bottom; never stretch) ----

local PAPER_PARTS_ANM2 = "gfx/ui/quest/questpage_parts.anm2"
local PAPER_LEGACY_ANM2 = "gfx/ui/quest/quest_panel.anm2"
local PAGE_W = 256
local PAGE_TOP_H = 168
local PAGE_MID_H = 32
local PAGE_BOT_H = 88

local _parts = {
	top = nil,
	mid = nil,
	bot = nil,
	ok = nil,
}
local _legacy_spr = nil
local _legacy_ok = nil

local function ensure_part(slot, anim)
	if _parts.ok == false then return nil end
	if _parts[slot] then return _parts[slot] end
	local ok, spr = pcall(function()
		local s = Sprite()
		s:Load(PAPER_PARTS_ANM2, true)
		s:Play(anim, true)
		s:SetFrame(anim, 0)
		return s
	end)
	if ok and spr then
		_parts[slot] = spr
		_parts.ok = true
		return spr
	end
	_parts.ok = false
	return nil
end

local function ensure_legacy_sprite()
	if _legacy_ok == false then return nil end
	if _legacy_spr then return _legacy_spr end
	local ok, spr = pcall(function()
		local s = Sprite()
		s:Load(PAPER_LEGACY_ANM2, true)
		s:Play("Idle", true)
		return s
	end)
	if ok and spr then
		_legacy_spr = spr
		_legacy_ok = true
		return spr
	end
	_legacy_ok = false
	return nil
end

local function fill_rect_scan(L, T, R, B, col)
	if not Isaac.DrawLine then return end
	L, T, R, B = P(L), P(T), P(R), P(B)
	if R <= L or B <= T then return end
	for y = T, B do
		line(V(L, y), V(R, y), col, 1)
	end
end

local function paper_debug(rect, alpha)
	local L, T, R, B = rect.left, rect.top, rect.right, rect.bottom
	local fill = KColor(0.82, 0.76, 0.62, 0.92 * alpha)
	local edge = KColor(0.55, 0.48, 0.36, 0.95 * alpha)
	local accent = KColor(0.78, 0.69, 0.47, 0.9 * alpha)
	fill_rect_scan(L, T, R, B, fill)
	line(V(L, T), V(R, T), edge, 1)
	line(V(R, T), V(R, B), edge, 1)
	line(V(R, B), V(L, B), edge, 1)
	line(V(L, B), V(L, T), edge, 1)
	outline_diamond(L + 4, T + 4, 2, accent)
	outline_diamond(R - 4, T + 4, 2, accent)
	outline_diamond(L + 4, B - 4, 2, accent)
	outline_diamond(R - 4, B - 4, 2, accent)
end

--- Stretch legacy 48×48 (opt-in only; misleads size tuning).
local function paper_legacy_stretch(rect, alpha)
	local spr = ensure_legacy_sprite()
	if not spr then
		paper_debug(rect, alpha)
		return
	end
	local L, T, R, B = P(rect.left), P(rect.top), P(rect.right), P(rect.bottom)
	local w = math.max(1, R - L)
	local h = math.max(1, B - T)
	local sx = w / 48
	local sy = h / 48
	pcall(function()
		spr.Color = Color(1, 1, 1, alpha, 0, 0, 0)
		spr.Scale = Vector(sx, sy)
		spr:SetFrame("Idle", 0)
		spr:Render(Vector(L, T), Vector(0, 0), Vector(0, 0))
		spr.Scale = Vector(1, 1)
	end)
end

--- Render one part at top-left with optional horizontal reveal clip (from right).
local function render_part(spr, x, y, part_w, part_h, full_left, vis_left, alpha)
	if not spr then return end
	x, y = P(x), P(y)
	local right = x + part_w
	if right <= vis_left then return end
	local clip_l = 0
	if x < vis_left then
		clip_l = math.floor(vis_left - x + 0.5)
		if clip_l >= part_w then return end
	end
	pcall(function()
		spr.Color = Color(1, 1, 1, alpha, 0, 0, 0)
		spr.Scale = Vector(1, 1)
		spr:Render(Vector(x, y), Vector(clip_l, 0), Vector(0, 0))
	end)
end

--- 1:1 Top + N×Middle + Bottom. NEVER scales. Height must be 256+32*N.
local function paper_parts_assemble(rect, alpha)
	local full_left = rect.full_left or rect.left
	local full_top = rect.full_top or rect.top
	local full_right = rect.full_right or rect.right
	local height = rect.height or ((rect.full_bottom or rect.bottom) - full_top)
	local n = rect.middle_count
	if n == nil then
		local extra = math.max(0, height - (PAGE_TOP_H + PAGE_BOT_H))
		n = math.floor((extra / PAGE_MID_H) + 0.5)
	end
	n = math.max(0, math.floor(n + 0.5))
	local vis_left = rect.left or full_left
	local top = ensure_part("top", "Top")
	local mid = ensure_part("mid", "Middle")
	local bot = ensure_part("bot", "Bottom")
	if not top or not mid or not bot then
		paper_debug({
			left = full_left, top = full_top,
			right = full_right, bottom = full_top + PAGE_TOP_H + n * PAGE_MID_H + PAGE_BOT_H,
		}, alpha)
		return
	end
	-- Ensure correct anim each draw (shared sprites can be reused).
	pcall(function() top:SetFrame("Top", 0) end)
	pcall(function() mid:SetFrame("Middle", 0) end)
	pcall(function() bot:SetFrame("Bottom", 0) end)

	render_part(top, full_left, full_top, PAGE_W, PAGE_TOP_H, full_left, vis_left, alpha)
	local y = full_top + PAGE_TOP_H
	for _ = 1, n do
		render_part(mid, full_left, y, PAGE_W, PAGE_MID_H, full_left, vis_left, alpha)
		y = y + PAGE_MID_H
	end
	render_part(bot, full_left, y, PAGE_W, PAGE_BOT_H, full_left, vis_left, alpha)
end

--- Draw quest paper behind content. Must cover Seed when open.
--- rect = {left,top,right,bottom, full_*, middle_count}; opts.reveal/alpha/style.
function draw.paper_panel(rect, opts)
	opts = opts or {}
	if not rect then return end
	local reveal = opts.reveal
	if reveal == nil then reveal = 1 end
	reveal = tonumber(reveal) or 1
	if reveal <= 0.01 then return end
	local alpha = opts.alpha
	if alpha == nil then alpha = reveal end
	alpha = tonumber(alpha) or reveal
	if alpha <= 0.01 then return end

	local style = opts.style or draw.STYLE.paper or "parts"
	local r = {
		left = P(rect.left),
		top = P(rect.top),
		right = P(rect.right),
		bottom = P(rect.bottom),
		full_left = P(rect.full_left or rect.left),
		full_top = P(rect.full_top or rect.top),
		full_right = P(rect.full_right or rect.right),
		full_bottom = P(rect.full_bottom or rect.bottom),
		height = rect.height,
		middle_count = rect.middle_count,
	}
	if r.full_right <= r.full_left or r.bottom <= r.top then return end

	if style == "debug" then
		paper_debug({
			left = r.full_left, top = r.full_top,
			right = r.full_right, bottom = r.full_bottom or r.bottom,
		}, alpha)
	elseif style == "legacy" then
		paper_legacy_stretch({
			left = r.full_left, top = r.full_top,
			right = r.full_right, bottom = r.full_bottom or r.bottom,
		}, alpha)
	else
		-- Default: parts (sprite alias)
		paper_parts_assemble(r, alpha)
	end
end

function draw.set_paper_style(style)
	if style == "legacy" or style == "debug" or style == "parts" or style == "sprite" then
		if style == "sprite" then style = "parts" end
		draw.STYLE.paper = style
	end
end

function draw.get_paper_style()
	return draw.STYLE.paper or "parts"
end

-- ---- Page toggle tab (Openpage.png EN 64×64 / ZH 128×128; center pivots; no text) ----

local TOGGLE_ANM2 = "gfx/ui/quest/openpage_parts.anm2"
local _toggle_spr = nil
local _toggle_ok = nil
-- Debug-only language override: "auto" | "zh" | "en" (never writes Options.Language).
local _toggle_lang_override = "auto"
local _toggle_last_info = {
	lang = "zh",
	anim = "Open_ZH",
	width = 128,
	height = 128,
	kind = "open",
}

local function ensure_toggle_sprite()
	if _toggle_ok == false then return nil end
	if _toggle_spr then return _toggle_spr end
	local ok, spr = pcall(function()
		local s = Sprite()
		s:Load(TOGGLE_ANM2, true)
		s:SetFrame("Open_EN", 0)
		return s
	end)
	if ok and spr then
		_toggle_spr = spr
		_toggle_ok = true
		return spr
	end
	_toggle_ok = false
	return nil
end

local function game_toggle_lang()
	local ok, registry = pcall(require, "Qing_Remaster_scripts.quest.quest_registry")
	if ok and registry and registry.lang then
		return registry.lang() == "en" and "en" or "zh"
	end
	if Options and Options.Language == "en" then
		return "en"
	end
	return "zh"
end

function draw.set_toggle_language_override(mode)
	if mode == "zh" or mode == "en" or mode == "auto" then
		_toggle_lang_override = mode
	end
end

function draw.get_toggle_language_override()
	return _toggle_lang_override or "auto"
end

function draw.effective_toggle_language()
	local override = _toggle_lang_override or "auto"
	if override == "zh" or override == "en" then
		return override
	end
	return game_toggle_lang()
end

--- kind = "open" | "close"; returns animation name + crop size.
function draw.get_toggle_animation(kind, lang)
	kind = (kind == "close") and "close" or "open"
	lang = lang or draw.effective_toggle_language()
	if lang == "en" then
		return (kind == "close") and "Close_EN" or "Open_EN", 64, 64
	end
	return (kind == "close") and "Close_ZH" or "Open_ZH", 128, 128
end

function draw.get_toggle_last_info()
	return {
		lang = _toggle_last_info.lang,
		anim = _toggle_last_info.anim,
		width = _toggle_last_info.width,
		height = _toggle_last_info.height,
		kind = _toggle_last_info.kind,
	}
end

--- Draw page-toggle tab. pos = CENTER anchor (ANM2 pivots are crop centers).
--- opts.kind = "open"|"close"; opts.lang optional override for this draw only.
function draw.page_toggle(pos, kind, opts)
	opts = opts or {}
	if not pos then return end
	local alpha = opts.alpha
	if alpha == nil then alpha = 1 end
	alpha = tonumber(alpha) or 1
	if alpha <= 0.01 then return end
	kind = (kind == "close") and "close" or "open"
	local lang = opts.lang or draw.effective_toggle_language()
	local anim, w, h = draw.get_toggle_animation(kind, lang)
	_toggle_last_info.lang = lang
	_toggle_last_info.anim = anim
	_toggle_last_info.width = w
	_toggle_last_info.height = h
	_toggle_last_info.kind = kind

	local spr = ensure_toggle_sprite()
	local x, y = P(pos.X), P(pos.Y)
	if not spr then
		local col = KColor(0.92, 0.84, 0.55, 0.9 * alpha)
		outline_diamond(x, y, math.floor(w * 0.2), col)
		return
	end
	pcall(function()
		spr.Color = Color(1, 1, 1, alpha, 0, 0, 0)
		spr.Scale = Vector(1, 1)
		if spr:GetAnimation() ~= anim then
			spr:SetFrame(anim, 0)
		end
		spr:Render(Vector(x, y), Vector(0, 0), Vector(0, 0))
	end)
end

--- Half-size of current effective toggle (for debug / legacy TL conversion).
function draw.page_toggle_size()
	local _, w, h = draw.get_toggle_animation("open")
	return w, h
end

return draw
