-- Lightweight chapter title reveal (black veil + two lines). Not a cutscene.
-- Owns its own fonts (not Quest HUD / pixel_ui default gui.f).
-- after_delay: quiet game frames after the veil fades, before on_complete (Quest toast).

local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local pixel_ui = require("Qing_Remaster_scripts.auxiliary.pixel_ui")

local transition = {
	ToCall = {},
	myToCall = {},
	own_key = "Chapter_Transition_",
	_active = nil,
	_fonts = {},
}

-- Game-frame phases (MC_POST_UPDATE = 30 Hz).
-- Source BMFont is ~36px; prefer 0.5/1 scales (not 2/3 as if it were 9px UI font).
local DEFAULTS = {
	black = 6,
	hold = 40,
	fade = 18,
	after_delay = 18,
	chapter_scale = 1,
	title_scale = 0.75,
	chapter_y_frac = 0.40,
	title_y_frac = 0.50,
	letter_spacing = 2,
	font_id = "yozai_medium",
}

transition.config = {
	black = DEFAULTS.black,
	hold = DEFAULTS.hold,
	fade = DEFAULTS.fade,
	after_delay = DEFAULTS.after_delay,
	chapter_scale = DEFAULTS.chapter_scale,
	title_scale = DEFAULTS.title_scale,
	chapter_y_frac = DEFAULTS.chapter_y_frac,
	title_y_frac = DEFAULTS.title_y_frac,
	letter_spacing = DEFAULTS.letter_spacing,
	font_id = DEFAULTS.font_id,
}

-- Chapter BMFont (~36px) is independent of pixel_ui HUD scale allowlist.
transition.SCALE_CHOICES = {0.5, 0.75, 1, 1.5, 2}
transition.SCALE_MIN = 0.25
transition.SCALE_MAX = 2

transition.FONT_IDS = {
	"runtime_cjk",
	"yozai_medium",
	"yozai_medium_hard",
	"xiaolai",
	"cef_cjk",
}

transition.FONT_LABELS = {
	runtime_cjk = {zh = "Runtime CJK (gui.f2)", en = "Runtime CJK (gui.f2)"},
	yozai_medium = {zh = "Yozai Medium (soft)", en = "Yozai Medium (soft)"},
	yozai_medium_hard = {zh = "Yozai Medium (hard 128)", en = "Yozai Medium (hard 128)"},
	xiaolai = {zh = "Xiaolai", en = "Xiaolai"},
	cef_cjk = {zh = "CEF CJK", en = "CEF CJK"},
}

local FONT_PATHS = {
	yozai_medium = "font/chapter_title/yozai_medium.fnt",
	yozai_medium_hard = "font/chapter_title/yozai_medium_hard.fnt",
	xiaolai = "font/chapter_title/xiaolai.fnt",
	cef_cjk = "font/chapter_title/cef_cjk.fnt",
}

local SAMPLE_GLYPHS = "序章·狩猎"
local SAMPLE_ASCII = "ABCDE 12345"

transition._glyph_test = false
transition._fonts = transition._fonts or {}
transition._font_reports = transition._font_reports or {}
transition._font_paths_loaded = {}

local black_spr = nil
local function ensure_black()
	if black_spr then return black_spr end
	local ok, spr = pcall(function()
		local s = Sprite()
		s:Load("gfx/Black.anm2", true)
		s:Play("Idle", true)
		return s
	end)
	if ok and spr then
		black_spr = spr
		return black_spr
	end
	return nil
end

function transition.clear_font_cache()
	transition._fonts = {}
	transition._font_reports = {}
	transition._font_paths_loaded = {}
end

--- Chapter BMFonts load through gui.load_mod_font (live mod root), never bare Font:Load("font/...").
function transition.resolve_font(font_id)
	font_id = font_id or transition.config.font_id or "yozai_medium"
	if font_id == "runtime_cjk" then
		return gui.f2 or gui.f, "runtime_cjk", true
	end
	local cached = transition._fonts[font_id]
	if cached ~= nil then
		local loaded = cached:IsLoaded() == true
		if loaded then
			return cached, font_id, true
		end
		-- Stale success cache that unloaded — drop and retry.
		transition._fonts[font_id] = nil
	end
	local path = FONT_PATHS[font_id]
	local font, report = nil, nil
	if path and gui.load_mod_font then
		font, report = gui.load_mod_font(path)
	end
	transition._font_reports[font_id] = report
	transition._font_paths_loaded[font_id] = (report and report.resolved) or path
	-- Cache successes only; failed loads must retry (Debug / late mod path).
	if font then
		transition._fonts[font_id] = font
		return font, font_id, true
	end
	return gui.f2 or gui.f, font_id, false
end

local function measure_sample(font, text)
	if not font or not font.GetStringWidthUTF8 then return nil end
	local ok, w = pcall(function()
		return font:GetStringWidthUTF8(text)
	end)
	if ok then return w end
	return nil
end

local function font_line_height(font)
	if not font or not font.GetLineHeight then return nil end
	local ok, h = pcall(function() return font:GetLineHeight() end)
	if ok then return h end
	return nil
end

local function glyph_widths(font)
	local widths = {}
	for _, ch in ipairs({"序", "章", "狩", "猎", "·"}) do
		widths[#widths + 1] = {
			ch = ch,
			width = measure_sample(font, ch),
		}
	end
	return widths
end

--- Runtime font probe for Debug / ImGui. Distinguishes requested vs effective (fallback) font.
function transition.get_font_status(font_id)
	font_id = font_id or transition.config.font_id or "yozai_medium"
	local effective, id, loaded = transition.resolve_font(font_id)
	local report = transition._font_reports[font_id]
	local requested_path = FONT_PATHS[font_id]
	local is_fallback = (font_id ~= "runtime_cjk") and (loaded ~= true)
	local fallback_id = nil
	if is_fallback then
		fallback_id = "runtime_cjk"
	end

	-- Metrics for the *requested* font only when it truly loaded; else show fallback metrics separately.
	local metric_font = loaded and effective or nil
	local fallback_font = is_fallback and effective or nil

	return {
		id = id,
		requested_id = font_id,
		path = requested_path,
		resolved = report and report.resolved or transition._font_paths_loaded[font_id],
		loaded = loaded == true,
		call_ok = report and report.call_ok,
		reason = report and report.reason,
		mod_root = report and report.mod_root or (gui.get_mod_root and gui.get_mod_root()) or nil,
		is_runtime_fallback = is_fallback,
		fallback_id = fallback_id,
		effective_id = loaded and font_id or (fallback_id or font_id),
		sample_width = measure_sample(metric_font, SAMPLE_GLYPHS),
		ascii_width = measure_sample(metric_font, SAMPLE_ASCII),
		line_height = font_line_height(metric_font),
		glyphs = glyph_widths(metric_font),
		fallback_sample_width = measure_sample(fallback_font, SAMPLE_GLYPHS),
		fallback_line_height = font_line_height(fallback_font),
		report = report,
	}
end

function transition.set_glyph_test(enabled)
	transition._glyph_test = enabled == true
end

function transition.get_glyph_test()
	return transition._glyph_test == true
end

local function cfg_num(key, fallback)
	local v = transition.config[key]
	if v == nil then return fallback end
	return v
end

local function normalize_scale(scale, fallback)
	local n = tonumber(scale)
	if not n or n ~= n then
		return fallback or 1
	end
	local lo = transition.SCALE_MIN or 0.25
	local hi = transition.SCALE_MAX or 2
	if n < lo then n = lo end
	if n > hi then n = hi end
	return math.floor(n * 100 + 0.5) / 100
end

local function finish(active)
	local cb = active and active.on_complete
	transition._active = nil
	if type(cb) == "function" then
		pcall(cb)
	end
end

--- opts.chapter / opts.title, opts.after_delay, opts.on_complete, layout overrides
function transition.play(opts)
	opts = opts or {}
	if transition._active then
		finish(transition._active)
	end
	local spacing = opts.letter_spacing
	if spacing == nil then spacing = cfg_num("letter_spacing", DEFAULTS.letter_spacing) end
	transition._active = {
		chapter = tostring(opts.chapter or ""),
		title = tostring(opts.title or ""),
		age = 0,
		on_complete = opts.on_complete,
		black = opts.black or cfg_num("black", DEFAULTS.black),
		hold = opts.hold or cfg_num("hold", DEFAULTS.hold),
		fade = opts.fade or cfg_num("fade", DEFAULTS.fade),
		after_delay = opts.after_delay
			or cfg_num("after_delay", DEFAULTS.after_delay),
		chapter_scale = normalize_scale(
			opts.chapter_scale or cfg_num("chapter_scale", DEFAULTS.chapter_scale), 1
		),
		title_scale = normalize_scale(
			opts.title_scale or cfg_num("title_scale", DEFAULTS.title_scale), 1
		),
		chapter_y_frac = opts.chapter_y_frac or cfg_num("chapter_y_frac", DEFAULTS.chapter_y_frac),
		title_y_frac = opts.title_y_frac or cfg_num("title_y_frac", DEFAULTS.title_y_frac),
		letter_spacing = spacing or 0,
		font_id = opts.font_id or transition.config.font_id or DEFAULTS.font_id,
		preview_only = opts.preview_only == true,
	}
	return true
end

function transition.is_active()
	return transition._active ~= nil
end

function transition.cancel(fire_callback)
	local active = transition._active
	if not active then return end
	if fire_callback then
		finish(active)
	else
		transition._active = nil
	end
end

function transition.get_config()
	return transition.config
end

function transition.set_config(opts)
	opts = opts or {}
	for k, v in pairs(opts) do
		if DEFAULTS[k] ~= nil and v ~= nil then
			if k == "chapter_scale" or k == "title_scale" then
				transition.config[k] = normalize_scale(v, DEFAULTS[k])
			else
				transition.config[k] = v
			end
		end
	end
end

function transition.reset_config()
	for k, v in pairs(DEFAULTS) do
		transition.config[k] = v
	end
end

--- Play chapter + opening_title from story_defs (authoritative).
function transition.play_chapter(chapter_id, opts)
	opts = opts or {}
	local ok, story_reg = pcall(require, "Qing_Remaster_scripts.story.story_registry")
	if not ok or not story_reg or not story_reg.get_chapter then
		return false, "story_registry_missing"
	end
	local ch = story_reg.get_chapter(chapter_id)
	if not ch then return false, "unknown_chapter" end
	local lang = (Options and Options.Language == "en") and "en" or "zh"
	local function pick(tbl, fallback)
		if type(tbl) ~= "table" then return fallback or "" end
		if lang == "en" then return tbl.en or tbl.zh or fallback or "" end
		return tbl.zh or tbl.en or fallback or ""
	end
	return transition.play({
		chapter = opts.chapter or pick(ch.title, chapter_id),
		title = opts.title or pick(ch.opening_title, ""),
		after_delay = opts.after_delay,
		on_complete = opts.on_complete,
		preview_only = opts.preview_only == true,
		font_id = opts.font_id,
		black = opts.black,
		hold = opts.hold,
		fade = opts.fade,
		chapter_scale = opts.chapter_scale,
		title_scale = opts.title_scale,
		chapter_y_frac = opts.chapter_y_frac,
		title_y_frac = opts.title_y_frac,
		letter_spacing = opts.letter_spacing,
	})
end

--- Debug: title only (no Quest notify / no Story mutation).
function transition.debug_play_title(opts)
	opts = opts or {}
	if opts.chapter_id then
		return transition.play_chapter(opts.chapter_id, {
			preview_only = true,
			after_delay = opts.after_delay or 0,
			on_complete = opts.on_complete,
			font_id = opts.font_id,
		})
	end
	local lang = (Options and Options.Language == "en") and "en" or "zh"
	return transition.play({
		chapter = opts.chapter or ((lang == "en") and "Prologue" or "序章"),
		title = opts.title or ((lang == "en") and "The Hunt" or "狩猎"),
		preview_only = true,
		on_complete = opts.on_complete,
		after_delay = opts.after_delay or 0,
		font_id = opts.font_id,
	})
end

--- Debug: formal presentation path (suspend → title → resume Quest).
function transition.debug_play_title_then_quest(opts)
	opts = opts or {}
	local ok, story = pcall(require, "Qing_Remaster_scripts.story.story_state")
	if not ok or not story or not story.start_prologue_hunt then
		return false
	end
	-- Reset to locked so start_prologue_hunt always owns the presentation.
	local ch = story.get_chapter("prologue", true)
	if ch then
		ch.status = story.STATUS.LOCKED
		ch.current_node = nil
		ch.discovered = type(ch.discovered) == "table" and ch.discovered or {}
		ch.completed = type(ch.completed) == "table" and ch.completed or {}
		ch.discovered["prologue.hunt"] = nil
		ch.completed["prologue.hunt"] = nil
	end
	local tok, tracker = pcall(require, "Qing_Remaster_scripts.quest.quest_tracker")
	if tok and tracker and tracker.clear_suspend then
		tracker.clear_suspend()
	end
	if tok and tracker then
		tracker._cache = nil
	end
	return story.start_prologue_hunt({play_opening = true})
end

local function phase_alpha(age, black, hold, fade)
	local black_end = black
	local hold_end = black_end + hold
	local fade_end = hold_end + fade
	if age < black_end then
		return age / math.max(1, black_end)
	end
	if age < hold_end then
		return 1
	end
	if age < fade_end then
		local u = (age - hold_end) / math.max(1, fade)
		return 1 - u
	end
	return 0
end

local function text_alpha(age, black, hold, fade)
	local black_end = black
	local hold_end = black_end + hold
	local fade_end = hold_end + fade
	if age < 2 then
		return 0
	end
	if age < black_end + 4 then
		local u = (age - 2) / math.max(1, black_end + 2)
		return math.min(1, u)
	end
	if age < hold_end then
		return 1
	end
	if age < fade_end then
		local u = (age - hold_end) / math.max(1, fade)
		return 1 - u
	end
	return 0
end

local function glyph_width(font, glyph, scale)
	if font and font.GetStringWidthUTF8 then
		return (font:GetStringWidthUTF8(glyph) or 0) * scale
	end
	return 0
end

local function draw_line_centered(font, cx, y, text, scale, color, spacing)
	if not text or text == "" or not font then return end
	scale = normalize_scale(scale, 1)
	spacing = tonumber(spacing) or 0
	color = color or KColor(1, 1, 1, 1)
	-- Chapter BMFont scales freely; do not route through pixel_ui scale allowlist.
	local glyphs = {}
	local total_w = 0
	local count = 0
	for glyph in pixel_ui.iter_utf8_glyphs(text) do
		if count > 0 then
			total_w = total_w + spacing
		end
		local gw = glyph_width(font, glyph, scale)
		glyphs[#glyphs + 1] = {g = glyph, w = gw}
		total_w = total_w + gw
		count = count + 1
	end
	local x = math.floor((cx or 0) - total_w * 0.5 + 0.5)
	for i, rec in ipairs(glyphs) do
		if i > 1 then
			x = x + spacing
		end
		font:DrawStringScaledUTF8(rec.g, x, y, scale, scale, color, 0, false)
		x = x + rec.w
	end
end

local function render_glyph_test()
	if not transition._glyph_test then return end
	if auxi.is_pause_menu_open and auxi.is_pause_menu_open() then return end
	local scz = auxi.GetScreenSize and auxi.GetScreenSize() or Vector(480, 270)
	local x = 24
	local y = math.floor(scz.Y * 0.22 + 0.5)
	local scale = 1
	local col_label = KColor(0.7, 0.75, 0.85, 0.95)
	local col_text = KColor(1, 0.95, 0.8, 1)
	for _, id in ipairs(transition.FONT_IDS) do
		local font, _, loaded = transition.resolve_font(id)
		local lab = transition.FONT_LABELS[id]
		local label = (lab and lab.zh) or id
		local st = transition.get_font_status(id)
		local mark = loaded and "OK" or ("FALLBACK→" .. tostring(st.effective_id or "?"))
		gui.draw_ch(Vector(x, y), string.format("%s [%s]", label, mark), scale, scale, col_label, true, gui.f2 or gui.f)
		y = y + 12
		-- Draw with the font actually returned (requested if loaded, else fallback).
		if font then
			font:DrawStringScaledUTF8(SAMPLE_GLYPHS, x + 8, y, scale, scale, col_text, 0, false)
			y = y + 18
			font:DrawStringScaledUTF8(SAMPLE_ASCII, x + 8, y, scale, scale, col_text, 0, false)
			y = y + 22
		else
			y = y + 28
		end
	end
end

table.insert(transition.ToCall, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		local active = transition._active
		if not active then return end
		active.age = (active.age or 0) + 1
		local visual = (active.black or 0) + (active.hold or 0) + (active.fade or 0)
		local total = visual + (active.after_delay or 0)
		if active.age >= total then
			finish(active)
		end
	end,
})

-- After vanilla HUD / stage title (RGON). Fallback POST_RENDER without RGON.
local chapter_render_cb = (REPENTOGON and ModCallbacks.MC_POST_HUD_RENDER)
	or ModCallbacks.MC_POST_RENDER

table.insert(transition.ToCall, {
	CallBack = chapter_render_cb,
	params = nil,
	Function = function()
		render_glyph_test()
		local active = transition._active
		if not active then return end
		if auxi.is_pause_menu_open and auxi.is_pause_menu_open() then return end

		local age = active.age or 0
		local black = active.black or DEFAULTS.black
		local hold = active.hold or DEFAULTS.hold
		local fade = active.fade or DEFAULTS.fade
		local visual_end = black + hold + fade
		-- After veil: quiet gap (no overlay) before on_complete.
		if age >= visual_end then return end

		local a_black = phase_alpha(age, black, hold, fade)
		local a_text = text_alpha(age, black, hold, fade)
		if a_black <= 0.01 and a_text <= 0.01 then return end

		local spr = ensure_black()
		if spr and a_black > 0.01 then
			spr.Color = Color(1, 1, 1, a_black)
			spr:Render(Vector(0, 0), Vector(0, 0), Vector(0, 0))
		elseif a_black > 0.01 and Isaac.DrawLine then
			local scz = auxi.GetScreenSize and auxi.GetScreenSize() or Vector(480, 270)
			local col = KColor(0, 0, 0, a_black)
			for y = 0, math.floor(scz.Y) do
				Isaac.DrawLine(Vector(0, y), Vector(scz.X, y), col, col, 1)
			end
		end

		if a_text <= 0.01 then return end
		local scz = auxi.GetScreenSize and auxi.GetScreenSize() or Vector(480, 270)
		local cx = math.floor(scz.X * 0.5 + 0.5)
		local chapter_y = math.floor(scz.Y * (active.chapter_y_frac or DEFAULTS.chapter_y_frac) + 0.5)
		local title_y = math.floor(scz.Y * (active.title_y_frac or DEFAULTS.title_y_frac) + 0.5)
		local font = transition.resolve_font(active.font_id)
		local col_ch = KColor(0.82, 0.86, 0.95, a_text)
		local col_title = KColor(1.0, 0.94, 0.72, a_text)
		local spacing = active.letter_spacing or 0
		draw_line_centered(
			font, cx, chapter_y, active.chapter,
			active.chapter_scale or DEFAULTS.chapter_scale,
			col_ch, spacing
		)
		draw_line_centered(
			font, cx, title_y, active.title,
			active.title_scale or DEFAULTS.title_scale,
			col_title, spacing
		)
	end,
})

table.insert(transition.myToCall, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	params = nil,
	Function = function()
		transition._active = nil
		transition._glyph_test = false
		transition.clear_font_cache()
	end,
})

return transition
