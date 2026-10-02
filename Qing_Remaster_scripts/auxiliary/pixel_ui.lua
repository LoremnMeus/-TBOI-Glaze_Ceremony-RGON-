-- Pixel-font UI helpers for new surfaces (Quest Pause, etc.).
-- Do NOT assert inside gui.draw_ch — legacy callers may still use arbitrary scales.
-- New UI must call pixel_ui.draw_text / measure_text only.

local gui = require("Qing_Remaster_scripts.auxiliary.gui")

local pixel_ui = {
	SCHEMA_VERSION = 1,
	-- Global allow-list. 0.5 is the only fractional candidate; UI modules may
	-- further restrict (e.g. Quest Panel v1 allows only 1).
	ALLOWED_SCALES = {
		[0.5] = true,
		[1] = true,
		[2] = true,
		[3] = true,
		[4] = true,
	},
	_violations = {},
	_debug_show_scales = false,
}

local function normalize_scale_key(scale)
	local n = tonumber(scale)
	if not n then return nil end
	-- Exact table keys: 0.5 / 1 / 2 / 3 / 4
	if n == 0.5 or n == 1 or n == 2 or n == 3 or n == 4 then
		return n
	end
	return n
end

function pixel_ui.validate_scale(scale)
	local key = normalize_scale_key(scale)
	return key ~= nil and pixel_ui.ALLOWED_SCALES[key] == true
end

function pixel_ui.audit_scale(scale, context)
	if pixel_ui.validate_scale(scale) then
		return true
	end
	local msg = string.format(
		"%s: unsupported pixel-font scale %s",
		tostring(context or "PixelUI"),
		tostring(scale)
	)
	pixel_ui._violations[#pixel_ui._violations + 1] = {
		message = msg,
		scale = scale,
		context = context,
		frame = Game and Game():GetFrameCount() or 0,
	}
	-- Prefer loud failure in tests/dev; never silently round.
	error(msg, 2)
end

function pixel_ui.clear_violations()
	pixel_ui._violations = {}
end

function pixel_ui.get_violations()
	return pixel_ui._violations
end

function pixel_ui.snap(v)
	if not v then return Vector(0, 0) end
	return Vector(math.floor(v.X + 0.5), math.floor(v.Y + 0.5))
end

local function resolve_font(font)
	return font or gui.f
end

--- Real glyph advance via Font:GetStringWidthUTF8 * scale (same font as draw).
function pixel_ui.measure_text(text, scale, font)
	pixel_ui.audit_scale(scale, "pixel_ui.measure_text")
	text = text or ""
	font = resolve_font(font)
	if not font or not font.GetStringWidthUTF8 then
		return 0
	end
	local base = font:GetStringWidthUTF8(text) or 0
	return base * scale
end

function pixel_ui.draw_text(pos, text, scale, color, opts)
	opts = opts or {}
	pixel_ui.audit_scale(scale, opts.context or "pixel_ui.draw_text")
	text = text or ""
	if text == "" then return end
	color = color or KColor(1, 1, 1, 1)
	local font = resolve_font(opts.font)
	pos = pixel_ui.snap(pos)
	-- Screen-space draw (has_count_world = true means pos is already screen).
	font:DrawStringScaledUTF8(text, pos.X, pos.Y, scale, scale, color, 0, false)
end

function pixel_ui.draw_text_centered(center_x, y, text, scale, color, opts)
	opts = opts or {}
	local width = pixel_ui.measure_text(text, scale, opts.font)
	local x = center_x - width * 0.5
	pixel_ui.draw_text(Vector(x, y), text, scale, color, opts)
	return pixel_ui.measure_line_height(scale)
end

--- Right-align: `pos` is the right edge (top-right of the string box).
function pixel_ui.draw_text_right(pos, text, scale, color, opts)
	opts = opts or {}
	local width = pixel_ui.measure_text(text, scale, opts.font)
	local p = pos or Vector(0, 0)
	pixel_ui.draw_text(Vector(p.X - width, p.Y), text, scale, color, opts)
	return pixel_ui.measure_line_height(scale)
end

--- UTF-8 codepoint length in bytes (Isaac Lua has no utf8 lib).
local function utf8_char_len(byte)
	if not byte then return 1 end
	if byte < 0x80 then return 1 end
	if byte < 0xE0 then return 2 end
	if byte < 0xF0 then return 3 end
	return 4
end

--- Iterate UTF-8 glyphs left→right. Yields each glyph string.
function pixel_ui.iter_utf8_glyphs(text)
	text = text or ""
	local i = 1
	local n = #text
	return function()
		if i > n then return nil end
		local len = utf8_char_len(string.byte(text, i))
		local glyph = string.sub(text, i, i + len - 1)
		i = i + len
		return glyph
	end
end

--- Width of `text` with extra `spacing` px between glyphs (not via ASCII spaces).
function pixel_ui.measure_text_spaced(text, scale, spacing, font)
	pixel_ui.audit_scale(scale, "pixel_ui.measure_text_spaced")
	text = text or ""
	spacing = tonumber(spacing) or 0
	local total = 0
	local count = 0
	for glyph in pixel_ui.iter_utf8_glyphs(text) do
		if count > 0 then
			total = total + spacing
		end
		total = total + pixel_ui.measure_text(glyph, scale, font)
		count = count + 1
	end
	return total
end

function pixel_ui.draw_text_spaced(pos, text, scale, color, spacing, opts)
	opts = opts or {}
	pixel_ui.audit_scale(scale, opts.context or "pixel_ui.draw_text_spaced")
	text = text or ""
	if text == "" then return 0 end
	spacing = tonumber(spacing) or 0
	color = color or KColor(1, 1, 1, 1)
	local font = resolve_font(opts.font)
	pos = pixel_ui.snap(pos)
	local x = pos.X
	local y = pos.Y
	local first = true
	for glyph in pixel_ui.iter_utf8_glyphs(text) do
		if not first then
			x = x + spacing
		end
		first = false
		font:DrawStringScaledUTF8(glyph, x, y, scale, scale, color, 0, false)
		x = x + pixel_ui.measure_text(glyph, scale, font)
	end
	return x - pos.X
end

function pixel_ui.draw_text_spaced_centered(cx, y, text, scale, color, spacing, opts)
	opts = opts or {}
	local width = pixel_ui.measure_text_spaced(text, scale, spacing, opts.font)
	local x = (cx or 0) - width * 0.5
	pixel_ui.draw_text_spaced(Vector(x, y), text, scale, color, spacing, opts)
	return pixel_ui.measure_line_height(scale)
end

function pixel_ui.measure_line_height(scale)
	pixel_ui.audit_scale(scale, "pixel_ui.measure_line_height")
	-- eid9 / eidcn line height ≈ 12 at 1x; keep integer grid.
	return math.floor(12 * scale + 0.5)
end

--- Optional overlay for ImGui "Pixel Font Scale Test".
function pixel_ui.render_scale_test(origin)
	if not pixel_ui._debug_show_scales then return end
	origin = pixel_ui.snap(origin or Vector(40, 40))
	local samples = {0.5, 1, 2}
	local y = origin.Y
	for _, s in ipairs(samples) do
		if pixel_ui.validate_scale(s) then
			local label = string.format("%sx  中文测试 ABC 123", tostring(s))
			-- Use pcall so a UI that forbids 0.5 does not crash the test harness
			-- when the global allow-list still contains it.
			local ok, err = pcall(pixel_ui.draw_text, Vector(origin.X, y), label, s, KColor(1, 1, 1, 1), {
				context = "pixel_ui.scale_test",
			})
			if not ok then
				-- fall through
			end
			y = y + pixel_ui.measure_line_height(s) + 4
		end
	end
end

function pixel_ui.set_debug_scale_test(enabled)
	pixel_ui._debug_show_scales = enabled == true
end

function pixel_ui.get_debug_scale_test()
	return pixel_ui._debug_show_scales == true
end

return pixel_ui
