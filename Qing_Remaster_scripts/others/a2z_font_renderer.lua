-- A2Z 双层像素字体端口。集中维护字宽、锚点、测量、排版与 Edge->Glyph 绘制顺序。
local M = {
	ANM2 = "gfx/ui/math/A2Z.anm2",
	ANIMATION = "Idle",
	EDGE_LAYER = 0,
	GLYPH_LAYER = 1,
	-- 半开区间：[-7,7) 为14px；[-10,10) 为20px，中心线不额外计1px。
	GLYPH_TOP = -7,
	GLYPH_BOTTOM_EXCLUSIVE = 7,
	EDGE_TOP = -10,
	EDGE_BOTTOM_EXCLUSIVE = 10,
}

local WIDE = {A = true, I = true, J = true, M = true, T = true, W = true}

local Renderer = {}
Renderer.__index = Renderer

function M.new(path)
	local self = setmetatable({}, Renderer)
	self.sprite = Sprite()
	self.sprite:Load(path or M.ANM2, true)
	self.sprite:Play(M.ANIMATION, true)
	return self
end

function Renderer:glyph_metrics(char, spacing)
	spacing = math.max(0, tonumber(spacing) or 0)
	char = string.upper(char or "")
	if char == " " then return nil, 6 + spacing, 0 end
	if char == "-" then
		-- Others.png 第0格；左侧比普通字面额外1px。
		return 0, 11 + spacing, 6, {edge_layer = 2, glyph_layer = 3}
	end
	local digit = tonumber(char)
	if digit and #char == 1 then
		-- Num.png 横向1..9、0；0位于第10格。1宽11px，其余10px。
		local frame = digit == 0 and 9 or digit - 1
		return frame, (digit == 1 and 11 or 10) + spacing, 5,
			{edge_layer = 4, glyph_layer = 5}
	end
	local byte = string.byte(char)
	local index = byte and (byte - string.byte("A")) or -1
	if index < 0 or index > 25 then return nil, 6 + spacing, 0 end
	-- 半开区间：常规字面横向 [-5,5)（10px）；宽字左侧多1px，为11px且锚点右移1px。
	if WIDE[char] then return index, 11 + spacing, 6 end
	return index, 10 + spacing, 5
end

function Renderer:measure(text, spacing)
	local width = 0
	for i = 1, #(text or "") do
		local _, advance = self:glyph_metrics(string.sub(text, i, i), spacing)
		width = width + advance
	end
	return width
end

-- 返回以 x 为左边界的字形表；空格只推进 cursor，不产生绘制项。
function Renderer:layout(text, x, spacing)
	local glyphs, cursor = {}, tonumber(x) or 0
	for i = 1, #(text or "") do
		local char = string.sub(text, i, i)
		local frame, advance, center, source = self:glyph_metrics(char, spacing)
		if frame then
			glyphs[#glyphs + 1] = {
				char = char, frame = frame, left = cursor, x = cursor + center,
				advance = advance, source_index = i,
				edge_layer = source and source.edge_layer or M.EDGE_LAYER,
				glyph_layer = source and source.glyph_layer or M.GLYPH_LAYER,
			}
		end
		cursor = cursor + advance
	end
	return glyphs, cursor
end

function Renderer:render_layer(glyphs, logical_layer, position_fn, style_fn)
	for index, glyph in ipairs(glyphs or {}) do
		local layer = logical_layer == "edge" and (glyph.edge_layer or M.EDGE_LAYER)
			or (glyph.glyph_layer or M.GLYPH_LAYER)
		local color, scale, rotation = nil, nil, nil
		if style_fn then color, scale, rotation = style_fn(glyph, layer, index) end
		self.sprite:SetFrame(M.ANIMATION, glyph.frame)
		self.sprite.Color = color or Color(1, 1, 1, 1)
		self.sprite.Scale = scale or Vector(1, 1)
		self.sprite.Rotation = rotation or 0
		local pos = position_fn and position_fn(glyph, layer, index) or Vector(glyph.x, glyph.y or 0)
		self.sprite:RenderLayer(layer, pos, Vector.Zero, Vector.Zero)
	end
end

-- 必须整批 Edge 后整批 Glyph，避免后一字母的边框覆盖前一字面。
function Renderer:render(glyphs, position_fn, edge_style, glyph_style)
	self:render_layer(glyphs, "edge", position_fn, edge_style)
	self:render_layer(glyphs, "glyph", position_fn, glyph_style)
end

M.Renderer = Renderer
M.WIDE_GLYPHS = WIDE

return M
