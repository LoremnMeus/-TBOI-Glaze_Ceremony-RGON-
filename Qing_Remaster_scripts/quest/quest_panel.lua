-- Pause Quest Panel — RPG quest log on Pause surface.
--   MC_PRE_COMPLETION_MARKS_RENDER  → pause_ui.capture_completion_anchor only
--                                     (manager owns that callback; Quest does not draw there)
--   MC_POST_PAUSE_SCREEN_RENDER     → KEY_Q input + Quest Page Toggle / Paper / Content
--   MC_INPUT_ACTION                 → block PauseMenu back / nav while opened
--   MC_PRE_PAUSE_SCREEN_RENDER      → native Pause sprite Offset shift
--
-- Contract: Completion Marks callbacks provide a reliable Pause anchor only.
-- Quest UI lifecycle belongs to Pause Screen, NOT Completion Marks.
-- Do NOT redraw Quest from MC_POST_COMPLETION_MARKS_RENDER — PRE return false
-- skips POST for mod characters (Qing / Tecro / Anna / Zeiz / …).
--
-- Run Scope: Challenge runs block formal Story Quests (quest_run_scope).
-- Debug force_* / toast preview may still render; they must not advance Story.
--
-- No ScreenSize percentages. Font scale whitelist via pixel_ui (1x only).
-- No QuestProgress. Data from quest_registry + story_state.
-- Visual primitives: quest_draw.lua.
--
-- Legacy panel background assets kept on disk for fallback only:
--   resources/gfx/ui/quest/quest_panel.png
--   resources/gfx/ui/quest/quest_panel.anm2

local enums = require("Qing_Remaster_scripts.core.enums")
local registry = require("Qing_Remaster_scripts.quest.quest_registry")
local pixel_ui = require("Qing_Remaster_scripts.auxiliary.pixel_ui")
local pause_ui = require("Qing_Remaster_scripts.auxiliary.pause_ui")
local draw = require("Qing_Remaster_scripts.quest.quest_draw")

local panel = {
	ToCall = {},
	pre_ToCall = {},
	myToCall = {},
	own_key = "Quest_Panel_",

	opened = false,

	_last_layout = nil,
	_last_input = nil,
	_last_open_gate = nil,
	_last_content_bounds = nil,
	_layout_warning = nil,

	-- Physical Q edge latch (do NOT clear in open/close — only on key release / lifecycle exit).
	_q_down = false,

	-- Pause input probe (Story Test ImGui).
	_debug_pause_render_count = 0,
	_debug_q_down = false,
	_debug_q_press_count = 0,
	_debug_panel_toggles = 0,

	-- Visual → Quest UI debug preview (does not change formal pause gates permanently).
	_debug_preview = {
		force_toggle_open = false,
		force_toggle_close = false,
		force_hint = false, -- legacy alias → force_toggle_open
		force_panel = false,
		use_sample = false,
	},
}

-- Openpage (Q 任务) bookmark presentation — transient, not saved.
-- First open of a Pause session snaps to full; Q / submenu transitions animate.
local ENTRY_IN_FRAMES = 16
local ENTRY_OUT_FRAMES = 12
local ENTRY_RISE_PX = 14
local ENTRY_MAX_ALPHA = 0.95
local ENTRY_PANEL_HIDE_T = 0.35

local entry_anim = {
	progress = 1,
	target = 1,
	pause_initialized = false,
	last_render_frame = nil,
}

local function ease_out_cubic(t)
	t = math.max(0, math.min(1, t or 0))
	local u = 1 - t
	return 1 - u * u * u
end

local function ease_in_cubic(t)
	t = math.max(0, math.min(1, t or 0))
	return t * t * t
end

local function reset_entry_session()
	entry_anim.progress = 1
	entry_anim.target = 1
	entry_anim.pause_initialized = false
	entry_anim.last_render_frame = nil
end

local function snap_entry_shown()
	entry_anim.progress = 1
	entry_anim.target = 1
end

local function tick_entry_anim()
	local frame = Isaac and Isaac.GetFrameCount and Isaac.GetFrameCount() or nil
	if frame ~= nil and entry_anim.last_render_frame == frame then
		return
	end
	entry_anim.last_render_frame = frame

	local tgt = entry_anim.target or 0
	local cur = entry_anim.progress or 0
	if math.abs(tgt - cur) < 0.0005 then
		entry_anim.progress = tgt
		return
	end
	local frames = (tgt > cur) and ENTRY_IN_FRAMES or ENTRY_OUT_FRAMES
	if frames < 1 then frames = 1 end
	local step = 1 / frames
	if tgt > cur then
		cur = math.min(tgt, cur + step)
	else
		cur = math.max(tgt, cur - step)
	end
	entry_anim.progress = cur
end

--- Visual params from entry progress + paper open_amount hide weight.
local function entry_visual_params(opts)
	opts = opts or {}
	local progress = entry_anim.progress or 0
	local target = entry_anim.target or 0
	local eased
	if target < progress then
		eased = ease_in_cubic(progress)
	else
		eased = ease_out_cubic(progress)
	end
	local alpha = ENTRY_MAX_ALPHA * eased
	local offset_y = ENTRY_RISE_PX * (1 - eased)
	if opts.static_full then
		alpha = opts.force_alpha or 1
		offset_y = 0
	end
	local panel_t = pause_ui.get_quest_open_amount() or 0
	local hide_factor = 1 - math.min(1, panel_t / ENTRY_PANEL_HIDE_T)
	alpha = alpha * hide_factor
	return alpha, offset_y, hide_factor
end

-- Quest Panel: only integer 1x. 0.5 not approved for this surface yet.
local SCALE = 1
local MARKER_X = 10
local TEXT_X = 24
local SIDE_ROW_H = 24
-- Soft overflow alarm (Pause-local Y past this → Debug warning). Not auto-fit.
local SAFE_BOTTOM_LOCAL = 160

-- While open: own PauseMenu so vanilla selection does not move underneath.
-- Q is physical KEY_Q — not handled here. No in-panel settings selection.
local BLOCKED_WHEN_OPEN = {
	[ButtonAction.ACTION_MENUUP] = true,
	[ButtonAction.ACTION_MENUDOWN] = true,
	[ButtonAction.ACTION_MENULEFT] = true,
	[ButtonAction.ACTION_MENURIGHT] = true,
	[ButtonAction.ACTION_MENUCONFIRM] = true,
	[ButtonAction.ACTION_MENUBACK] = true,
}

local function story_state()
	local ok, mod = pcall(require, "Qing_Remaster_scripts.story.story_state")
	if ok then return mod end
	return nil
end

local function quest_hud()
	local ok, mod = pcall(require, "Qing_Remaster_scripts.quest.quest_hud")
	if ok then return mod end
	return nil
end

local function t(zh, en)
	if registry.lang() == "en" then return en else return zh end
end

local function get_prefs()
	local hud = quest_hud()
	if hud and hud.get_prefs then
		return hud.get_prefs()
	end
	return {tracker_enabled = false, compact_mode = false}
end

function panel.close()
	-- Do not clear _q_down here: Q may still be held; clearing would re-edge and flash open.
	panel.opened = false
	pause_ui.set_quest_open_amount(0)
	-- Openpage rises again while paper retracts (same Pause session).
	if entry_anim.pause_initialized then
		entry_anim.target = 1
	end
end

function panel.open()
	panel.opened = true
	pause_ui.set_quest_open_amount(1)
	-- Openpage exits immediately with paper expand — do not wait for exit finish.
	entry_anim.target = 0
end

local function panel_reveal_t()
	local prev = panel._debug_preview or {}
	if prev.force_panel then
		return 1
	end
	return pause_ui.get_quest_open_amount() or 0
end

local function should_draw_panel()
	local prev = panel._debug_preview or {}
	if prev.force_panel then return true end
	if panel.opened then return true end
	if (pause_ui.get_quest_open_amount() or 0) > 0.02 then
		return true
	end
	return false
end

local function reset_pause_input_latch()
	panel._q_down = false
	panel._debug_q_down = false
end

local function ending_blocking()
	local hud = quest_hud()
	return hud and hud.ending1_blocking and hud.ending1_blocking() == true
end

--- Hint / entry: pause main page + quest revealed. Independent of main objective.
function panel.can_show_hint()
	local scope = require("Qing_Remaster_scripts.quest.quest_run_scope")
	if not scope.allows_story_quests() then
		return false, "run_scope_blocked"
	end
	if not pause_ui.is_in_run() then return false, "not_in_run" end
	if not pause_ui.is_open() then return false, "pause_closed" end
	if not pause_ui.is_main_page() then return false, "not_main_pause" end
	if ending_blocking() then return false, "ending1_blocking" end
	local st = story_state()
	if not st then return false, "no_story" end
	if not registry.is_quest_system_revealed(st) then
		return false, "not_revealed"
	end
	return true, nil
end

--- Challenge / blocked scope: no Openpage, no Q, no open_amount / Pause shift.
function panel.enforce_run_scope()
	local scope = require("Qing_Remaster_scripts.quest.quest_run_scope")
	if scope.allows_story_quests() then
		return false
	end
	if panel.opened then
		panel.close()
	else
		pause_ui.set_quest_open_amount(0)
	end
	reset_pause_input_latch()
	return true
end

-- Compat alias for Story Test.
function panel.can_show_entry()
	return panel.can_show_hint()
end

-- Edge-detect physical Q. Prefer IsButtonPressed + latch over IsButtonTriggered
-- so Pause render / other consumers cannot steal the edge.
local function poll_pause_q()
	local down = Input.IsButtonPressed(Keyboard.KEY_Q, 0)
	panel._debug_q_down = down == true

	if down then
		if panel._q_down then
			return false
		end
		panel._q_down = true
		panel._debug_q_press_count = (panel._debug_q_press_count or 0) + 1
		panel._last_input = "KEY_Q"
		return true
	end

	panel._q_down = false
	return false
end

local function begin_layout(layout, opts)
	opts = opts or {}
	local reveal = opts.reveal_t
	if reveal == nil then reveal = 1 end
	if reveal < 0 then reveal = 0 end
	if reveal > 1 then reveal = 1 end
	local width = layout.quest_width or 190
	local origin = layout.quest_origin or Vector(0, 0)
	local half = math.floor(width / 2)
	return {
		cx = origin.X,
		y = origin.Y,
		width = width,
		left = origin.X - half,
		right = origin.X + half,
		min_x = nil,
		min_y = nil,
		max_x = nil,
		max_y = nil,
		origin = origin,
		reveal_t = reveal,
		alpha = reveal,
	}
end

local function finish_layout(ctx, layout)
	local bounds = nil
	if ctx.min_x and ctx.min_y and ctx.max_x and ctx.max_y then
		bounds = {
			left = ctx.min_x,
			top = ctx.min_y,
			right = ctx.max_x,
			bottom = ctx.max_y,
			width = ctx.max_x - ctx.min_x,
			height = ctx.max_y - ctx.min_y,
		}
	end
	panel._last_content_bounds = bounds
	if pause_ui.set_last_content_bounds then
		pause_ui.set_last_content_bounds(bounds)
	end

	panel._layout_warning = nil
	if bounds and layout and layout.anchor and layout.anchor.origin then
		local scale_y = (layout.anchor.scale and layout.anchor.scale.Y) or 1
		if scale_y == 0 then scale_y = 1 end
		local local_bottom = (bounds.bottom - layout.anchor.origin.Y) / scale_y
		if local_bottom > SAFE_BOTTOM_LOCAL then
			panel._layout_warning = {
				kind = "overflow_bottom",
				amount = math.floor(local_bottom - SAFE_BOTTOM_LOCAL + 0.5),
			}
		end
	end
	return bounds
end

local function render_paper(layout, content_bounds, reveal)
	if reveal <= 0.01 then return nil end
	local rect = pause_ui.get_quest_paper_rect(layout, content_bounds, reveal)
	if not rect then return nil end
	draw.paper_panel(rect, {
		reveal = reveal,
		alpha = reveal,
		style = draw.get_paper_style and draw.get_paper_style() or nil,
	})
	return rect
end

local function material_marker_state(detail)
	if not detail then return "unknown" end
	if detail.state == "completed" then return "completed" end
	if detail.state == "unknown" then return "unknown" end
	-- known → numbered hollow (not "current"; five materials have no single tracker target)
	return "known"
end

local function side_marker_state(side)
	local stage = side and side.stage
	if stage == "climax" or stage == "boss" then return "progress" end
	if stage == "progressing" or stage == "deep" then return "progress" end
	return "known"
end

local function render_page_toggle(layout, kind, alpha, offset_y)
	if not layout then return end
	local pos
	if kind == "close" then
		pos = layout.toggle_close_pos
	else
		pos = layout.toggle_open_pos or layout.hint_pos
	end
	if not pos then return end
	if draw.page_toggle then
		draw.page_toggle(pos, kind, {
			alpha = alpha or 1,
			offset_y = offset_y or 0,
		})
	end
end

local function render_openpage(layout, opts)
	opts = opts or {}
	local alpha, offset_y = entry_visual_params(opts)
	if alpha <= 0.01 then return end
	render_page_toggle(layout, "open", alpha, offset_y)
end

local function sample_panel_view()
	return {
		chapter_id = "chapter1",
		chapter_title = t("第一章", "Chapter 1"),
		main = {
			id = "chapter1.collect_materials",
			title = t("收集炼金素材", "Collect Alchemy Materials"),
			objective = t("寻找五种炼金素材", "Find five alchemy materials"),
			progress = {current = 2, target = 5, text = "2 / 5"},
			details = {
				{id = "coin", title = t("贪婪银行", "Greed Bank"), state = "known"},
				{id = "glaze", title = t("镜中异象", "Mirror Vision"), state = "completed"},
				{id = "stone", title = t("棋盘异变", "Chess Shift"), state = "known"},
				{id = "wind", title = t("风暴异变", "Storm Shift"), state = "unknown"},
				{id = "phase_anchor", title = t("相位锚", "Phase Anchor"), state = "unknown"},
			},
			chapter_complete = false,
		},
		sides = {
			{
				id = "chapter1.stone",
				title = t("棋盘异变", "Chess Shift"),
				objective = t("找到黑兵", "Find the black pawn"),
				stage = "progressing",
			},
		},
		completed_chapters = {},
	}
end

local function render_chapter(ctx, view)
	if not view or not view.chapter_title or view.chapter_title == "" then
		return
	end
	pixel_ui.draw_text_centered(
		ctx.cx, ctx.y, view.chapter_title, SCALE, draw.COLORS.chapter,
		{context = "QuestPanel.chapter"}
	)
	draw.touch_text(ctx, ctx.cx - 30, ctx.y, view.chapter_title, SCALE)
	ctx.y = ctx.y + 14
end

local function render_main_quest(ctx, main)
	if not main then return end

	local title_y = ctx.y
	pixel_ui.draw_text(
		Vector(ctx.left, title_y),
		main.title or "",
		SCALE,
		draw.COLORS.title,
		{context = "QuestPanel.main.title"}
	)
	draw.touch_text(ctx, ctx.left, title_y, main.title or "", SCALE)

	if main.progress and main.progress.text then
		pixel_ui.draw_text_right(
			Vector(ctx.right, title_y),
			main.progress.text,
			SCALE,
			draw.COLORS.current,
			{context = "QuestPanel.main.progress"}
		)
		local pw = pixel_ui.measure_text(main.progress.text, SCALE)
		draw.touch_bounds(ctx, ctx.right - pw, title_y, ctx.right, title_y + 12)
	end

	ctx.y = ctx.y + 12

	pixel_ui.draw_text(
		Vector(ctx.left + 2, ctx.y),
		main.objective or "",
		SCALE,
		draw.COLORS.text,
		{context = "QuestPanel.main.objective"}
	)
	draw.touch_text(ctx, ctx.left + 2, ctx.y, main.objective or "", SCALE)
	ctx.y = ctx.y + 14

	if main.panel_notes then
		for _, note in ipairs(main.panel_notes) do
			pixel_ui.draw_text(
				Vector(ctx.left + 4, ctx.y),
				note,
				SCALE,
				draw.COLORS.note,
				{context = "QuestPanel.main.note"}
			)
			draw.touch_text(ctx, ctx.left + 4, ctx.y, note, SCALE)
			ctx.y = ctx.y + 12
		end
	end
end

local function render_material_steps(ctx, details)
	if not details or #details == 0 then return end
	local marker_x = ctx.left + MARKER_X
	local text_x = ctx.left + TEXT_X
	local row_h = draw.STEP_ROW_H

	for i, detail in ipairs(details) do
		local cy = ctx.y + 5
		local state = material_marker_state(detail)
		local number = (state == "known") and i or nil

		draw.marker(marker_x, cy, state, number, ctx)

		pixel_ui.draw_text(
			Vector(text_x, ctx.y),
			detail.title or "",
			SCALE,
			draw.material_text_color(state),
			{context = "QuestPanel.material"}
		)
		draw.touch_text(ctx, text_x, ctx.y, detail.title or "", SCALE)

		if i < #details then
			draw.connector(marker_x, cy + 6, cy + row_h - 5, ctx)
		end

		ctx.y = ctx.y + row_h
	end
	ctx.y = ctx.y + 4
end

local function render_side_quests(ctx, sides)
	if not sides or #sides == 0 then return end
	ctx.y = ctx.y + 2
	draw.section_title(ctx, t("已发现事件", "Discovered Events"))

	local marker_x = ctx.left + MARKER_X
	local text_x = ctx.left + TEXT_X

	for i, side in ipairs(sides) do
		local cy = ctx.y + 5
		local state = side_marker_state(side)
		draw.marker(marker_x, cy, state, i, ctx)

		pixel_ui.draw_text(
			Vector(text_x, ctx.y),
			side.title or "",
			SCALE,
			draw.COLORS.text,
			{context = "QuestPanel.side.title"}
		)
		draw.touch_text(ctx, text_x, ctx.y, side.title or "", SCALE)

		pixel_ui.draw_text(
			Vector(text_x, ctx.y + 11),
			side.objective or "",
			SCALE,
			draw.COLORS.secondary,
			{context = "QuestPanel.side.objective"}
		)
		draw.touch_text(ctx, text_x, ctx.y + 11, side.objective or "", SCALE)

		-- No vertical connectors between independent side events.
		ctx.y = ctx.y + SIDE_ROW_H
	end
	ctx.y = ctx.y + 2
end

local function render_completed_chapters(ctx, rows)
	if not rows or #rows == 0 then return end
	ctx.y = ctx.y + 2
	draw.section_title(ctx, t("章节完成", "Chapter Complete"))
	for _, row in ipairs(rows) do
		local label = (row.title or row.id or "")
		local marker_x = ctx.left + MARKER_X
		draw.marker(marker_x, ctx.y + 5, "completed", nil, ctx)
		pixel_ui.draw_text(
			Vector(ctx.left + TEXT_X, ctx.y),
			label,
			SCALE,
			draw.COLORS.completed,
			{context = "QuestPanel.completed"}
		)
		draw.touch_text(ctx, ctx.left + TEXT_X, ctx.y, label, SCALE)
		ctx.y = ctx.y + 14
	end
	ctx.y = ctx.y + 2
end

local function render_footer(_ctx)
	-- Player-facing close text removed; Close tab sprite is the only close cue.
end

local function render_panel(layout)
	local view
	local prev = panel._debug_preview
	if prev and prev.use_sample then
		view = sample_panel_view()
	else
		local st = story_state()
		view = registry.resolve_panel_view(st)
	end
	if not view then
		if prev and prev.force_panel then
			view = sample_panel_view()
		else
			return
		end
	end

	local reveal = panel_reveal_t()
	if reveal <= 0.01 then return end

	-- Paper behind content (covers Seed). Height uses last-frame content bounds.
	render_paper(layout, panel._last_content_bounds, reveal)
	if reveal < 0.12 then
		return
	end

	local ctx = begin_layout(layout, {reveal_t = reveal})
	draw.header(ctx, t("任 务", "QUEST"))
	render_chapter(ctx, view)

	local main = view.main
	if main and main.chapter_complete then
		render_completed_chapters(ctx, view.completed_chapters)
		if main.objective and main.objective ~= "" then
			pixel_ui.draw_text_centered(
				ctx.cx, ctx.y, main.objective, SCALE, draw.COLORS.secondary,
				{context = "QuestPanel.complete.objective"}
			)
			draw.touch_text(ctx, ctx.cx - 40, ctx.y, main.objective, SCALE)
			ctx.y = ctx.y + 14
		end
	else
		render_main_quest(ctx, main)
		if main and main.details then
			render_material_steps(ctx, main.details)
		end
		if view.sides and #view.sides > 0 then
			render_side_quests(ctx, view.sides)
		end
	end

	render_footer(ctx)
	finish_layout(ctx, layout)
	-- Close tab on top of paper + text (bookmark on the page edge).
	render_page_toggle(layout, "close", reveal)
end

-- Apply Pause sprite shift BEFORE engine draws Pause body/stats.
if REPENTOGON and ModCallbacks.MC_PRE_PAUSE_SCREEN_RENDER then
	table.insert(panel.pre_ToCall, {
		CallBack = ModCallbacks.MC_PRE_PAUSE_SCREEN_RENDER,
		params = nil,
		Function = function(_, pause_body, pause_stats)
			if pause_ui.is_in_run() then
				local scope = require("Qing_Remaster_scripts.quest.quest_run_scope")
				if not scope.allows_story_quests() then
					-- No formal Quest shift in Challenge (Debug force_panel may re-open later).
					if not (panel._debug_preview and panel._debug_preview.force_panel) then
						pause_ui.set_quest_open_amount(0)
					end
				end
				pause_ui.tick_content_shift(pause_body, pause_stats)
			end
		end,
	})
end

local function try_build_pause_layout()
	local anchor = pause_ui.get_completion_anchor and pause_ui.get_completion_anchor()
	if not anchor or not anchor.position then
		return nil
	end
	local layout = pause_ui.build_layout(anchor.position, anchor.scale)
	panel._last_layout = layout
	return layout
end

--- Drive Openpage target for this Pause frame. First session show snaps full (no rise).
local function update_openpage_target(want_show, opts)
	opts = opts or {}
	if opts.static_preview then
		-- Force preview: snap once to full; Replay may set progress=0 then rise once.
		if not entry_anim.pause_initialized then
			entry_anim.pause_initialized = true
			snap_entry_shown()
		else
			entry_anim.target = 1
		end
		return
	end
	if want_show then
		if not entry_anim.pause_initialized then
			-- First Pause main-page show this session: sit with the menu, do not float up.
			entry_anim.pause_initialized = true
			snap_entry_shown()
		else
			entry_anim.target = 1
		end
	else
		entry_anim.target = 0
	end
end

-- Pause-surface input + Quest UI draw (after vanilla Pause / Seed / Marks).
-- Anchor comes from PRE_COMPLETION_MARKS capture; never draw from POST marks.
if REPENTOGON and ModCallbacks.MC_POST_PAUSE_SCREEN_RENDER then
	table.insert(panel.ToCall, {
		CallBack = ModCallbacks.MC_POST_PAUSE_SCREEN_RENDER,
		params = nil,
		Function = function(_, _pause_body, _pause_stats)
			panel._debug_pause_render_count = (panel._debug_pause_render_count or 0) + 1

			if not pause_ui.is_in_run() then
				reset_pause_input_latch()
				reset_entry_session()
				return
			end

			-- Challenge / blocked scope: kill Q, Openpage, open_amount, Pause shift.
			-- Debug force_* preview may still draw below when force flags are set.
			if panel.enforce_run_scope() then
				local prev = panel._debug_preview or {}
				local force = prev.force_toggle_open == true
					or prev.force_toggle_close == true
					or prev.force_hint == true
					or prev.force_panel == true
				if not force then
					panel._last_open_gate = {ok = false, reason = "run_scope_blocked"}
					reset_entry_session()
					return
				end
			end

			-- Pause submenu (options / etc.): exit Openpage if still rendering; no Q.
			if not pause_ui.is_main_page() then
				reset_pause_input_latch()
				if panel.opened then
					panel.opened = false
					pause_ui.set_quest_open_amount(0)
				end
				entry_anim.target = 0
				tick_entry_anim()
				if (entry_anim.progress or 0) > 0.01 then
					local layout = try_build_pause_layout()
					if layout then
						render_openpage(layout)
					end
				end
				return
			end

			if ending_blocking() then
				reset_pause_input_latch()
				if panel.opened then
					panel.close()
				end
				entry_anim.target = 0
				tick_entry_anim()
				reset_entry_session()
				return
			end

			local prev = panel._debug_preview or {}
			local force_open = prev.force_toggle_open == true or prev.force_hint == true
			local force_close = prev.force_toggle_close == true
			local force_panel = prev.force_panel == true
			local force = force_open or force_close or force_panel
			local ok, reason = panel.can_show_hint()
			if not ok and not force then
				reset_pause_input_latch()
				panel._last_open_gate = {ok = false, reason = reason}
				if panel.opened then
					panel.close()
				else
					pause_ui.set_quest_open_amount(0)
				end
				entry_anim.target = 0
				tick_entry_anim()
				if reason == "pause_closed" or reason == "not_in_run" then
					reset_entry_session()
				end
				return
			end

			if force_panel and not panel.opened then
				panel.open()
			elseif force_panel then
				pause_ui.set_quest_open_amount(1)
				entry_anim.target = 0
			end

			if ok and poll_pause_q() then
				panel._last_open_gate = {ok = true, reason = nil}
				if panel.opened then
					panel.close()
				else
					panel.open()
				end
				panel._debug_panel_toggles = (panel._debug_panel_toggles or 0) + 1
				if Isaac and Isaac.DebugString then
					Isaac.DebugString(
						"[QuestPanel] KEY_Q; opened=" .. tostring(panel.opened)
					)
				end
			end

			-- Openpage wants to show when hint allowed (or force open) and paper is not the focus.
			-- Do NOT gate on should_draw_panel()==false — that waits for full paper retract.
			local want_openpage = (ok or force_open) and not panel.opened and not force_panel
			update_openpage_target(want_openpage, {static_preview = force_open and not panel.opened})
			tick_entry_anim()

			-- Unified Quest draw for vanilla + all self-drawn completion characters.
			if not ok and not force_open and not force_close and not force_panel
				and not panel.opened and not should_draw_panel()
				and (entry_anim.progress or 0) <= 0.01 then
				return
			end

			local layout = try_build_pause_layout()
			if not layout then
				return
			end

			if should_draw_panel() then
				render_panel(layout)
			end

			-- Openpage: animate with paper; force preview draws static full when panel closed.
			if force_open and not panel.opened and not should_draw_panel() then
				render_openpage(layout, {static_full = true, force_alpha = 1})
			elseif (ok or force_open or (entry_anim.progress or 0) > 0.01) and not force_panel then
				render_openpage(layout)
			end

			if force_close and not should_draw_panel() then
				render_page_toggle(layout, "close", 1)
			end
			pause_ui.render_debug_overlay(layout, panel._last_content_bounds)
		end,
	})
end

-- Full Pause exit is not guaranteed to keep POST_PAUSE_SCREEN_RENDER; clear session here.
table.insert(panel.ToCall, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		if entry_anim.pause_initialized and not pause_ui.is_open() then
			reset_entry_session()
			if panel.opened then
				panel.opened = false
				pause_ui.set_quest_open_amount(0)
			end
			reset_pause_input_latch()
		end
	end,
})

-- While opened: block PauseMenu navigation / back. Read-only log — no settings UI.
table.insert(panel.pre_ToCall, {
	CallBack = ModCallbacks.MC_INPUT_ACTION,
	params = nil,
	priority = -500,
	Function = function(_, _ent, hook, button)
		if not panel.opened then
			return
		end

		if not BLOCKED_WHEN_OPEN[button] then
			return
		end

		if hook == InputHook.IS_ACTION_TRIGGERED then
			if button == ButtonAction.ACTION_MENUBACK then
				panel._last_input = "ACTION_MENUBACK"
				panel.close()
				return false
			end
			-- Swallow up/down/left/right/confirm so Pause menu does not move.
			panel._last_input = "ACTION_MENU_BLOCKED"
			return false
		end

		if hook == InputHook.IS_ACTION_PRESSED then
			return false
		end

		if hook == InputHook.GET_ACTION_VALUE then
			return 0
		end
	end,
})

table.insert(panel.ToCall, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	params = nil,
	Function = function()
		pause_ui.set_in_run(true)
		panel.opened = false
		pause_ui.set_quest_open_amount(0)
		reset_entry_session()
		panel.enforce_run_scope()
		reset_pause_input_latch()
		panel._debug_pause_render_count = 0
		panel._debug_q_press_count = 0
		panel._debug_panel_toggles = 0
		panel._last_content_bounds = nil
		panel._layout_warning = nil
	end,
})

table.insert(panel.ToCall, {
	CallBack = ModCallbacks.MC_PRE_GAME_EXIT,
	params = nil,
	Function = function()
		pause_ui.set_in_run(false)
		panel.opened = false
		pause_ui.set_quest_open_amount(0)
		reset_entry_session()
		reset_pause_input_latch()
	end,
})

table.insert(panel.ToCall, {
	CallBack = ModCallbacks.MC_POST_GAME_END,
	params = nil,
	Function = function()
		pause_ui.set_in_run(false)
		panel.opened = false
		pause_ui.set_quest_open_amount(0)
		reset_entry_session()
		reset_pause_input_latch()
	end,
})

table.insert(panel.myToCall, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	params = nil,
	Function = function()
		panel.opened = false
		pause_ui.set_quest_open_amount(0)
		reset_entry_session()
		panel.enforce_run_scope()
		reset_pause_input_latch()
	end,
})

function panel.is_open()
	return panel.opened == true
end

function panel.set_debug_preview(opts)
	opts = opts or {}
	local d = panel._debug_preview
	if opts.force_toggle_open ~= nil then d.force_toggle_open = opts.force_toggle_open == true end
	if opts.force_toggle_close ~= nil then d.force_toggle_close = opts.force_toggle_close == true end
	if opts.force_hint ~= nil then
		d.force_hint = opts.force_hint == true
		d.force_toggle_open = d.force_hint
	end
	if opts.force_panel ~= nil then d.force_panel = opts.force_panel == true end
	if opts.use_sample ~= nil then d.use_sample = opts.use_sample == true end
	if d.force_panel then
		panel.open()
	end
end

function panel.get_debug_preview()
	return panel._debug_preview
end

function panel.reset_debug_preview()
	panel._debug_preview.force_toggle_open = false
	panel._debug_preview.force_toggle_close = false
	panel._debug_preview.force_hint = false
	panel._debug_preview.force_panel = false
	panel._debug_preview.use_sample = false
	panel.opened = false
	pause_ui.set_quest_open_amount(0)
	snap_entry_shown()
end

--- Debug: replay Openpage rise (does not loop; force preview stays static by default).
function panel.replay_openpage_anim()
	entry_anim.pause_initialized = true
	entry_anim.progress = 0
	entry_anim.target = 1
	entry_anim.last_render_frame = nil
end

function panel.get_openpage_anim_snapshot()
	return {
		progress = entry_anim.progress or 0,
		target = entry_anim.target or 0,
		pause_initialized = entry_anim.pause_initialized == true,
		in_frames = ENTRY_IN_FRAMES,
		out_frames = ENTRY_OUT_FRAMES,
		rise_px = ENTRY_RISE_PX,
	}
end

function panel.get_content_bounds()
	return panel._last_content_bounds
end

function panel.get_layout_warning()
	return panel._layout_warning
end

function panel.get_audit_snapshot()
	local st = story_state()
	local ok, reason = panel.can_show_hint()
	local view = registry.resolve_panel_view(st)
	local prefs = get_prefs()
	local layout = panel._last_layout
	local bounds = panel._last_content_bounds
	local pause_audit = pause_ui.get_audit_snapshot()
	return {
		opened = panel.opened,
		last_input = panel._last_input,
		last_open_gate = panel._last_open_gate,
		pause_render_count = panel._debug_pause_render_count or 0,
		q_physically_down = panel._debug_q_down == true,
		q_press_count = panel._debug_q_press_count or 0,
		panel_toggles = panel._debug_panel_toggles or 0,
		openpage_anim = panel.get_openpage_anim_snapshot(),
		entry_ok = ok == true,
		entry_reason = reason,
		revealed = st and registry.is_quest_system_revealed(st) or false,
		tracker_enabled = prefs.tracker_enabled == true,
		compact_mode = prefs.compact_mode == true,
		font_scale = SCALE,
		panel_view = view,
		pause = pause_audit,
		layout = layout and {
			hint_x = layout.hint_pos and layout.hint_pos.X,
			hint_y = layout.hint_pos and layout.hint_pos.Y,
			quest_x = layout.quest_origin and layout.quest_origin.X,
			quest_y = layout.quest_origin and layout.quest_origin.Y,
			quest_width = layout.quest_width,
			quest_local_x = layout.quest_local_final and layout.quest_local_final.X,
			quest_local_y = layout.quest_local_final and layout.quest_local_final.Y,
			variant = layout.anchor and layout.anchor.variant,
		} or nil,
		content_bounds = bounds,
		layout_warning = panel._layout_warning,
		pixel_violations = #pixel_ui.get_violations(),
	}
end

return panel
