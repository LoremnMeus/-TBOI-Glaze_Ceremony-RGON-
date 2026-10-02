-- Shared Pause-menu surface helpers for Quest and future Pause UI.
-- Lifecycle boundary: POST_GAME_STARTED ↔ PRE_GAME_EXIT / POST_GAME_END.
-- Do not infer in-run from MenuManager / Sprite userdata.
--
-- Layout contract (Quest Log v5 — 1:1 questpage parts):
--   panel           = paper top-left local (NOT center). Whole panel + content share this.
--   panel_offset    = baked whole-panel transform (debug Panel X/Y adds on top).
--   content_inset_* = content safe rect inside the 256px paper (not derived padding).
--   Height          = TOP(168) + N*MIDDLE(32) + BOTTOM(88) = 256 + 32*N  (no free stretch).
--   Width           = always 256 (source pixels; NEVER scale).
-- Debug offsets are integer pixels and never auto-written back into LAYOUTS.

local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local pixel_ui = require("Qing_Remaster_scripts.auxiliary.pixel_ui")

local pause_ui = {
	in_run = false,
	_debug_anchors = false,
	_debug_paper_bounds = false,
	_debug_offset = {
		surface = Vector(0, 0),
		hint = Vector(0, 0), -- legacy alias → toggle_open
		toggle_open = Vector(0, 0),
		toggle_close = Vector(0, 0),
		panel = Vector(0, 0),
		paper_fine = Vector(0, 0),
		content_fine = Vector(0, 0),
	},
	_last_anchor = nil,
	_last_layout = nil,
	_last_paper_rect = nil,
	_last_content_bounds = nil,
	-- Captured in MC_PRE_COMPLETION_MARKS_RENDER (before any return false).
	-- Quest UI consumes this from MC_POST_PAUSE_SCREEN_RENDER — never from POST marks.
	_completion_anchor = nil,
}

-- Source art (questpage.png) 1:1 — no scale.
local PAGE = {
	width = 256,
	top_h = 168,
	middle_h = 32,
	bottom_h = 88,
}
PAGE.base_height = PAGE.top_h + PAGE.bottom_h -- 256

-- panel = top-left of paper relative to Pause marks origin.
-- Previous center paper=(-150,-34) + offset(+72,0) + half of old 184 → migrated to TL of 256:
--   center X = -78 → TL X = -78 - 128 = -206
local LAYOUTS = {
	vanilla = {
		-- Open/Close tab CENTER anchors (ANM2 pivots are crop centers).
		-- Migrated from prior top-left bake (-116,138)/(+10,-12) + EN half(32,32).
		toggle_open = Vector(-84, 170),
		toggle_close = Vector(42, 20),
		panel = Vector(-206, -34),
		panel_offset = Vector(0, 0),
		paper_width = PAGE.width,
		middle_count = 1,      -- default height 288
		min_middle = 0,
		max_middle = 3,        -- 256 / 288 / 320 / 352
		-- Content safe rect insets (calibrate in Debug).
		content_inset_left = 36,
		content_inset_right = 36,
		content_inset_top = 28,
		content_inset_bottom = 24,
		pause_shift = 52,
		seed_cover = {left = -200, top = -50, right = -20, bottom = 90},
	},
	mini = {
		-- Center anchors (migrated from prior TL guesses + EN half 32).
		toggle_open = Vector(-68, 132),
		toggle_close = Vector(16, 38),
		panel = Vector(-180, -30),
		panel_offset = Vector(0, 0),
		paper_width = PAGE.width,
		middle_count = 1,
		min_middle = 0,
		max_middle = 2,
		content_inset_left = 36,
		content_inset_right = 36,
		content_inset_top = 28,
		content_inset_bottom = 24,
		pause_shift = 36,
		seed_cover = {left = -170, top = -40, right = -10, bottom = 80},
	},
	unintrusive = {
		toggle_open = Vector(-88, 142),
		toggle_close = Vector(14, 39),
		panel = Vector(-190, -32),
		panel_offset = Vector(0, 0),
		paper_width = PAGE.width,
		middle_count = 1,
		min_middle = 0,
		max_middle = 3,
		content_inset_left = 36,
		content_inset_right = 36,
		content_inset_top = 28,
		content_inset_bottom = 24,
		pause_shift = 40,
		seed_cover = {left = -185, top = -45, right = -15, bottom = 85},
	},
}

-- open_amount 0..1 drives paper reveal + native Pause shift together.
-- Offset = captured base + Vector(shift_x, 0); never accumulate per frame.
local shift = {
	feature_enabled = true,
	target_t = 0,
	current_t = 0,
	approach = 0.25,
	override_px = nil,
	bases = nil,
	last_open = false,
	last_applied_x = 0,
}

-- Absolute panel overrides for Debug (nil = use preset). Width is NEVER tunable.
local paper_tune = {
	middle_count = nil,
	min_middle = nil,
	max_middle = nil,
	content_inset_left = nil,
	content_inset_right = nil,
	content_inset_top = nil,
	content_inset_bottom = nil,
}

local function clear_paper_tune()
	paper_tune.middle_count = nil
	paper_tune.min_middle = nil
	paper_tune.max_middle = nil
	paper_tune.content_inset_left = nil
	paper_tune.content_inset_right = nil
	paper_tune.content_inset_top = nil
	paper_tune.content_inset_bottom = nil
end

local function ivec(x, y)
	return Vector(math.floor((x or 0) + 0.5), math.floor((y or 0) + 0.5))
end

function pause_ui.get_page_source()
	return {
		width = PAGE.width,
		top_h = PAGE.top_h,
		middle_h = PAGE.middle_h,
		bottom_h = PAGE.bottom_h,
		base_height = PAGE.base_height,
	}
end

function pause_ui.height_for_middle(n)
	n = math.max(0, math.floor((tonumber(n) or 0) + 0.5))
	return PAGE.base_height + n * PAGE.middle_h
end

function pause_ui.middle_for_height(h)
	h = tonumber(h) or PAGE.base_height
	local extra = math.max(0, h - PAGE.base_height)
	return math.floor((extra / PAGE.middle_h) + 0.5)
end

function pause_ui.set_in_run(value)
	pause_ui.in_run = value == true
	if not pause_ui.in_run then
		pause_ui._last_anchor = nil
		pause_ui._last_layout = nil
		pause_ui.clear_completion_anchor()
		pause_ui.restore_content_shift_bases()
		shift.target_t = 0
		shift.current_t = 0
		shift.override_px = nil
		shift.last_open = false
	end
end

--- Capture Pause completion-widget renderPos/scale for Quest layout.
--- Must be called from PRE_COMPLETION_MARKS_RENDER before any early return.
function pause_ui.capture_completion_anchor(render_pos, render_scale, player_type)
	if not render_pos then
		return
	end
	local scale = render_scale or Vector(1, 1)
	local frame = 0
	if Game and Game() and Game().GetFrameCount then
		frame = Game():GetFrameCount()
	end
	pause_ui._completion_anchor = {
		position = Vector(render_pos.X or 0, render_pos.Y or 0),
		scale = Vector(scale.X or 1, scale.Y or 1),
		player_type = player_type,
		frame = frame,
		source = "CompletionMarks PRE",
	}
end

function pause_ui.clear_completion_anchor()
	pause_ui._completion_anchor = nil
end

--- Debug / audit: last capture + age even if stale.
function pause_ui.get_completion_anchor_info()
	local a = pause_ui._completion_anchor
	if not a then
		return nil
	end
	local frame = 0
	if Game and Game() and Game().GetFrameCount then
		frame = Game():GetFrameCount()
	end
	local age = frame - (a.frame or frame)
	return {
		position = a.position and Vector(a.position.X, a.position.Y) or nil,
		scale = a.scale and Vector(a.scale.X, a.scale.Y) or nil,
		player_type = a.player_type,
		frame = a.frame,
		age = age,
		fresh = age <= 1,
		source = a.source or "CompletionMarks PRE",
	}
end

--- Fresh Pause anchor only (rejects MAIN→OPTIONS leftover).
function pause_ui.get_completion_anchor()
	local info = pause_ui.get_completion_anchor_info()
	if not info or not info.fresh then
		return nil
	end
	return pause_ui._completion_anchor
end

function pause_ui.is_in_run()
	return pause_ui.in_run == true
end

function pause_ui.is_open()
	return auxi.is_pause_menu_open() == true
end

function pause_ui.is_main_page()
	if PauseMenu and PauseMenu.GetState and PauseMenuStates then
		local ok, state = pcall(PauseMenu.GetState)
		if ok and state ~= nil then
			return state == PauseMenuStates.OPEN
		end
	end
	local ok, holder = pcall(require, "Qing_Remaster_scripts.others.Pause_Screen_holder")
	if ok and holder and holder.currentState then
		return holder.currentState.name == "MAIN"
	end
	return pause_ui.is_open()
end

function pause_ui.get_layout_variant()
	if UNINTRUSIVEPAUSEMENU then return "unintrusive" end
	if MiniPauseMenu_Mod or MiniPauseMenuPlus_Mod then return "mini" end
	return "vanilla"
end

function pause_ui.get_layout_preset(variant)
	variant = variant or pause_ui.get_layout_variant()
	return LAYOUTS[variant] or LAYOUTS.vanilla
end

function pause_ui.snap(v)
	return pixel_ui.snap(v)
end

--- Apply local offset under Pause callback renderScale (layout transform only).
--- Font scale stays on the pixel_ui whitelist and must NOT multiply renderScale.
function pause_ui.offset(anchor, local_pos)
	anchor = anchor or {}
	local origin = anchor.origin or Vector(0, 0)
	local scale = anchor.scale or Vector(1, 1)
	local lp = local_pos or Vector(0, 0)
	return pause_ui.snap(origin + Vector(lp.X * scale.X, lp.Y * scale.Y))
end

function pause_ui.get_debug_offsets()
	local d = pause_ui._debug_offset
	return {
		surface = d.surface,
		hint = d.toggle_open,
		toggle_open = d.toggle_open,
		toggle_close = d.toggle_close,
		panel = d.panel,
		paper_fine = d.paper_fine,
		content_fine = d.content_fine,
		quest = d.content_fine,
		paper = d.paper_fine,
	}
end

function pause_ui.set_debug_surface_offset(x, y)
	pause_ui._debug_offset.surface = ivec(x, y)
end

function pause_ui.set_debug_hint_offset(x, y)
	pause_ui.set_debug_toggle_open_offset(x, y)
end

function pause_ui.set_debug_toggle_open_offset(x, y)
	pause_ui._debug_offset.toggle_open = ivec(x, y)
	pause_ui._debug_offset.hint = pause_ui._debug_offset.toggle_open
end

function pause_ui.set_debug_toggle_close_offset(x, y)
	pause_ui._debug_offset.toggle_close = ivec(x, y)
end

function pause_ui.reset_toggle_offsets()
	pause_ui._debug_offset.toggle_open = Vector(0, 0)
	pause_ui._debug_offset.toggle_close = Vector(0, 0)
	pause_ui._debug_offset.hint = pause_ui._debug_offset.toggle_open
end

function pause_ui.set_debug_panel_offset(x, y)
	pause_ui._debug_offset.panel = ivec(x, y)
end

function pause_ui.set_debug_content_fine_offset(x, y)
	pause_ui._debug_offset.content_fine = ivec(x, y)
end

function pause_ui.set_debug_quest_offset(x, y)
	pause_ui.set_debug_content_fine_offset(x, y)
end

function pause_ui.set_debug_paper_fine_offset(x, y)
	pause_ui._debug_offset.paper_fine = ivec(x, y)
end

function pause_ui.set_debug_paper_offset(x, y)
	pause_ui.set_debug_paper_fine_offset(x, y)
end

function pause_ui.reset_panel_layout_defaults()
	pause_ui._debug_offset.panel = Vector(0, 0)
	pause_ui._debug_offset.paper_fine = Vector(0, 0)
	pause_ui._debug_offset.content_fine = Vector(0, 0)
	clear_paper_tune()
end

function pause_ui.reset_debug_offsets()
	pause_ui._debug_offset.surface = Vector(0, 0)
	pause_ui.reset_toggle_offsets()
	pause_ui.reset_panel_layout_defaults()
end

--- Debug overrides: middle_count / insets (width fixed at 256).
function pause_ui.set_paper_tune(opts)
	opts = opts or {}
	local function set_num(key, v)
		if v == nil or v == false or v == "clear" then
			paper_tune[key] = nil
			return
		end
		paper_tune[key] = math.floor((tonumber(v) or 0) + 0.5)
	end
	if opts.clear == true then
		clear_paper_tune()
		return
	end
	if opts.middle_count ~= nil then set_num("middle_count", opts.middle_count) end
	if opts.min_middle ~= nil then set_num("min_middle", opts.min_middle) end
	if opts.max_middle ~= nil then set_num("max_middle", opts.max_middle) end
	if opts.content_inset_left ~= nil then set_num("content_inset_left", opts.content_inset_left) end
	if opts.content_inset_right ~= nil then set_num("content_inset_right", opts.content_inset_right) end
	if opts.content_inset_top ~= nil then set_num("content_inset_top", opts.content_inset_top) end
	if opts.content_inset_bottom ~= nil then set_num("content_inset_bottom", opts.content_inset_bottom) end
	-- Legacy no-ops so old Debug callers don't error
	_ = opts.width
	_ = opts.min_height
	_ = opts.max_height
	_ = opts.pad_x
	_ = opts.pad_top
	_ = opts.pad_bottom
	_ = opts.content_width
end

function pause_ui.get_paper_tune()
	return {
		middle_count = paper_tune.middle_count,
		min_middle = paper_tune.min_middle,
		max_middle = paper_tune.max_middle,
		content_inset_left = paper_tune.content_inset_left,
		content_inset_right = paper_tune.content_inset_right,
		content_inset_top = paper_tune.content_inset_top,
		content_inset_bottom = paper_tune.content_inset_bottom,
	}
end

function pause_ui.get_paper_effective(variant)
	local preset = pause_ui.get_layout_preset(variant)
	local min_n = paper_tune.min_middle
	if min_n == nil then min_n = preset.min_middle or 0 end
	local max_n = paper_tune.max_middle
	if max_n == nil then max_n = preset.max_middle or 3 end
	if max_n < min_n then max_n = min_n end
	local n = paper_tune.middle_count
	if n == nil then n = preset.middle_count or 1 end
	if n < min_n then n = min_n end
	if n > max_n then n = max_n end
	local il = paper_tune.content_inset_left or (preset.content_inset_left or 36)
	local ir = paper_tune.content_inset_right or (preset.content_inset_right or 36)
	local it = paper_tune.content_inset_top or (preset.content_inset_top or 28)
	local ib = paper_tune.content_inset_bottom or (preset.content_inset_bottom or 24)
	local height = pause_ui.height_for_middle(n)
	local content_width = math.max(40, PAGE.width - il - ir)
	return {
		width = PAGE.width,
		height = height,
		min_height = pause_ui.height_for_middle(min_n),
		max_height = pause_ui.height_for_middle(max_n),
		middle_count = n,
		middle_forced = paper_tune.middle_count ~= nil,
		min_middle = min_n,
		max_middle = max_n,
		top_h = PAGE.top_h,
		middle_h = PAGE.middle_h,
		bottom_h = PAGE.bottom_h,
		base_height = PAGE.base_height,
		content_inset_left = il,
		content_inset_right = ir,
		content_inset_top = it,
		content_inset_bottom = ib,
		content_width = content_width,
		-- Compat aliases for older Debug UI
		pad_x = il,
		pad_top = it,
		pad_bottom = ib,
		preset_width = PAGE.width,
		preset_min_height = pause_ui.height_for_middle(preset.min_middle or 0),
		preset_max_height = pause_ui.height_for_middle(preset.max_middle or 3),
		panel_offset = preset.panel_offset or Vector(0, 0),
	}
end

function pause_ui.capture_anchor(render_pos, render_scale)
	local variant = pause_ui.get_layout_variant()
	local layout = pause_ui.get_layout_preset(variant)
	local eff = pause_ui.get_paper_effective(variant)
	local panel_base = layout.panel or layout.paper or Vector(0, 0)
	local toggle_open_base = layout.toggle_open or layout.hint or Vector(0, 0)
	local toggle_close_base = layout.toggle_close or Vector(0, 0)
	local anchor = {
		origin = render_pos or Vector(0, 0),
		scale = render_scale or Vector(1, 1),
		variant = variant,
		hint_local = toggle_open_base, -- legacy
		toggle_open_local = toggle_open_base,
		toggle_close_local = toggle_close_base,
		panel_local = panel_base,
		panel_offset = layout.panel_offset or Vector(0, 0),
		quest_width = eff.content_width,
		paper_width = PAGE.width,
		paper_min_height = eff.min_height,
		paper_max_height = eff.max_height,
		middle_count = eff.middle_count,
		middle_forced = eff.middle_forced == true,
		min_middle = eff.min_middle,
		max_middle = eff.max_middle,
		top_h = PAGE.top_h,
		middle_h = PAGE.middle_h,
		bottom_h = PAGE.bottom_h,
		content_inset_left = eff.content_inset_left,
		content_inset_right = eff.content_inset_right,
		content_inset_top = eff.content_inset_top,
		content_inset_bottom = eff.content_inset_bottom,
		seed_cover = layout.seed_cover,
		pause_shift = layout.pause_shift or 52,
	}
	pause_ui._last_anchor = anchor
	return anchor
end

function pause_ui.build_layout(render_pos, render_scale)
	local anchor = pause_ui.capture_anchor(render_pos, render_scale)
	local dbg = pause_ui._debug_offset
	local sx = dbg.surface and dbg.surface.X or 0
	local sy = dbg.surface and dbg.surface.Y or 0
	local baked = anchor.panel_offset or Vector(0, 0)
	local panel_dx = (baked.X or 0) + (dbg.panel and dbg.panel.X or 0)
	local panel_dy = (baked.Y or 0) + (dbg.panel and dbg.panel.Y or 0)
	local paper_fine = dbg.paper_fine or Vector(0, 0)
	local content_fine = dbg.content_fine or Vector(0, 0)
	local toggle_open_dbg = dbg.toggle_open or dbg.hint or Vector(0, 0)
	local toggle_close_dbg = dbg.toggle_close or Vector(0, 0)
	local panel_base = anchor.panel_local or Vector(0, 0)
	local toggle_open_base = anchor.toggle_open_local or anchor.hint_local or Vector(0, 0)
	local toggle_close_base = anchor.toggle_close_local or Vector(0, 0)

	-- Open tab: Pause-relative top-left.
	local toggle_open_local = Vector(
		(toggle_open_base.X or 0) + sx + (toggle_open_dbg.X or 0),
		(toggle_open_base.Y or 0) + sy + (toggle_open_dbg.Y or 0)
	)
	-- Paper top-left (global panel transform + optional paper fine).
	local paper_local = Vector(
		(panel_base.X or 0) + sx + panel_dx + (paper_fine.X or 0),
		(panel_base.Y or 0) + sy + panel_dy + (paper_fine.Y or 0)
	)
	-- Content top-center from paper top-left + safe insets (+ content fine).
	local il = anchor.content_inset_left or 36
	local ir = anchor.content_inset_right or 36
	local it = anchor.content_inset_top or 28
	local cw = anchor.quest_width or (PAGE.width - il - ir)
	local quest_local = Vector(
		paper_local.X + il + (cw * 0.5) + (content_fine.X or 0),
		paper_local.Y + it + (content_fine.Y or 0)
	)
	local paper_origin = pause_ui.offset(anchor, paper_local)
	local quest_origin = pause_ui.offset(anchor, quest_local)
	local toggle_open_pos = pause_ui.offset(anchor, toggle_open_local)
	-- Close tab: relative to quest paper top-left (screen space).
	local toggle_close_pos = pause_ui.snap(Vector(
		paper_origin.X + (toggle_close_base.X or 0) + (toggle_close_dbg.X or 0),
		paper_origin.Y + (toggle_close_base.Y or 0) + (toggle_close_dbg.Y or 0)
	))
	local layout = {
		anchor = anchor,
		hint_pos = toggle_open_pos,
		toggle_open_pos = toggle_open_pos,
		toggle_close_pos = toggle_close_pos,
		paper_origin = paper_origin,
		quest_origin = quest_origin,
		quest_width = cw,
		paper_width = PAGE.width,
		paper_min_height = anchor.paper_min_height,
		paper_max_height = anchor.paper_max_height,
		middle_count = anchor.middle_count,
		middle_forced = anchor.middle_forced == true,
		min_middle = anchor.min_middle,
		max_middle = anchor.max_middle,
		top_h = PAGE.top_h,
		middle_h = PAGE.middle_h,
		bottom_h = PAGE.bottom_h,
		content_inset_left = il,
		content_inset_right = ir,
		content_inset_top = it,
		content_inset_bottom = anchor.content_inset_bottom or 24,
		pad_x = il,
		pad_top = it,
		pad_bottom = anchor.content_inset_bottom or 24,
		seed_cover = anchor.seed_cover,
		hint_local_final = ivec(toggle_open_local.X, toggle_open_local.Y),
		toggle_open_local_final = ivec(toggle_open_local.X, toggle_open_local.Y),
		toggle_close_offset_final = ivec(
			(toggle_close_base.X or 0) + (toggle_close_dbg.X or 0),
			(toggle_close_base.Y or 0) + (toggle_close_dbg.Y or 0)
		),
		paper_local_final = ivec(paper_local.X, paper_local.Y),
		quest_local_final = ivec(quest_local.X, quest_local.Y),
		panel_offset_final = ivec(panel_dx, panel_dy),
		debug = {
			surface_offset = dbg.surface,
			toggle_open_offset = toggle_open_dbg,
			toggle_close_offset = toggle_close_dbg,
			hint_offset = toggle_open_dbg,
			panel_offset = dbg.panel,
			paper_fine_offset = paper_fine,
			content_fine_offset = content_fine,
			quest_offset = content_fine,
			paper_offset = paper_fine,
		},
	}
	pause_ui._last_layout = layout
	return layout
end

function pause_ui.get_last_anchor()
	return pause_ui._last_anchor
end

function pause_ui.get_last_layout()
	return pause_ui._last_layout
end

function pause_ui.set_debug_anchors(enabled)
	pause_ui._debug_anchors = enabled == true
end

function pause_ui.get_debug_anchors()
	return pause_ui._debug_anchors == true
end

function pause_ui.set_debug_paper_bounds(enabled)
	pause_ui._debug_paper_bounds = enabled == true
end

function pause_ui.get_debug_paper_bounds()
	return pause_ui._debug_paper_bounds == true
end

local function cross(pos, col)
	if not Isaac.DrawLine or not pos then return end
	Isaac.DrawLine(pos + Vector(-4, 0), pos + Vector(4, 0), col, col, 1)
	Isaac.DrawLine(pos + Vector(0, -4), pos + Vector(0, 4), col, col, 1)
end

local function rect_outline(L, T, R, B, col)
	if not Isaac.DrawLine then return end
	Isaac.DrawLine(Vector(L, T), Vector(R, T), col, col, 1)
	Isaac.DrawLine(Vector(R, T), Vector(R, B), col, col, 1)
	Isaac.DrawLine(Vector(R, B), Vector(L, B), col, col, 1)
	Isaac.DrawLine(Vector(L, B), Vector(L, T), col, col, 1)
end

--- Snap desired height to Top + N*Middle + Bottom (1:1 pixels).
--- paper_origin is TOP-LEFT. open_t only clips visible draw width.
function pause_ui.get_quest_paper_rect(layout, content_bounds, open_t)
	layout = layout or pause_ui._last_layout
	if not layout or not layout.paper_origin then return nil end
	open_t = tonumber(open_t)
	if open_t == nil then open_t = pause_ui.get_quest_open_amount() end
	if open_t < 0 then open_t = 0 end
	if open_t > 1 then open_t = 1 end

	local full_w = PAGE.width
	local top_h = layout.top_h or PAGE.top_h
	local mid_h = layout.middle_h or PAGE.middle_h
	local bot_h = layout.bottom_h or PAGE.bottom_h
	local base_h = top_h + bot_h
	local min_n = layout.min_middle or 0
	local max_n = layout.max_middle or 3
	local default_n = layout.middle_count or 1
	local pad_bottom = layout.content_inset_bottom or layout.pad_bottom or 24
	local origin = layout.paper_origin -- TOP-LEFT
	local left = origin.X
	local top = origin.Y
	local right = left + full_w

	local n = default_n
	local overflow = false
	if layout.middle_forced then
		n = default_n
		if n < min_n then n = min_n end
		if n > max_n then n = max_n end
	elseif content_bounds and content_bounds.bottom then
		local desired = (content_bounds.bottom - top) + pad_bottom
		local needed = math.max(base_h + min_n * mid_h, desired)
		local extra = math.max(0, needed - base_h)
		n = math.ceil(extra / mid_h - 1e-6)
		if n < min_n then n = min_n end
		if n > max_n then
			overflow = true
			n = max_n
		end
	else
		if n < min_n then n = min_n end
		if n > max_n then n = max_n end
	end

	local height = base_h + n * mid_h
	local bottom = top + height
	local vis_w = math.max(4, math.floor(full_w * open_t + 0.5))
	local vis_left = right - vis_w

	local rect = {
		left = math.floor(vis_left + 0.5),
		top = math.floor(top + 0.5),
		right = math.floor(right + 0.5),
		bottom = math.floor(bottom + 0.5),
		full_left = math.floor(left + 0.5),
		full_right = math.floor(right + 0.5),
		full_top = math.floor(top + 0.5),
		full_bottom = math.floor(bottom + 0.5),
		full_width = full_w,
		visible_width = vis_w,
		height = math.floor(height + 0.5),
		min_height = base_h + min_n * mid_h,
		max_height = base_h + max_n * mid_h,
		middle_count = n,
		top_h = top_h,
		middle_h = mid_h,
		bottom_h = bot_h,
		overflow = overflow,
		open_t = open_t,
		anchor = "top_left",
	}
	pause_ui._last_paper_rect = rect
	return rect
end

function pause_ui.get_last_paper_rect()
	return pause_ui._last_paper_rect
end

function pause_ui.set_last_content_bounds(bounds)
	pause_ui._last_content_bounds = bounds
end

--- Anchor / paper / content overlay.
--- Yellow = full paper; cyan = content; red = overflow; magenta = Seed guide only.
function pause_ui.render_debug_overlay(layout, content_bounds)
	if not layout then return end
	local show_anchor = pause_ui._debug_anchors
	local show_paper = pause_ui._debug_paper_bounds
	if not show_anchor and not show_paper then return end

	if show_anchor then
		local a = layout.anchor
		if a and a.origin then
			cross(pause_ui.snap(a.origin), KColor(1, 0.92, 0.2, 0.95))
		end
		if layout.quest_origin then
			cross(layout.quest_origin, KColor(0.25, 1, 0.45, 0.95))
		end
		if layout.paper_origin then
			cross(layout.paper_origin, KColor(0.95, 0.75, 0.35, 0.95))
		end
		if layout.hint_pos then
			cross(layout.hint_pos, KColor(1, 0.55, 0.15, 0.95))
		end
	end
	if show_paper or show_anchor then
		if content_bounds and content_bounds.left then
			rect_outline(
				content_bounds.left, content_bounds.top,
				content_bounds.right, content_bounds.bottom,
				KColor(0.2, 0.95, 1, 0.85)
			)
		end
	end
	if show_paper then
		local pr = pause_ui._last_paper_rect or pause_ui.get_quest_paper_rect(layout, content_bounds, 1)
		if pr then
			-- Yellow: fixed full paper layout rect
			rect_outline(
				pr.full_left or pr.left, pr.full_top or pr.top,
				pr.full_right or pr.right, pr.full_bottom or pr.bottom,
				KColor(1.0, 0.88, 0.2, 0.95)
			)
			-- Green: content safe rect from insets
			local il = layout.content_inset_left or 36
			local ir = layout.content_inset_right or 36
			local it = layout.content_inset_top or 28
			local ib = layout.content_inset_bottom or 24
			local fl = pr.full_left or pr.left
			local ft = pr.full_top or pr.top
			local fr = pr.full_right or pr.right
			local fb = pr.full_bottom or pr.bottom
			rect_outline(
				fl + il, ft + it,
				fr - ir, fb - ib,
				KColor(0.35, 1.0, 0.45, 0.75)
			)
			if pr.overflow then
				local max_b = (pr.full_top or pr.top) + (pr.max_height or 352)
				rect_outline(
					pr.full_left or pr.left, max_b,
					pr.full_right or pr.right, max_b + 8,
					KColor(1.0, 0.2, 0.2, 0.9)
				)
			end
			-- Magenta: Seed safety guide (does NOT affect paper size)
			local sc = layout.seed_cover
			local anchor = layout.anchor
			if sc and anchor then
				local tl = pause_ui.offset(anchor, Vector(sc.left or 0, sc.top or 0))
				local br = pause_ui.offset(anchor, Vector(sc.right or 0, sc.bottom or 0))
				rect_outline(tl.X, tl.Y, br.X, br.Y, KColor(0.9, 0.2, 0.85, 0.55))
			end
		end
	end
end

function pause_ui.get_audit_snapshot()
	local a = pause_ui._last_anchor
	local layout = pause_ui._last_layout
	local preset = pause_ui.get_layout_preset(a and a.variant)
	local dbg = pause_ui._debug_offset
	return {
		in_run = pause_ui.in_run,
		pause_open = pause_ui.is_open(),
		main_page = pause_ui.is_main_page(),
		variant = pause_ui.get_layout_variant(),
		quest_base = preset and {
			x = (preset.panel and preset.panel.X or 0)
				+ (preset.panel_offset and preset.panel_offset.X or 0)
				+ (preset.content_inset_left or 36),
			y = (preset.panel and preset.panel.Y or 0)
				+ (preset.panel_offset and preset.panel_offset.Y or 0)
				+ (preset.content_inset_top or 28),
			width = (pause_ui.get_paper_effective(a and a.variant).content_width),
		} or nil,
		paper_base = preset and {
			x = (preset.panel and preset.panel.X or 0)
				+ (preset.panel_offset and preset.panel_offset.X or 0),
			y = (preset.panel and preset.panel.Y or 0)
				+ (preset.panel_offset and preset.panel_offset.Y or 0),
			width = PAGE.width,
			min_height = pause_ui.height_for_middle(preset.min_middle or 0),
			middle_count = preset.middle_count or 1,
		} or nil,
		hint_base = preset and {
			x = preset.toggle_open and preset.toggle_open.X,
			y = preset.toggle_open and preset.toggle_open.Y,
		} or nil,
		debug_offset = {
			surface_x = dbg.surface and dbg.surface.X or 0,
			surface_y = dbg.surface and dbg.surface.Y or 0,
			hint_x = dbg.hint and dbg.hint.X or 0,
			hint_y = dbg.hint and dbg.hint.Y or 0,
			panel_x = dbg.panel and dbg.panel.X or 0,
			panel_y = dbg.panel and dbg.panel.Y or 0,
			paper_fine_x = dbg.paper_fine and dbg.paper_fine.X or 0,
			paper_fine_y = dbg.paper_fine and dbg.paper_fine.Y or 0,
			content_fine_x = dbg.content_fine and dbg.content_fine.X or 0,
			content_fine_y = dbg.content_fine and dbg.content_fine.Y or 0,
			-- Legacy
			quest_x = dbg.content_fine and dbg.content_fine.X or 0,
			quest_y = dbg.content_fine and dbg.content_fine.Y or 0,
			paper_x = dbg.paper_fine and dbg.paper_fine.X or 0,
			paper_y = dbg.paper_fine and dbg.paper_fine.Y or 0,
		},
		panel_offset_final = layout and layout.panel_offset_final and {
			x = layout.panel_offset_final.X,
			y = layout.panel_offset_final.Y,
		} or nil,
		quest_local_final = layout and layout.quest_local_final and {
			x = layout.quest_local_final.X,
			y = layout.quest_local_final.Y,
		} or nil,
		paper_local_final = layout and layout.paper_local_final and {
			x = layout.paper_local_final.X,
			y = layout.paper_local_final.Y,
		} or nil,
		hint_local_final = layout and layout.hint_local_final and {
			x = layout.hint_local_final.X,
			y = layout.hint_local_final.Y,
		} or nil,
		quest_screen = layout and layout.quest_origin and {
			x = layout.quest_origin.X,
			y = layout.quest_origin.Y,
		} or nil,
		paper_screen = layout and layout.paper_origin and {
			x = layout.paper_origin.X,
			y = layout.paper_origin.Y,
		} or nil,
		anchor = a and {
			origin_x = a.origin and a.origin.X,
			origin_y = a.origin and a.origin.Y,
			scale_x = a.scale and a.scale.X,
			scale_y = a.scale and a.scale.Y,
			variant = a.variant,
		} or nil,
		completion_anchor = pause_ui.get_completion_anchor_info(),
		native_pause_shift_x = pause_ui.get_native_pause_shift_x(),
		content_shift = pause_ui.get_content_shift_snapshot(),
		open_amount = pause_ui.get_quest_open_amount(),
	}
end

-- ---- Pause content shift (vanilla Pause sprites slide right when Quest opens) ----

local function read_sprite_offset(spr)
	if not spr then return nil end
	local ok, off = pcall(function() return spr.Offset end)
	if not ok or not off then return nil end
	return Vector(off.X or 0, off.Y or 0)
end

local function write_sprite_offset(spr, vec)
	if not spr or not vec then return false end
	local ok = pcall(function()
		spr.Offset = Vector(vec.X, vec.Y)
	end)
	return ok == true
end

local function collect_pause_sprites(pause_body, pause_stats)
	local list = {}
	local function add(key, spr)
		if spr then
			list[#list + 1] = {key = key, spr = spr}
		end
	end
	add("body", pause_body or (PauseMenu and PauseMenu.GetSprite and PauseMenu.GetSprite()))
	add("stats", pause_stats or (PauseMenu and PauseMenu.GetStatsSprite and PauseMenu.GetStatsSprite()))
	if PauseMenu then
		if PauseMenu.GetCompletionMarksSprite then
			add("marks", PauseMenu.GetCompletionMarksSprite())
		end
		if PauseMenu.GetMyStuffSprite then
			add("mystuff", PauseMenu.GetMyStuffSprite())
		end
	end
	return list
end

function pause_ui.capture_content_shift_bases(pause_body, pause_stats)
	local bases = {}
	for _, row in ipairs(collect_pause_sprites(pause_body, pause_stats)) do
		local off = read_sprite_offset(row.spr)
		if off then
			bases[row.key] = {
				x = off.X,
				y = off.Y,
				spr = row.spr,
			}
		end
	end
	shift.bases = bases
	return bases
end

function pause_ui.restore_content_shift_bases()
	local bases = shift.bases
	if not bases then
		shift.last_applied_x = 0
		return
	end
	for _, row in pairs(bases) do
		if row.spr then
			write_sprite_offset(row.spr, Vector(row.x, row.y))
		end
	end
	shift.last_applied_x = 0
end

local function apply_shift_px(px)
	local bases = shift.bases
	if not bases then return end
	px = math.floor((px or 0) + 0.5)
	for _, row in pairs(bases) do
		if row.spr then
			write_sprite_offset(row.spr, Vector(row.x + px, row.y))
		end
	end
	shift.last_applied_x = px
end

function pause_ui.set_content_shift_enabled(enabled)
	shift.feature_enabled = enabled == true
	if not shift.feature_enabled and not shift.override_px then
		apply_shift_px(0)
		shift.target_t = 0
		shift.current_t = 0
	end
end

function pause_ui.is_content_shift_enabled()
	return shift.feature_enabled == true
end

function pause_ui.set_content_shift_target(t)
	t = tonumber(t) or 0
	if t < 0 then t = 0 end
	if t > 1 then t = 1 end
	shift.target_t = t
end

--- Canonical open amount API (paper reveal + Pause shift share this).
function pause_ui.set_quest_open_amount(t)
	pause_ui.set_content_shift_target(t)
end

function pause_ui.get_content_shift_t()
	return shift.current_t or 0
end

function pause_ui.get_quest_open_amount()
	return pause_ui.get_content_shift_t()
end

--- Pixel shift currently applied to native PauseMenu sprites via Sprite.Offset.
--- Custom (self-drawn) marks must add this to RenderPos; do NOT also Offset those sprites.
function pause_ui.get_native_pause_shift()
	return Vector(shift.last_applied_x or 0, 0)
end

function pause_ui.get_native_pause_shift_x()
	return shift.last_applied_x or 0
end

function pause_ui.set_content_shift_approach(v)
	v = tonumber(v) or 0.25
	if v < 0.05 then v = 0.05 end
	if v > 1 then v = 1 end
	shift.approach = v
end

function pause_ui.get_content_shift_approach()
	return shift.approach or 0.25
end

function pause_ui.get_pause_shift_max()
	local preset = pause_ui.get_layout_preset()
	return (preset and preset.pause_shift) or 48
end

--- Probe / debug: force an immediate pixel shift (nil clears override).
function pause_ui.set_debug_shift_test(px)
	if px == nil then
		shift.override_px = nil
		return
	end
	shift.override_px = math.floor((tonumber(px) or 0) + 0.5)
end

function pause_ui.get_debug_shift_test()
	return shift.override_px
end

function pause_ui.get_content_shift_snapshot()
	local bases = shift.bases or {}
	local out_bases = {}
	for k, row in pairs(bases) do
		out_bases[k] = {x = row.x, y = row.y}
	end
	return {
		feature_enabled = shift.feature_enabled,
		target_t = shift.target_t,
		current_t = shift.current_t,
		open_amount = shift.current_t,
		applied_x = shift.last_applied_x,
		override_px = shift.override_px,
		max_px = pause_ui.get_pause_shift_max(),
		bases = out_bases,
	}
end

--- Alias used by quest_panel / debug.
function pause_ui.apply_native_pause_shift(pause_body, pause_stats)
	pause_ui.tick_content_shift(pause_body, pause_stats)
end

--- Call from MC_PRE_PAUSE_SCREEN_RENDER each frame. Captures bases on open edge;
--- derives Offset = base + shift (never Offset = Offset + delta).
function pause_ui.tick_content_shift(pause_body, pause_stats)
	local open = pause_ui.is_open() == true
	if open and not shift.last_open then
		shift.bases = nil
		pause_ui.capture_content_shift_bases(pause_body, pause_stats)
	end
	if not open then
		if shift.last_open then
			pause_ui.restore_content_shift_bases()
			shift.bases = nil
			shift.current_t = 0
			shift.target_t = 0
			shift.override_px = nil
			pause_ui.clear_completion_anchor()
		end
		shift.last_open = false
		return
	end
	shift.last_open = true

	if not shift.bases then
		pause_ui.capture_content_shift_bases(pause_body, pause_stats)
	else
		-- Refresh spr userdata handles each frame (wrappers may change).
		for _, row in ipairs(collect_pause_sprites(pause_body, pause_stats)) do
			local b = shift.bases[row.key]
			if b then
				b.spr = row.spr
			elseif row.spr then
				local off = read_sprite_offset(row.spr)
				if off then
					shift.bases[row.key] = {x = off.X, y = off.Y, spr = row.spr}
				end
			end
		end
	end

	local tgt = shift.target_t or 0
	local cur = shift.current_t or 0
	local ap = shift.approach or 0.25
	cur = cur + (tgt - cur) * ap
	if math.abs(cur - tgt) < 0.01 then
		cur = tgt
	end
	shift.current_t = cur

	local sx
	if shift.override_px ~= nil then
		sx = shift.override_px
	elseif not shift.feature_enabled then
		sx = 0
	else
		sx = math.floor(cur * pause_ui.get_pause_shift_max() + 0.5)
	end
	apply_shift_px(sx)
end

return pause_ui
