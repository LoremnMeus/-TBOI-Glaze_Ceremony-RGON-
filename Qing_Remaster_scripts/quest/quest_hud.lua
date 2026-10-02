-- Minimal text Quest HUD: toast + optional persistent tracker.
-- Default: tracker OFF (schema_version 1). Pause content lives in quest_panel.

local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local pixel_ui = require("Qing_Remaster_scripts.auxiliary.pixel_ui")
local quest_draw = require("Qing_Remaster_scripts.quest.quest_draw")

local QUEST_UI_SCHEMA = 1
local SCALE = 1
local TOAST_ROW_H = 10
-- Toast lifetime is advanced on MC_POST_UPDATE (30 Hz logic frames), not Render.
local TOAST_FADE_IN = 5
local TOAST_FADE_OUT = 12
local TOAST_ENTER_Y = 4
local QUEST_HUD_LAYOUT = {
	toast = Vector(126, 16),
	title_centered = true,
	title_letter_spacing = 1,
	title_y_offset = 0,
	ornament_y_offset = 0,
	ornament_half_width = 24,
	body_y_offset = 0,
	body_row_h = 10,
	fade_in = TOAST_FADE_IN,
	fade_out = TOAST_FADE_OUT,
	enter_y = TOAST_ENTER_Y,
}

local hud = {
	ToCall = {},
	myToCall = {},
	own_key = "Quest_HUD_",
	_toast = nil,
	_toast_queue = {},
	_tracker = nil,
	_tracker_alpha = 0.55,
	_tracker_boost_until = 0,
	_room_seen = nil,
	_debug_toast_offset = Vector(0, 0),
	_debug_title = {
		centered = nil, -- nil → use LAYOUT default
		letter_spacing = nil,
		y_offset = nil,
		ornament_y_offset = nil,
		ornament_half_width = nil,
		body_y_offset = nil,
		body_row_h = nil,
	},
	_debug_preview = {
		enabled = false,
		kind = "new",
		line1 = "",
		line2 = "",
		line3 = "",
	},
}

local function normalize_prefs(p)
	p = p or {}
	if p.tracker_enabled == nil then p.tracker_enabled = false end
	if p.compact_mode == nil then p.compact_mode = false end
	p.schema_version = QUEST_UI_SCHEMA
	return p
end

local function prefs()
	if type(save.PermanentData) ~= "table" then
		return {schema_version = QUEST_UI_SCHEMA, tracker_enabled = false, compact_mode = false}
	end
	save.PermanentData.QuestUI = normalize_prefs(save.PermanentData.QuestUI or {
		schema_version = QUEST_UI_SCHEMA,
		tracker_enabled = false,
		compact_mode = false,
	})
	return save.PermanentData.QuestUI
end

function hud.get_prefs()
	return prefs()
end

function hud.ending1_blocking()
	local ok, end1 = pcall(require, "Qing_Remaster_scripts.threads.thread_End1")
	if ok and end1 and (end1.end1_has_start or end1.end1_has_end) then
		return true
	end
	return false
end

local function make_toast_payload(toast)
	local duration = math.max(1, toast.duration or 75)
	return {
		kind = toast.kind or "update",
		line1 = toast.line1 or "",
		line2 = toast.line2 or "",
		line3 = toast.line3 or "",
		completed = toast.completed == true,
		age = 0,
		duration = duration,
	}
end

local function activate_toast(payload)
	hud._toast = payload
	hud._tracker_boost_until = (Game():GetFrameCount() or 0) + 180
	hud._tracker_alpha = 1
end

local function pop_toast_queue()
	local q = hud._toast_queue
	if type(q) ~= "table" or #q == 0 then
		hud._toast = nil
		return
	end
	activate_toast(table.remove(q, 1))
end

--- Queue-aware toast. If a toast is already showing, append; else show immediately.
function hud.enqueue_toast(toast, opts)
	opts = opts or {}
	if type(toast) ~= "table" then return false end
	if not opts.debug_bypass then
		local scope = require("Qing_Remaster_scripts.quest.quest_run_scope")
		if not scope.allows_story_quests() then
			return false
		end
	end
	local payload = make_toast_payload(toast)
	if hud._toast then
		hud._toast_queue = hud._toast_queue or {}
		hud._toast_queue[#hud._toast_queue + 1] = payload
	else
		activate_toast(payload)
	end
	return true
end

function hud.push_toast(toast, opts)
	return hud.enqueue_toast(toast, opts)
end

function hud.clear_toast()
	hud._toast = nil
	hud._toast_queue = {}
end

function hud.set_tracker(data)
	if type(data) ~= "table" or not data.title then
		hud._tracker = nil
		return
	end
	hud._tracker = {
		title = data.title,
		objective = data.objective,
		progress = data.progress,
		side_title = data.side_title,
		side_objective = data.side_objective,
	}
end

function hud.clear_tracker()
	hud._tracker = nil
end

-- Stable HUD-space anchor near hearts (right of HP area). Does not follow heart count.
local function toast_anchor()
	local hud_offset = 0
	if Options and Options.HUDOffset then
		hud_offset = tonumber(Options.HUDOffset) or 0
	end
	local base = QUEST_HUD_LAYOUT.toast
	local dbg = hud._debug_toast_offset or Vector(0, 0)
	local x = base.X + (dbg.X or 0) + math.floor(hud_offset * 20 + 0.5)
	local y = base.Y + (dbg.Y or 0) + math.floor(hud_offset * 12 + 0.5)
	return pixel_ui.snap(Vector(x, y))
end

function hud.get_toast_layout()
	local dbg = hud._debug_title or {}
	local L = QUEST_HUD_LAYOUT
	return {
		base = Vector(L.toast.X, L.toast.Y),
		debug_offset = hud._debug_toast_offset,
		title_centered = dbg.centered,
		title_letter_spacing = dbg.letter_spacing,
		title_y_offset = dbg.y_offset,
		fade_in = L.fade_in or TOAST_FADE_IN,
		fade_out = L.fade_out or TOAST_FADE_OUT,
		enter_y = L.enter_y or TOAST_ENTER_Y,
		defaults = {
			title_centered = L.title_centered == true,
			title_letter_spacing = L.title_letter_spacing or 0,
			title_y_offset = L.title_y_offset or 0,
			ornament_y_offset = L.ornament_y_offset or 0,
			ornament_half_width = L.ornament_half_width or 24,
			body_y_offset = L.body_y_offset or 0,
			body_row_h = L.body_row_h or TOAST_ROW_H,
			fade_in = TOAST_FADE_IN,
			fade_out = TOAST_FADE_OUT,
			enter_y = TOAST_ENTER_Y,
		},
	}
end

--- Debug / Advanced: toast appear animation (fade in / hold / fade out + enter Y).
function hud.set_toast_fade(opts)
	opts = opts or {}
	if opts.fade_in ~= nil then
		QUEST_HUD_LAYOUT.fade_in = math.max(0, math.floor((tonumber(opts.fade_in) or TOAST_FADE_IN) + 0.5))
	end
	if opts.fade_out ~= nil then
		QUEST_HUD_LAYOUT.fade_out = math.max(0, math.floor((tonumber(opts.fade_out) or TOAST_FADE_OUT) + 0.5))
	end
	if opts.enter_y ~= nil then
		QUEST_HUD_LAYOUT.enter_y = math.max(0, math.floor((tonumber(opts.enter_y) or TOAST_ENTER_Y) + 0.5))
	end
end

function hud.reset_toast_fade()
	QUEST_HUD_LAYOUT.fade_in = TOAST_FADE_IN
	QUEST_HUD_LAYOUT.fade_out = TOAST_FADE_OUT
	QUEST_HUD_LAYOUT.enter_y = TOAST_ENTER_Y
end

function hud.set_debug_toast_offset(x, y)
	hud._debug_toast_offset = Vector(
		math.floor((x or 0) + 0.5),
		math.floor((y or 0) + 0.5)
	)
end

function hud.reset_debug_toast_offset()
	hud._debug_toast_offset = Vector(0, 0)
end

function hud.set_debug_title_layout(opts)
	opts = opts or {}
	local d = hud._debug_title
	if opts.centered ~= nil then d.centered = opts.centered == true end
	if opts.letter_spacing ~= nil then d.letter_spacing = math.floor((tonumber(opts.letter_spacing) or 0) + 0.5) end
	if opts.y_offset ~= nil then d.y_offset = math.floor((tonumber(opts.y_offset) or 0) + 0.5) end
	if opts.ornament_y_offset ~= nil then d.ornament_y_offset = math.floor((tonumber(opts.ornament_y_offset) or 0) + 0.5) end
	if opts.ornament_half_width ~= nil then d.ornament_half_width = math.floor((tonumber(opts.ornament_half_width) or 24) + 0.5) end
	if opts.body_y_offset ~= nil then d.body_y_offset = math.floor((tonumber(opts.body_y_offset) or 0) + 0.5) end
	if opts.body_row_h ~= nil then d.body_row_h = math.floor((tonumber(opts.body_row_h) or TOAST_ROW_H) + 0.5) end
end

function hud.get_debug_title_layout()
	local L = QUEST_HUD_LAYOUT
	local d = hud._debug_title
	return {
		centered = (d.centered ~= nil) and d.centered or (L.title_centered == true),
		letter_spacing = d.letter_spacing ~= nil and d.letter_spacing or (L.title_letter_spacing or 0),
		y_offset = d.y_offset ~= nil and d.y_offset or (L.title_y_offset or 0),
		ornament_y_offset = d.ornament_y_offset ~= nil and d.ornament_y_offset or (L.ornament_y_offset or 0),
		ornament_half_width = d.ornament_half_width ~= nil and d.ornament_half_width or (L.ornament_half_width or 24),
		body_y_offset = d.body_y_offset ~= nil and d.body_y_offset or (L.body_y_offset or 0),
		body_row_h = d.body_row_h ~= nil and d.body_row_h or (L.body_row_h or TOAST_ROW_H),
	}
end

function hud.reset_debug_title_layout()
	hud._debug_title = {
		centered = nil,
		letter_spacing = nil,
		y_offset = nil,
		ornament_y_offset = nil,
		ornament_half_width = nil,
		body_y_offset = nil,
		body_row_h = nil,
	}
end

local SAMPLE_TOAST = {
	new = {kind = "new", line1 = "新的目标", line2 = "狩猎", line3 = "继续前进"},
	update = {kind = "update", line1 = "目标更新", line2 = "陌生的相遇", line3 = "与以撒见面（可选）"},
	progress = {kind = "progress", line1 = "进度更新", line2 = "收集炼金素材", line3 = "2 / 5"},
	side = {kind = "side", line1 = "支线发现", line2 = "棋盘异变", line3 = "前往 Mines / Ashpit"},
	complete = {
		kind = "complete",
		line1 = "狩猎",
		line2 = "继续前进",
		line3 = "",
		completed = true,
	},
	optional = {
		kind = "new",
		line1 = "新的目标",
		line2 = "陌生的相遇",
		line3 = "与以撒见面（可选）",
	},
}

--- Persistent debug toast (no TTL). Independent from push_toast().
function hud.set_debug_preview(enabled, kind)
	local d = hud._debug_preview
	d.enabled = enabled == true
	if kind then
		local sample = SAMPLE_TOAST[kind] or SAMPLE_TOAST.new
		d.kind = sample.kind
		d.line1 = sample.line1
		d.line2 = sample.line2
		d.line3 = sample.line3
		d.completed = sample.completed == true
	end
end

function hud.get_debug_preview()
	return hud._debug_preview
end

--- Dev helpers: push a sample toast without playing story (timed).
--- Bypasses Run Scope so Visual Debug works inside Challenge.
function hud.debug_push_sample(kind)
	kind = kind or "new"
	local sample = SAMPLE_TOAST[kind] or SAMPLE_TOAST.new
	hud.enqueue_toast({
		kind = sample.kind,
		line1 = sample.line1,
		line2 = sample.line2,
		line3 = sample.line3,
		completed = sample.completed == true,
		duration = 90, -- logic frames @30Hz
	}, {debug_bypass = true})
end

--- Preview: complete hunt → new home encounter (queue).
function hud.debug_push_complete_then_new()
	hud.clear_toast()
	hud.enqueue_toast({
		kind = "complete",
		line1 = "狩猎",
		line2 = "继续前进",
		line3 = "",
		completed = true,
		duration = 60, -- logic frames @30Hz
	}, {debug_bypass = true})
	hud.enqueue_toast({
		kind = "new",
		line1 = "新的目标",
		line2 = "陌生的相遇",
		line3 = "与以撒见面（可选）",
		duration = 75, -- logic frames @30Hz
	}, {debug_bypass = true})
end

local function render_toast_payload(t, permanent)
	if not t then return end

	local a = 1
	local enter_y = 0
	if not permanent then
		local duration = math.max(1, t.duration or 75)
		local age = math.max(0, t.age or 0)
		local remaining = duration - age
		local fade_in = QUEST_HUD_LAYOUT.fade_in or TOAST_FADE_IN
		local fade_out = QUEST_HUD_LAYOUT.fade_out or TOAST_FADE_OUT
		local enter = QUEST_HUD_LAYOUT.enter_y or TOAST_ENTER_Y
		if age < fade_in then
			local u = age / math.max(1, fade_in)
			-- ease-out-ish
			u = 1 - (1 - u) * (1 - u)
			a = u
			enter_y = math.floor((1 - u) * enter + 0.5)
		elseif remaining < fade_out then
			a = math.max(0, remaining) / math.max(1, fade_out)
		else
			a = 1
		end
	end

	local title = hud.get_debug_title_layout()
	local pos = toast_anchor()
	local x = pos.X
	local y = pos.Y + enter_y
	local body_w = 90
	local cx = x + math.floor(body_w * 0.5)

	quest_draw.toast_header(
		cx,
		y + 3 + (title.ornament_y_offset or 0),
		t.kind,
		{half_width = title.ornament_half_width or 24, alpha = a}
	)
	y = y + 14 + (title.body_y_offset or 0)

	local col1 = KColor(1, 0.92, 0.65, a)
	local col2 = KColor(1, 1, 1, a)
	local col3 = KColor(0.85, 0.9, 1, a)
	if t.kind == "complete" then
		col1 = KColor(0.67, 0.90, 0.70, a)
	elseif t.kind == "side" then
		col1 = KColor(0.75, 0.82, 1.0, a)
	end

	local row_h = title.body_row_h or TOAST_ROW_H
	if t.completed then
		-- ✓ title, then strikethrough objective (line1/line2).
		if t.line1 ~= "" then
			y = quest_draw.completed_title(
				Vector(x, y + (title.y_offset or 0)),
				t.line1,
				{scale = SCALE, color = col1, row_h = row_h, context = "QuestHUD.toast.complete"}
			)
		end
		if t.line2 ~= "" then
			y = quest_draw.completed_text(
				Vector(x, y),
				t.line2,
				{scale = SCALE, color = col3, row_h = row_h, context = "QuestHUD.toast.complete"}
			)
		end
		if t.line3 ~= "" then
			pixel_ui.draw_text(Vector(x, y), t.line3, SCALE, col3, {context = "QuestHUD.toast"})
		end
	else
		if t.line1 ~= "" then
			local title_y = y + (title.y_offset or 0)
			local spacing = title.letter_spacing or 0
			if title.centered then
				pixel_ui.draw_text_spaced_centered(
					cx, title_y, t.line1, SCALE, col1, spacing,
					{context = "QuestHUD.toast.title"}
				)
			else
				pixel_ui.draw_text_spaced(
					Vector(x, title_y), t.line1, SCALE, col1, spacing,
					{context = "QuestHUD.toast.title"}
				)
			end
			y = y + row_h
		end
		if t.line2 ~= "" then
			pixel_ui.draw_text(Vector(x, y), t.line2, SCALE, col2, {context = "QuestHUD.toast"})
			y = y + row_h
		end
		if t.line3 ~= "" then
			pixel_ui.draw_text(Vector(x, y), t.line3, SCALE, col3, {context = "QuestHUD.toast"})
		end
	end
end

--- Advance toast lifetime on game logic frames (MC_POST_UPDATE @30Hz). Render stays draw-only.
local function update_toast()
	local t = hud._toast
	if not t then return end
	t.age = (t.age or 0) + 1
	if t.age >= (t.duration or 75) then
		pop_toast_queue()
	end
end

local function render_toast()
	render_toast_payload(hud._toast, false)
end

local function render_debug_preview_toast()
	local d = hud._debug_preview
	if not d or not d.enabled then return end
	render_toast_payload({
		kind = d.kind or "new",
		line1 = d.line1 or "",
		line2 = d.line2 or "",
		line3 = d.line3 or "",
		completed = d.completed == true or d.kind == "complete",
	}, true)
end

local TRACKER_ROW_H = 12

local function right_line(x, y, str, col)
	if not str or str == "" then return y end
	local w = pixel_ui.measure_text(str, SCALE)
	pixel_ui.draw_text(Vector(x - w, y), str, SCALE, col, {context = "QuestHUD.tracker"})
	return y + TRACKER_ROW_H
end

local function render_compact_tracker(scz, a)
	local t = hud._tracker
	local x = scz.X - 8
	local y = math.floor(scz.Y * 0.28 + 0.5)
	local line = t.title or ""
	if t.progress and t.progress ~= "" then
		line = line .. "  ·  " .. t.progress
	end
	right_line(x, y, line, KColor(1, 0.95, 0.75, a))
end

local function render_full_tracker(scz, a)
	local t = hud._tracker
	local x = scz.X - 8
	local y = math.floor(scz.Y * 0.28 + 0.5)
	y = right_line(x, y, t.title, KColor(1, 0.95, 0.75, a))
	local obj = t.objective or ""
	if t.progress and t.progress ~= "" then
		obj = obj .. "  " .. t.progress
	end
	y = right_line(x, y, obj, KColor(0.9, 0.92, 1, a * 0.95))
	if t.side_title and t.side_title ~= "" then
		y = y + 4
		y = right_line(x, y, "----", KColor(0.6, 0.6, 0.7, a * 0.5))
		y = right_line(x, y, t.side_title, KColor(0.85, 0.95, 0.85, a * 0.9))
		right_line(x, y, t.side_objective, KColor(0.8, 0.85, 0.9, a * 0.85))
	end
end

local function render_tracker(scz)
	if prefs().tracker_enabled ~= true then return end
	if not hud._tracker then return end
	local frame = Game():GetFrameCount() or 0
	if frame < (hud._tracker_boost_until or 0) then
		hud._tracker_alpha = math.min(1, (hud._tracker_alpha or 0.55) + 0.05)
	else
		hud._tracker_alpha = math.max(0.42, (hud._tracker_alpha or 0.55) - 0.01)
	end
	local a = hud._tracker_alpha
	if prefs().compact_mode then
		render_compact_tracker(scz, a)
	else
		render_full_tracker(scz, a)
	end
end

table.insert(hud.ToCall, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		if auxi.is_pause_menu_open() or hud.ending1_blocking() then return end
		update_toast()
	end,
})

-- After vanilla HUD / stage title (RGON). Fallback POST_RENDER without RGON.
local quest_hud_render_cb = (REPENTOGON and ModCallbacks.MC_POST_HUD_RENDER)
	or ModCallbacks.MC_POST_RENDER

table.insert(hud.ToCall, {
	CallBack = quest_hud_render_cb,
	params = nil,
	Function = function()
		-- Formal Toast / Tracker: Challenge blocked by push_toast + tracker snapshot.
		-- Debug persistent preview bypasses Run Scope (Visual Debug in Challenge OK).
		if auxi.is_pause_menu_open() or hud.ending1_blocking() then return end
		local scz = auxi.GetScreenSize and auxi.GetScreenSize() or Vector(480, 270)
		if hud._debug_preview and hud._debug_preview.enabled then
			render_debug_preview_toast()
		elseif hud._toast then
			render_toast()
		end
		if prefs().tracker_enabled == true then
			local room = Game():GetRoom()
			local desc = Game():GetLevel():GetCurrentRoomDesc()
			local key = desc and desc.SafeGridIndex
			if key ~= nil and key ~= hud._room_seen then
				hud._room_seen = key
				hud._tracker_boost_until = (Game():GetFrameCount() or 0) + 60
				hud._tracker_alpha = math.max(hud._tracker_alpha or 0.55, 0.85)
			end
			render_tracker(scz)
		end
		if pixel_ui.get_debug_scale_test and pixel_ui.get_debug_scale_test() then
			pixel_ui.render_scale_test(Vector(24, 40))
		end
	end,
})

table.insert(hud.myToCall, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	params = nil,
	Function = function()
		hud._toast = nil
		hud._toast_queue = {}
		hud._tracker = nil
		hud._room_seen = nil
		if hud._debug_preview then
			hud._debug_preview.enabled = false
		end
		prefs()
	end,
})

return hud
