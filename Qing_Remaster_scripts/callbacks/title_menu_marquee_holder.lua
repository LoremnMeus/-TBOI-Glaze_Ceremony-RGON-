-- 标题页滚动字标：A2Z 双层字库，先边框后字形。
local options = require("Qing_Remaster_scripts.callbacks.rgon_imgui_options_holder")
local A2ZFont = require("Qing_Remaster_scripts.others.a2z_font_renderer")

local item = {
	ToCall = {},
	text = "GLAZE CEREMONY PROMISED LAND   ",
}

local font = A2ZFont.new()

local defaults = {
	StartX = 320, EndX = 80, Y = 80, Speed = 28, FadeWidth = 48, LetterSpacing = 4,
	RainbowSpeed = 0.7, WaveSpeed = 0.26, EdgeIntensity = 0.45, EdgeWaveWidth = 0.75,
	BounceSpeed = 2.5, BounceTravelSpeed = 24, BounceHeight = 9,
	SquashX = 0.10, SquashY = 0.95, ImpactSharpness = 6,
	TangentRotation = 1,
}

local function setting(key)
	local value = options.get_value({"QingRemasterOptions", "Debug", "TitleMarquee"..key})
	return tonumber(value) or defaults[key]
end

local function clamp01(value)
	return math.max(0, math.min(1, value))
end

local function hsv(h, s, v, a)
	h = h - math.floor(h)
	local sector = math.floor(h * 6)
	local f = h * 6 - sector
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	sector = sector % 6
	if sector == 0 then return Color(v, t, p, a, 0, 0, 0) end
	if sector == 1 then return Color(q, v, p, a, 0, 0, 0) end
	if sector == 2 then return Color(p, v, t, a, 0, 0, 0) end
	if sector == 3 then return Color(p, q, v, a, 0, 0, 0) end
	if sector == 4 then return Color(t, p, v, a, 0, 0, 0) end
	return Color(v, p, q, a, 0, 0, 0)
end

local function hsv_rgb(h, s, v)
	h = h - math.floor(h)
	local sector = math.floor(h * 6)
	local f = h * 6 - sector
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	sector = sector % 6
	if sector == 0 then return v, t, p end
	if sector == 1 then return q, v, p end
	if sector == 2 then return p, v, t end
	if sector == 3 then return p, q, v end
	if sector == 4 then return t, p, v end
	return v, p, q
end

local function phrase_width(spacing)
	return font:measure(item.text, spacing)
end

local function menu_position(pos)
	return Isaac.WorldToMenuPosition(MainMenuType and MainMenuType.TITLE or 1, pos)
end

local function menu_scale()
	return math.max(0.01, (menu_position(Vector(1, 0)) - menu_position(Vector.Zero)):Length())
end

local function is_title_visible()
	if not REPENTOGON or not MenuManager or not MenuManager.GetActiveMenu then return false end
	local ok, active = pcall(MenuManager.GetActiveMenu)
	return ok and active == (MainMenuType and MainMenuType.TITLE or 1)
end

local function build_glyphs(time)
	local start_x, end_x = setting("StartX"), setting("EndX")
	if end_x > start_x then end_x, start_x = start_x, end_x end
	local y = setting("Y")
	local speed = math.max(0, setting("Speed"))
	local fade_width = math.max(1, setting("FadeWidth"))
	local spacing = math.max(0, setting("LetterSpacing"))
	local rainbow_speed = setting("RainbowSpeed")
	local wave_speed = setting("WaveSpeed")
	local bounce_speed = setting("BounceSpeed")
	local bounce_travel_speed = math.max(0.1, setting("BounceTravelSpeed"))
	local bounce_height = math.max(0, setting("BounceHeight"))
	local squash_x = math.max(0, setting("SquashX"))
	local squash_y = math.max(0, math.min(0.95, setting("SquashY")))
	local impact_sharpness = math.max(0.25, setting("ImpactSharpness"))
	local tangent_rotation = setting("TangentRotation")
	local width = phrase_width(spacing)
	local first = start_x - ((time * speed) % width)
	while first > end_x - width do first = first - width end
	local glyphs, copy_x = {}, first
	while copy_x <= start_x + width do
		local cursor = copy_x
		for i = 1, #item.text do
			local frame, advance, center = font:glyph_metrics(string.sub(item.text, i, i), spacing)
			if frame then
				local left, right = cursor, cursor + advance - 1
				if right >= end_x and left <= start_x then
					local alpha = math.min(
						clamp01((left - end_x) / fade_width),
						clamp01((start_x - left) / 10)
					)
					-- 直接以连续屏幕位置取相位；不得依赖每帧重建后会变化的 serial。
					local glyph_pitch = 14
					local spatial_phase = bounce_speed / (bounce_travel_speed * glyph_pitch)
					local phase = time * bounce_speed - (cursor - end_x) * spatial_phase
					local lift_wave = math.max(0, math.sin(phase))
					local slope = 0
					if math.sin(phase) > 0 then
						slope = 2 * math.sin(phase) * math.cos(phase) * bounce_height * spatial_phase
					end
					local rotation = math.atan(slope) * 180 / math.pi * tangent_rotation
					local impact = math.max(0, math.sin(phase + math.pi * 0.5)) ^ impact_sharpness
					glyphs[#glyphs + 1] = {
						frame = frame, x = cursor + center, y = y - lift_wave * lift_wave * bounce_height,
						alpha = alpha, sx = 1 + impact * squash_x, sy = 1 - impact * squash_y,
						rotation = rotation,
						hue = (time * rainbow_speed + (cursor - end_x) * 0.012) % 1,
						-- 波峰拥有独立的时间/空间频率，避免与彩虹 hue 永久锁相。
						wave_phase = (time * wave_speed + (cursor - end_x) * 0.019) % 1,
					}
				end
			end
			cursor = cursor + advance
		end
		copy_x = copy_x + width
	end
	return glyphs
end

local function render_glyphs(glyphs, scale)
	local function position(glyph)
		return menu_position(Vector(glyph.x, glyph.y))
	end
	local function edge_style(glyph)
			-- 边框像素为黑色，Tint 无法显色；用 Color Offset 让移动波扫过的一部分字母闪光。
			local wave = (math.sin(glyph.wave_phase * math.pi * 2) + 1) * 0.5
			local width = math.max(0.05, math.min(1, setting("EdgeWaveWidth")))
			-- width 表示一个周期内参与染色的比例；宽波峰让相邻字母连续过渡，而非单字闪烁。
			local flash = clamp01((wave - (1 - width)) / width) ^ 2
			-- Edge 与 Glyph 必须共用同一 hue；仅亮度门控不同，否则滚动时会看出相位错位。
			local r, g, b = hsv_rgb(glyph.hue, 0.72, 1)
			local intensity = math.max(0, setting("EdgeIntensity"))
		return Color(1, 1, 1, glyph.alpha, r * intensity * flash, g * intensity * flash, b * intensity * flash),
			Vector(glyph.sx * scale, glyph.sy * scale), glyph.rotation
	end
	local function glyph_style(glyph)
		return hsv(glyph.hue, 0.72, 1, glyph.alpha), Vector(glyph.sx * scale, glyph.sy * scale), glyph.rotation
	end
	font:render(glyphs, position, edge_style, glyph_style)
end

function item.render()
	if not is_title_visible() then return end
	local time = ((Isaac.GetTime and Isaac.GetTime()) or 0) / 1000
	local glyphs, scale = build_glyphs(time), menu_scale()
	render_glyphs(glyphs, scale)
end

table.insert(item.ToCall, {
	CallBack = ModCallbacks.MC_MAIN_MENU_RENDER,
	params = nil,
	Function = function(_) item.render() end,
})

return item
