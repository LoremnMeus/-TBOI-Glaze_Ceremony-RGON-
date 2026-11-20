-- 放逐证明屏幕面板。本地坐标 420×268，绘制时乘同一套 scale。
-- 只报告 open_catalog / enter_border / banish_selected / cancel。
-- 不调用 remove_banish、RemoveCollectible、Trans_to。
-- 正式底图是完整文书，锚点在面板中心 (210,134)，不再叠加共用外框。
--   resources/gfx/mimics/Exoneration/Exo_Menu.anm2
--   resources/gfx/mimics/Exoneration/Exo_Panel.anm2
-- 底图加载失败时保留程序化占位。导航和业务动作不读取绘制坐标。

local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local hud = require("Qing_Remaster_scripts.auxiliary.ui")
local pixel_ui = require("Qing_Remaster_scripts.auxiliary.pixel_ui")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")

local M = {
	PANEL_W = 420,
	PANEL_H = 268,
	COLS = 10,
	ROWS = 5,
	PAGE_SIZE = 50,
	CELL = 32,
	NAV_REPEAT_INITIAL = 22,
	NAV_REPEAT_INTERVAL = 6,
	assets = {
		frame = nil,
		menu_overlay = nil,
		catalog_overlay = nil,
		cursor = nil,
		page_arrow = nil,
		stamp = nil,
		icon_banish = nil,
		icon_border = nil,
	},
}

local KEY = "ExonerationUI_state"
local DIR_PRIORITY = { 6, 7, 4, 5 }

local function zh_lang()
	local language = Options and Options.Language or "en"
	return language ~= "en"
end

local function text(zh, en)
	if zh_lang() then
		return zh
	end
	return en
end

local function state_of(player)
	if not player or not player.GetData then
		return nil
	end
	local st = player:GetData()[KEY]
	if type(st) ~= "table" or st.open ~= true then
		return nil
	end
	return st
end

function M.set_assets(next_assets)
	if type(next_assets) ~= "table" then
		return M.assets
	end
	for name, value in pairs(next_assets) do
		if M.assets[name] ~= nil or name == "frame" or name == "menu_overlay" or name == "catalog_overlay" or name == "cursor" or name == "page_arrow" or name == "stamp" or name == "icon_banish" or name == "icon_border" then
			M.assets[name] = value
		end
	end
	return M.assets
end

local function fresh_state(model)
	return {
		open = true,
		page = "menu",
		menu_index = 1,
		catalog_page = 1,
		catalog_index = 1,
		catalog_focus = "items",
		catalog_column = 0,
		opening_frames = 8,
		closing_frames = 0,
		stamp_frames = 0,
		page_anim = 0,
		page_anim_dir = 0,
		holds = {},
		model = model or {},
		committed = false,
		dismiss = false,
	}
end

function M.open(player, model)
	if not player or not player.GetData then
		return nil
	end
	local st = fresh_state(model)
	player:GetData()[KEY] = st
	return st
end

function M.close(player)
	if player and player.GetData then
		player:GetData()[KEY] = nil
	end
end

function M.is_open(player)
	return state_of(player) ~= nil
end

function M.is_locked(player)
	local st = state_of(player)
	if not st then
		return false
	end
	return st.ceremony ~= nil or st.committed == true or (st.stamp_frames or 0) > 0 or (st.closing_frames or 0) > 0
end

function M.ready_to_dismiss(player)
	local st = state_of(player)
	return st ~= nil and st.dismiss == true
end

function M.set_model(player, model)
	local st = state_of(player)
	if st and type(model) == "table" then
		st.model = model
	end
end

function M.show_page(player, page)
	local st = state_of(player)
	if not st or st.committed then
		return
	end
	if page == "catalog" then
		st.page = "catalog"
		st.catalog_page = 1
		st.catalog_index = 1
		st.catalog_focus = "items"
		st.catalog_column = 0
		st.page_anim = 0
		st.page_anim_dir = 0
		st.holds = {}
		st.ceremony = nil
		st.ceremony_t = nil
		st.ceremony_frame = nil
		st.ceremony_ids = nil
		st.verdict_id = nil
		st.commit_sent = nil
		st.commit_done = nil
		st.verdict_failed = nil
		st.stamp_sounded = nil
		st.want_stamp_sound = nil
		st.stamp_frames = 0
	elseif page == "menu" then
		st.page = "menu"
	end
end

-- 判决演出按 Game 帧推进（30Hz）。105 帧 = 3.5 秒。
local CEREMONY_DISMISS = 105
local VERDICT_X = 78
local VERDICT_Y = 86
local VERDICT_SIZE = 40
local STAMP_START_X = 388
local STAMP_START_Y = 244
local STAMP_END_X = 322
local STAMP_END_Y = 174
local STAMP_RADIUS = 29
local BANISHED_ICON_ALPHA = 0.4

local function ceremony_phase(t)
	if t < 15 then
		return "clear_icons"
	end
	if t < 33 then
		return "move_selected"
	end
	if t < 66 then
		return "show_verdict"
	end
	if t < 81 then
		return "stamp_enter"
	end
	if t < 97 then
		return "stamp_hold"
	end
	return "closing"
end

local function smooth(t)
	if t <= 0 then
		return 0
	end
	if t >= 1 then
		return 1
	end
	return t * t * (3 - 2 * t)
end

function M.begin_verdict(player, collectible_id)
	local st = state_of(player)
	local id = tonumber(collectible_id)
	if not st or st.ceremony or not id then
		return false
	end
	local art = M.assets.catalog_overlay ~= nil
	local step = art and 26 or 32
	local origin_x = art and 93 or 66
	local origin_y = art and 75 or 64
	local index = st.catalog_index or 1
	local list = st.model and st.model.candidate_ids
	if type(list) ~= "table" then
		list = {}
	end
	local page = st.catalog_page or 1
	local pages = math.max(1, math.ceil(math.max(#list, 1) / M.PAGE_SIZE))
	if #list <= 0 then
		pages = 1
	end
	if page < 1 then
		page = 1
	elseif page > pages then
		page = pages
	end
	local start = (page - 1) * M.PAGE_SIZE
	local count = math.max(0, math.min(M.PAGE_SIZE, #list - start))
	local snap = {}
	for i = 1, count do
		snap[i] = list[start + i]
	end
	local col = (index - 1) % M.COLS
	local row = math.floor((index - 1) / M.COLS)
	st.committed = true
	st.ceremony = "clear_icons"
	st.ceremony_t = 0
	st.ceremony_frame = Game():GetFrameCount()
	st.ceremony_ids = snap
	st.ceremony_index = index
	st.ceremony_art = art
	st.verdict_id = id
	st.from_x = origin_x + col * step
	st.from_y = origin_y + row * step
	st.from_size = art and 24 or 28
	st.commit_sent = false
	st.commit_done = false
	st.verdict_failed = false
	st.stamp_sounded = false
	st.want_stamp_sound = nil
	return true
end

function M.finish_commit(player, ok)
	local st = state_of(player)
	if not st or not st.ceremony then
		return
	end
	st.commit_done = true
	if ok == true then
		st.want_stamp_sound = true
		return
	end
	st.verdict_failed = true
	if (st.ceremony_t or 0) < 97 then
		st.ceremony_t = 97
		st.ceremony = "closing"
	end
end

function M.begin_close(player)
	local st = state_of(player)
	if not st or st.dismiss or st.ceremony or (st.stamp_frames or 0) > 0 then
		return
	end
	if (st.closing_frames or 0) <= 0 then
		st.closing_frames = 6
	end
end

local function play(id, volume, pitch)
	if not id or not sound_tracker or not sound_tracker.PlayStackedSound then
		return
	end
	sound_tracker.PlayStackedSound(id, volume or 1, pitch or 1, false, 0, 2)
end

local function page_total(count)
	if count <= 0 then
		return 1
	end
	return math.ceil(count / M.PAGE_SIZE)
end

local function page_span(count, page)
	local pages = page_total(count)
	if page < 1 then
		page = 1
	elseif page > pages then
		page = pages
	end
	local start = (page - 1) * M.PAGE_SIZE
	local n = math.max(0, math.min(M.PAGE_SIZE, count - start))
	return page, start, n, pages
end

local function row_width(count, row)
	local start_at = row * M.COLS
	if start_at >= count then
		return 0
	end
	return math.min(M.COLS, count - start_at)
end

local function clamp_cell(count, row, col)
	if count <= 0 then
		return 1, 0, 0
	end
	local rows = math.ceil(count / M.COLS)
	if row < 0 then
		row = 0
	elseif row >= rows then
		row = rows - 1
	end
	local width = row_width(count, row)
	if width <= 0 then
		row = rows - 1
		width = row_width(count, row)
	end
	if width <= 0 then
		return 1, 0, 0
	end
	col = math.floor(tonumber(col) or 0)
	if col < 0 then
		col = 0
	elseif col >= width then
		col = width - 1
	end
	return row * M.COLS + col + 1, row, col
end

local function list_of(st)
	local model = st.model or {}
	local list = model.candidate_ids
	if type(list) ~= "table" then
		return {}
	end
	return list
end

local function change_page(st, list_count, delta)
	local pages = page_total(list_count)
	local dest = st.catalog_page + delta
	if dest < 1 or dest > pages then
		return false
	end
	local row = math.floor((st.catalog_index - 1) / M.COLS)
	local col = (st.catalog_index - 1) % M.COLS
	st.catalog_page = dest
	local _, _, n = page_span(list_count, dest)
	local index, _, new_col = clamp_cell(n, row, col)
	st.catalog_index = index
	st.catalog_column = new_col
	st.catalog_focus = "items"
	st.page_anim = 5
	st.page_anim_dir = delta
	return true
end

local function move_items(st, list_count, dir)
	local _, _, count = page_span(list_count, st.catalog_page)
	if count <= 0 then
		if dir == 7 then
			st.catalog_focus = st.catalog_page > 1 and "prev" or "next"
		end
		return false
	end
	local col = (st.catalog_index - 1) % M.COLS
	local row = math.floor((st.catalog_index - 1) / M.COLS)
	local rows = math.max(1, math.ceil(count / M.COLS))
	if dir == 4 then
		if col > 0 then
			col = col - 1
		else
			return change_page(st, list_count, -1)
		end
	elseif dir == 5 then
		local width = row_width(count, row)
		if col < width - 1 then
			col = col + 1
		else
			return change_page(st, list_count, 1)
		end
	elseif dir == 6 then
		if row > 0 then
			row = row - 1
		end
	elseif dir == 7 then
		if row + 1 < rows then
			row = row + 1
		else
			st.catalog_focus = st.catalog_page > 1 and "prev" or "next"
			st.catalog_column = col
			return false
		end
	end
	local index, _, new_col = clamp_cell(count, row, col)
	st.catalog_index = index
	st.catalog_column = new_col
	st.catalog_focus = "items"
	return false
end

local function move_pager(st, list_count, dir)
	local _, _, count = page_span(list_count, st.catalog_page)
	if dir == 4 then
		st.catalog_focus = "prev"
	elseif dir == 5 then
		st.catalog_focus = "next"
	elseif dir == 6 then
		if count <= 0 then
			return false
		end
		st.catalog_focus = "items"
		local row = math.ceil(count / M.COLS) - 1
		local index, _, col = clamp_cell(count, row, st.catalog_column or 0)
		st.catalog_index = index
		st.catalog_column = col
	elseif dir == 9 then
		if st.catalog_focus == "prev" then
			return change_page(st, list_count, -1)
		end
		if st.catalog_focus == "next" then
			return change_page(st, list_count, 1)
		end
	end
	return false
end

local function selected_id(st)
	if st.catalog_focus ~= "items" then
		return nil
	end
	local list = list_of(st)
	local _, start, n = page_span(#list, st.catalog_page)
	if st.catalog_index < 1 or st.catalog_index > n then
		return nil
	end
	return list[start + st.catalog_index]
end

local function option_row(st, index)
	local options = st.model and st.model.options
	if type(options) ~= "table" then
		return nil
	end
	return options[index]
end

local function direction_edge(st, ctrl, button)
	local holds = st.holds
	local down = Input.IsActionPressed(button, ctrl) or Input.IsActionTriggered(button, ctrl)
	if not down then
		holds[button] = nil
		return false
	end
	if holds[button] == nil then
		holds[button] = 0
		return true
	end
	holds[button] = holds[button] + 1
	local held = holds[button]
	if held == M.NAV_REPEAT_INITIAL then
		return true
	end
	if held > M.NAV_REPEAT_INITIAL then
		return (held - M.NAV_REPEAT_INITIAL) % M.NAV_REPEAT_INTERVAL == 0
	end
	return false
end

function M.tick(player)
	local st = state_of(player)
	if not st or Game():IsPaused() then
		return nil
	end
	if st.ceremony then
		local now = Game():GetFrameCount()
		if st.ceremony_frame ~= now then
			st.ceremony_frame = now
			st.ceremony_t = (st.ceremony_t or 0) + 1
			st.ceremony = ceremony_phase(st.ceremony_t)
		end
		if st.ceremony_t >= CEREMONY_DISMISS then
			st.dismiss = true
			return nil
		end
		if st.ceremony_t >= 81 and not st.commit_sent and not st.verdict_failed then
			st.commit_sent = true
			return { action = "commit_banish", collectible_id = st.verdict_id }
		end
		return nil
	end
	if st.opening_frames > 0 then
		st.opening_frames = st.opening_frames - 1
		return nil
	end
	if st.page_anim > 0 then
		st.page_anim = st.page_anim - 1
	end
	if st.stamp_frames > 0 then
		st.stamp_frames = st.stamp_frames - 1
		if st.stamp_frames == 0 then
			st.closing_frames = 6
		end
		return
	end
	if st.closing_frames > 0 then
		st.closing_frames = st.closing_frames - 1
		if st.closing_frames == 0 then
			st.dismiss = true
		end
	end
end

function M.handle_input(player)
	local st = state_of(player)
	if not st or st.dismiss or st.committed or Game():IsPaused() then
		return nil
	end
	if st.opening_frames > 0 or st.stamp_frames > 0 or st.closing_frames > 0 then
		return nil
	end
	local ctrl = player.ControllerIndex
	local fired = {}
	for _, button in ipairs(DIR_PRIORITY) do
		fired[button] = direction_edge(st, ctrl, button)
	end
	local action = nil
	if Input.IsActionTriggered(11, ctrl) then
		action = 11
	elseif Input.IsActionTriggered(9, ctrl) then
		action = 9
	else
		for _, button in ipairs(DIR_PRIORITY) do
			if fired[button] then
				action = button
				break
			end
		end
	end
	if not action then
		return nil
	end
	if st.page == "menu" then
		local count = 2
		if action == 11 then
			return { action = "cancel" }
		elseif action == 9 then
			local row = option_row(st, st.menu_index)
			if not row or row.enabled ~= true then
				return nil
			end
			play(SoundEffect.SOUND_BUTTON_PRESS, 0.8, 1)
			if row.id == "border" then
				return { action = "enter_border" }
			end
			return { action = "open_catalog" }
		elseif action == 6 or action == 4 then
			st.menu_index = (st.menu_index - 2) % count + 1
			play(SoundEffect.SOUND_MENU_SCROLL, 0.45, 1)
		elseif action == 7 or action == 5 then
			st.menu_index = st.menu_index % count + 1
			play(SoundEffect.SOUND_MENU_SCROLL, 0.45, 1)
		end
		return nil
	end
	local list_count = #list_of(st)
	if action == 11 then
		st.page = "menu"
		play(SoundEffect.SOUND_MENU_SCROLL, 0.4, 0.9)
		return nil
	end
	if action == 9 and st.catalog_focus == "items" then
		local id = selected_id(st)
		if not id then
			return nil
		end
		local banned = st.model and st.model.banished_set
		local count = tonumber(st.model and st.model.banished_count) or 0
		local limit = tonumber(st.model and st.model.banished_limit) or 32
		if (type(banned) == "table" and banned[id] == true) or count >= limit then
			play(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.4, 1.15)
			return nil
		end
		play(SoundEffect.SOUND_BUTTON_PRESS, 0.85, 0.95)
		return { action = "banish_selected", collectible_id = id }
	end
	local turned = false
	if st.catalog_focus == "items" then
		turned = move_items(st, list_count, action)
	else
		turned = move_pager(st, list_count, action)
	end
	if turned then
		play(SoundEffect.SOUND_BOOK_PAGE_TURN_12, 0.9, 1)
	elseif action >= 4 and action <= 7 then
		play(SoundEffect.SOUND_MENU_SCROLL, 0.28, 1.1)
	end
	return nil
end

function M.back_to_menu(player)
	local st = state_of(player)
	if not st or st.page ~= "catalog" or st.committed then
		return false
	end
	if st.stamp_frames > 0 or st.closing_frames > 0 then
		return true
	end
	st.page = "menu"
	play(SoundEffect.SOUND_MENU_SCROLL, 0.4, 0.9)
	return true
end

local function layout()
	local screen = gui.GetScreenSize()
	local hud_level = 0
	if hud.GetHudOffsetLevel then
		hud_level = hud.GetHudOffsetLevel() or 0
	end
	local shake = Vector.Zero
	if hud.GetHUDRenderOffset then
		shake = hud.GetHUDRenderOffset() or Vector.Zero
	end
	local margin = 12 + hud_level * 2
	local tl = Vector(margin, margin) + shake
	local br = screen + Vector(-margin, -margin) + shake
	local avail_w = math.max(1, br.X - tl.X)
	local avail_h = math.max(1, br.Y - tl.Y)
	local scale = math.min(1, avail_w / M.PANEL_W, avail_h / M.PANEL_H)
	local left = (tl.X + br.X) * 0.5 - M.PANEL_W * scale * 0.5
	local top = (tl.Y + br.Y) * 0.5 - M.PANEL_H * scale * 0.5
	local text_scale = 1
	if scale < 0.75 then
		text_scale = 0.5
	end
	return {
		scale = scale,
		left = left,
		top = top,
		text_scale = text_scale,
	}
end

local function sx(L, x)
	return L.left + x * L.scale
end

local function sy(L, y)
	return L.top + y * L.scale
end

local function fill_rect(x, y, w, h, color)
	if w <= 0 or h <= 0 then
		return
	end
	local y0 = math.floor(y + 0.5)
	local y1 = math.floor(y + h + 0.5)
	local x1 = x + w
	for yy = y0, y1 do
		Isaac.DrawLine(Vector(x, yy), Vector(x1, yy), color, color, 1)
	end
end

local function stroke_rect(x, y, w, h, color, thickness)
	thickness = thickness or 1
	Isaac.DrawLine(Vector(x, y), Vector(x + w, y), color, color, thickness)
	Isaac.DrawLine(Vector(x, y + h), Vector(x + w, y + h), color, color, thickness)
	Isaac.DrawLine(Vector(x, y), Vector(x, y + h), color, color, thickness)
	Isaac.DrawLine(Vector(x + w, y), Vector(x + w, y + h), color, color, thickness)
end

local function panel_alpha(st)
	if st.ceremony then
		local t = st.ceremony_t or 0
		if t >= 97 then
			return math.max(0, (CEREMONY_DISMISS - t) / 8)
		end
		return 1
	end
	if st.opening_frames > 0 then
		return 1 - st.opening_frames / 8
	end
	if st.closing_frames > 0 then
		return st.closing_frames / 6
	end
	return 1
end

local function draw_text(L, x, y, line, alpha, centered, width, color)
	local scale = L.text_scale
	local shown = line or ""
	if width and width > 0 then
		local limit = width * L.scale
		if pixel_ui.measure_text(shown, scale) > limit then
			local ellipsis = "..."
			local kept = ""
			for glyph in pixel_ui.iter_utf8_glyphs(shown) do
				local candidate = kept .. glyph
				if pixel_ui.measure_text(candidate .. ellipsis, scale) > limit then
					break
				end
				kept = candidate
			end
			shown = kept == "" and ellipsis or (kept .. ellipsis)
		end
	end
	color = color or KColor(1, 242 / 255, 217 / 255, alpha)
	local screen_x = sx(L, x)
	local screen_y = sy(L, y)
	if centered then
		pixel_ui.draw_text_centered(screen_x, screen_y, shown, scale, color, { context = "exoneration_ui" })
	else
		pixel_ui.draw_text(Vector(screen_x, screen_y), shown, scale, color, { context = "exoneration_ui" })
	end
end

local function draw_placeholder_icon(L, kind, x, y, alpha)
	local cx = sx(L, x)
	local cy = sy(L, y)
	local s = 10 * L.scale
	local ink = KColor(0.72, 0.22, 0.18, alpha)
	local brass = KColor(0.78, 0.62, 0.32, alpha)
	if kind == "banish" then
		stroke_rect(cx - s, cy - s, s * 2, s * 2, brass, 1)
		Isaac.DrawLine(Vector(cx - s + 3, cy - s + 3), Vector(cx + s - 3, cy + s - 3), ink, ink, 1)
		Isaac.DrawLine(Vector(cx + s - 3, cy - s + 3), Vector(cx - s + 3, cy + s - 3), ink, ink, 1)
	else
		Isaac.DrawLine(Vector(cx - s, cy + s), Vector(cx - s, cy - 2), brass, brass, 1)
		Isaac.DrawLine(Vector(cx + s, cy + s), Vector(cx + s, cy - 2), brass, brass, 1)
		Isaac.DrawLine(Vector(cx - s, cy - 2), Vector(cx, cy - s), ink, ink, 1)
		Isaac.DrawLine(Vector(cx, cy - s), Vector(cx + s, cy - 2), ink, ink, 1)
	end
end

local function draw_asset(sprite, x, y, scale, alpha)
	if not sprite or not sprite.Render then
		return false
	end
	local prev_scale = sprite.Scale
	local prev_color = sprite.Color
	sprite.Scale = Vector(scale, scale)
	sprite.Color = Color(1, 1, 1, alpha)
	sprite:Render(Vector(x, y), Vector.Zero, Vector.Zero)
	sprite.Scale = prev_scale
	sprite.Color = prev_color
	return true
end

local function collectible_name(id)
	if EID and EID.getObjectName then
		local ok, name = pcall(function()
			return EID:getObjectName(5, 100, id)
		end)
		if ok and type(name) == "string" and name ~= "" then
			return name
		end
	end
	local cfg = Isaac.GetItemConfig():GetCollectible(id)
	return (cfg and cfg.Name) or ("#" .. tostring(id))
end

local function title_ink(alpha)
	return KColor(1, 242 / 255, 217 / 255, alpha)
end

local function note_ink(alpha)
	return KColor(242 / 255, 226 / 255, 196 / 255, alpha)
end

local function wax_ink(alpha)
	return KColor(132 / 255, 47 / 255, 53 / 255, alpha)
end

local function is_banished(st, id)
	local banned = st.model and st.model.banished_set
	return type(banned) == "table" and banned[tonumber(id)] == true
end

local function draw_collectible(L, id, x, y, size, alpha, icon_fn)
	local sprite = id and icon_fn and icon_fn(id) or nil
	if not sprite or not sprite.Render then
		return
	end
	local prev_scale = sprite.Scale
	local prev_color = sprite.Color
	local fit = (size / 32) * L.scale
	sprite.Scale = Vector(fit, fit)
	sprite.Color = Color(1, 1, 1, alpha)
	local ok, err = pcall(function()
		sprite:Render(Vector(sx(L, x), sy(L, y)), Vector.Zero, Vector.Zero)
	end)
	sprite.Scale = prev_scale
	sprite.Color = prev_color
	if not ok and Isaac and Isaac.DebugString then
		Isaac.DebugString("[ExonerationUI] draw_collectible failed: " .. tostring(err))
	end
end

local function draw_menu_icon(L, kind, x, y, alpha)
	local sprite = kind == "banish" and M.assets.icon_banish or M.assets.icon_border
	if draw_asset(sprite, sx(L, x), sy(L, y), L.scale, alpha) then
		return
	end
	draw_placeholder_icon(L, kind, x, y, alpha)
end

local function render_menu(st, L, alpha)
	local art = draw_asset(M.assets.menu_overlay, sx(L, 210), sy(L, 134), L.scale, alpha)
	local brass = KColor(0.78, 0.62, 0.32, alpha)
	if not art then
		local body = KColor(0.18, 0.11, 0.08, 0.94 * alpha)
		local paper = KColor(0.42, 0.3, 0.2, 0.95 * alpha)
		if not draw_asset(M.assets.frame, sx(L, 210), sy(L, 134), L.scale, alpha) then
			fill_rect(sx(L, 10), sy(L, 10), 400 * L.scale, 248 * L.scale, body)
			stroke_rect(sx(L, 10), sy(L, 10), 400 * L.scale, 248 * L.scale, brass, 2)
			fill_rect(sx(L, 24), sy(L, 16), 372 * L.scale, 54 * L.scale, paper)
		end
		Isaac.DrawLine(Vector(sx(L, 30), sy(L, 76)), Vector(sx(L, 390), sy(L, 76)), brass, brass, 1)
	end
	local slot_x = art and 37 or 34
	local slot_w = art and 346 or 352
	local slot_h = art and 56 or 57
	local slots = {
		{ y = art and 80 or 88, kind = "banish", title = text("签发放逐", "Banish an item"), desc = text("选择一件道具，将其永久放逐", "Choose one item to banish permanently") },
		{ y = art and 141 or 155, kind = "border", title = text("前往放逐边境", "Enter the Border"), desc = text("取回一件曾经放逐的道具", "Retrieve one banished item") },
	}
	for i, slot in ipairs(slots) do
		local row = option_row(st, i)
		local enabled = row and row.enabled == true
		local focused = st.menu_index == i
		local slot_alpha = alpha * (enabled and 1 or 0.4)
		if art then
			if focused and enabled then
				fill_rect(sx(L, slot_x + 6), sy(L, slot.y + 6), (slot_w - 12) * L.scale, (slot_h - 12) * L.scale, KColor(0.55, 0.16, 0.12, 0.06 * alpha))
			end
			if focused then
				stroke_rect(sx(L, slot_x + 4), sy(L, slot.y + 4), (slot_w - 8) * L.scale, (slot_h - 8) * L.scale, KColor(0.62, 0.14, 0.1, slot_alpha), 2)
			end
		else
			local fill = KColor(0.28, 0.16, 0.12, (focused and 0.95 or 0.55) * slot_alpha)
			fill_rect(sx(L, slot_x), sy(L, slot.y), slot_w * L.scale, slot_h * L.scale, fill)
			if focused then
				stroke_rect(sx(L, slot_x), sy(L, slot.y), slot_w * L.scale, slot_h * L.scale, KColor(0.55, 0.12, 0.1, slot_alpha), 2)
				stroke_rect(sx(L, slot_x + 4), sy(L, slot.y + 4), (slot_w - 8) * L.scale, (slot_h - 8) * L.scale, brass, 1)
			else
				stroke_rect(sx(L, slot_x), sy(L, slot.y), slot_w * L.scale, slot_h * L.scale, KColor(0.45, 0.32, 0.18, slot_alpha), 1)
			end
		end
		draw_menu_icon(L, slot.kind, 58, slot.y + 28, slot_alpha)
		draw_text(L, 78, slot.y + 12, slot.title, slot_alpha, false, 280, title_ink(slot_alpha))
		draw_text(L, 78, slot.y + 30, slot.desc, slot_alpha, false, 280, note_ink(slot_alpha))
	end
	local count = tonumber(st.model and st.model.banished_count) or 0
	local limit = tonumber(st.model and st.model.banished_limit) or 32
	local foot_y = art and 215 or 230
	draw_text(L, 48, foot_y, tostring(count) .. " / " .. tostring(limit), alpha, false, 90, note_ink(alpha))
	draw_text(L, 210, foot_y, text("确认 · 返回", "Confirm · Back"), alpha, true, 180, note_ink(alpha))
end

local function render_catalog(st, L, alpha, icon_fn)
	local art = draw_asset(M.assets.catalog_overlay, sx(L, 210), sy(L, 134), L.scale, alpha)
	local brass = KColor(0.78, 0.62, 0.32, alpha)
	if not art then
		local body = KColor(0.16, 0.1, 0.08, 0.94 * alpha)
		if not draw_asset(M.assets.frame, sx(L, 210), sy(L, 134), L.scale, alpha) then
			fill_rect(sx(L, 10), sy(L, 10), 400 * L.scale, 248 * L.scale, body)
			stroke_rect(sx(L, 10), sy(L, 10), 400 * L.scale, 248 * L.scale, brass, 2)
		end
	end
	local list = list_of(st)
	local _, start, count, pages = page_span(#list, st.catalog_page)
	if not art then
		draw_text(L, 300, 16, text("第 ", "Page ") .. tostring(st.catalog_page) .. " / " .. tostring(pages), alpha, false, 110)
		fill_rect(sx(L, 42), sy(L, 48), 336 * L.scale, 160 * L.scale, KColor(0.1, 0.07, 0.05, 0.9 * alpha))
	end
	local step = art and 26 or 32
	local origin_x = art and 93 or 66
	local origin_y = art and 75 or 64
	local icon_box = art and 24 or 28
	local slide_px = art and 10 or 16
	local slide = 0
	if st.page_anim > 0 then
		slide = st.page_anim_dir * (st.page_anim / 5) * slide_px
	end
	for i = 1, count do
		local id = list[start + i]
		local col = (i - 1) % M.COLS
		local row = math.floor((i - 1) / M.COLS)
		local cx = origin_x + col * step + slide
		local cy = origin_y + row * step
		local half = step * 0.5
		if art then
			fill_rect(sx(L, cx - 12), sy(L, cy - 12), 24 * L.scale, 24 * L.scale, KColor(0.98, 0.94, 0.86, 0.28 * alpha))
			stroke_rect(sx(L, cx - half), sy(L, cy - half), step * L.scale, step * L.scale, KColor(0.55, 0.4, 0.22, 0.45 * alpha), 1)
		else
			fill_rect(sx(L, cx - 15), sy(L, cy - 15), 30 * L.scale, 30 * L.scale, KColor(0.24, 0.16, 0.1, 0.85 * alpha))
		end
		local icon_alpha = alpha
		if is_banished(st, id) then
			icon_alpha = alpha * BANISHED_ICON_ALPHA
		end
		draw_collectible(L, id, cx, cy, icon_box, icon_alpha, icon_fn)
		if st.catalog_focus == "items" and st.catalog_index == i then
			local pulse = 0.65 + 0.35 * (0.5 + 0.5 * math.sin((Isaac.GetFrameCount() or 0) * 0.15))
			local cursor = M.assets.cursor
			if not draw_asset(cursor, sx(L, cx), sy(L, cy), L.scale, alpha * pulse) then
				local mark = art and KColor(0.62, 0.16, 0.12, alpha * pulse) or KColor(0.86, 0.72, 0.34, alpha * pulse)
				stroke_rect(sx(L, cx - half), sy(L, cy - half), step * L.scale, step * L.scale, mark, 2)
			end
		end
	end
	local prev_on = st.catalog_page > 1
	local next_on = st.catalog_page < pages
	local function pager_alpha(enabled, focused)
		if not enabled then
			return alpha * (focused and 0.55 or 0.35)
		end
		return alpha * (focused and 1 or 0.9)
	end
	local prev_label = (st.catalog_focus == "prev" and "> " or "") .. text("上一页", "Prev")
	local next_label = (st.catalog_focus == "next" and "> " or "") .. text("下一页", "Next")
	local pager_y = art and 204 or 214
	local name_y = art and 230 or 238
	draw_text(L, 90, pager_y, prev_label, pager_alpha(prev_on, st.catalog_focus == "prev"), true, 100, note_ink(pager_alpha(prev_on, st.catalog_focus == "prev")))
	draw_text(L, 210, pager_y, tostring(st.catalog_page) .. " / " .. tostring(pages), alpha, true, 80, note_ink(alpha))
	draw_text(L, 330, pager_y, next_label, pager_alpha(next_on, st.catalog_focus == "next"), true, 100, note_ink(pager_alpha(next_on, st.catalog_focus == "next")))
	local shown = nil
	local _, name_start, name_n = page_span(#list, st.catalog_page)
	if st.catalog_index >= 1 and st.catalog_index <= name_n then
		shown = list[name_start + st.catalog_index]
	end
	local name
	local name_color = title_ink(alpha)
	if not shown then
		name = text("没有可放逐的道具", "No item can be banished")
	elseif is_banished(st, shown) then
		name = collectible_name(shown) .. text(" · 已放逐", " · Banished")
		name_color = wax_ink(alpha)
	elseif (tonumber(st.model and st.model.banished_count) or 0) >= (tonumber(st.model and st.model.banished_limit) or 32) then
		name = collectible_name(shown) .. text(" · 放逐名额已满", " · Exile quota full")
		name_color = wax_ink(alpha)
	else
		name = text("已选：", "Selected: ") .. collectible_name(shown)
	end
	draw_text(L, 210, name_y, name, alpha, true, 300, name_color)
end

local function draw_ring(cx, cy, radius, color, weight)
	for i = 0, 23 do
		local a0 = i / 24 * math.pi * 2
		local a1 = (i + 1) / 24 * math.pi * 2
		Isaac.DrawLine(
			Vector(cx + math.cos(a0) * radius, cy + math.sin(a0) * radius),
			Vector(cx + math.cos(a1) * radius, cy + math.sin(a1) * radius),
			color, color, weight or 2
		)
	end
end

local function verdict_lines(id)
	local no = string.format("%03d", tonumber(id) or 0)
	local name = collectible_name(id)
	if zh_lang() then
		return {
			"放逐裁定 · 第 " .. no .. " 号",
			name,
			"经审定，该物品不再具备留存于此世界之必要。",
			"即日起，予以永久放逐。",
		}
	end
	return {
		"Decree of Exile · No. " .. no,
		name,
		"It may no longer remain in this world.",
		"From this day, it is permanently exiled.",
	}
end

local function selected_pose(st)
	local t = st.ceremony_t or 0
	local p = 0
	if t >= 33 then
		p = 1
	elseif t >= 15 then
		p = smooth((t - 15) / 17)
	end
	return st.from_x + (VERDICT_X - st.from_x) * p,
		st.from_y + (VERDICT_Y - st.from_y) * p,
		st.from_size + (VERDICT_SIZE - st.from_size) * p
end

local function render_verdict(st, L, alpha, icon_fn)
	local art = draw_asset(M.assets.catalog_overlay, sx(L, 210), sy(L, 134), L.scale, alpha)
	if not art and not draw_asset(M.assets.frame, sx(L, 210), sy(L, 134), L.scale, alpha) then
		fill_rect(sx(L, 10), sy(L, 10), 400 * L.scale, 248 * L.scale, KColor(0.16, 0.1, 0.08, 0.94 * alpha))
		stroke_rect(sx(L, 10), sy(L, 10), 400 * L.scale, 248 * L.scale, KColor(0.78, 0.62, 0.32, alpha), 2)
	end
	local t = st.ceremony_t or 0
	local snap = st.ceremony_ids
	if type(snap) ~= "table" then
		snap = {}
	end
	local focus = st.ceremony_index or st.catalog_index or 1
	local used_art = st.ceremony_art
	if used_art == nil then
		used_art = art
	end
	local step = used_art and 26 or 32
	local origin_x = used_art and 93 or 66
	local origin_y = used_art and 75 or 64
	local icon_box = used_art and 24 or 28
	for i = 1, #snap do
		if i ~= focus then
			local began = ((i - 1) % 10) * 0.7
			local fade = 1 - smooth((t - began) / 8)
			fade = math.max(0, math.min(1, fade))
			local shown = alpha * fade
			if shown > 0.02 then
				local col = (i - 1) % M.COLS
				local row = math.floor((i - 1) / M.COLS)
				local cx = origin_x + col * step
				local cy = origin_y + row * step
				if used_art then
					fill_rect(sx(L, cx - 12), sy(L, cy - 12), 24 * L.scale, 24 * L.scale, KColor(0.98, 0.94, 0.86, 0.28 * shown))
				end
				draw_collectible(L, snap[i], cx, cy, icon_box, shown, icon_fn)
			end
		end
	end
	local x, y, size = selected_pose(st)
	draw_collectible(L, st.verdict_id, x, y, size, alpha, icon_fn)
	if t >= 33 then
		local lines = verdict_lines(st.verdict_id)
		for i, line in ipairs(lines) do
			local shown = alpha * smooth((t - (33 + (i - 1) * 8)) / 6)
			if shown > 0.02 then
				local ink = note_ink(shown)
				if i == 1 or i == 4 then
					ink = wax_ink(shown)
				elseif i == 2 then
					ink = title_ink(shown)
				end
				draw_text(L, 148, 64 + (i - 1) * 18, line, shown, false, 230, ink)
			end
		end
	end
	if t >= 66 and not st.verdict_failed then
		local p = 1
		if t < 81 then
			local u = (t - 66) / 14
			p = u * u * u
		end
		local sx0 = STAMP_START_X + (STAMP_END_X - STAMP_START_X) * p
		local sy0 = STAMP_START_Y + (STAMP_END_Y - STAMP_START_Y) * p
		local stamp_alpha = alpha * math.min(1, 0.35 + p)
		local radius = (18 + (STAMP_RADIUS - 18) * p) * L.scale
		local ring = KColor(0.52, 0.12, 0.1, stamp_alpha)
		draw_ring(sx(L, sx0), sy(L, sy0), radius, ring, 2)
		local arm = radius * 0.62
		Isaac.DrawLine(Vector(sx(L, sx0) - arm, sy(L, sy0) - arm), Vector(sx(L, sx0) + arm, sy(L, sy0) + arm), ring, ring, 2)
		Isaac.DrawLine(Vector(sx(L, sx0) + arm, sy(L, sy0) - arm), Vector(sx(L, sx0) - arm, sy(L, sy0) + arm), ring, ring, 2)
		if p >= 1 then
			local age = math.max(0, t - 81)
			local ink_alpha = alpha * math.max(0, 0.16 - age * 0.01)
			if ink_alpha > 0.02 then
				draw_ring(sx(L, sx0), sy(L, sy0), radius + (4 + age) * L.scale, KColor(0.45, 0.1, 0.08, ink_alpha), 1)
			end
		end
	end
end

function M.render(player, icon_fn)
	local st = state_of(player)
	if not st then
		return
	end
	local room = Game():GetRoom()
	if room.GetRenderMode and room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then
		return
	end
	if st.want_stamp_sound and not st.stamp_sounded then
		st.stamp_sounded = true
		play(SoundEffect.SOUND_HELLBOSS_GROUNDPOUND, 0.8, 0.92)
	end
	local L = layout()
	if st.ceremony and not st.verdict_failed then
		local t = st.ceremony_t or 0
		if t >= 81 and t <= 86 then
			local mag = (87 - t) * 0.8
			local sign = (t % 2 == 0) and 1 or -1
			L.left = L.left + sign * mag
			L.top = L.top + mag * 0.35
		end
	end
	local alpha = panel_alpha(st)
	local screen = gui.GetScreenSize()
	local veil = KColor(0, 0, 0, 0.45 * alpha)
	local y = 0
	while y <= screen.Y do
		Isaac.DrawLine(Vector(0, y), Vector(screen.X, y), veil, veil, 1)
		y = y + 2
	end
	if st.ceremony then
		render_verdict(st, L, alpha, icon_fn)
	elseif st.page == "catalog" then
		render_catalog(st, L, alpha, icon_fn)
	else
		render_menu(st, L, alpha)
	end
end

local MENU_ANM2 = "gfx/mimics/Exoneration/Exo_Menu.anm2"
local PANEL_ANM2 = "gfx/mimics/Exoneration/Exo_Panel.anm2"
local BANISH_ANM2 = "gfx/mimics/Exoneration/Exo_Icon_Banish.anm2"
local BORDER_ANM2 = "gfx/mimics/Exoneration/Exo_Icon_Border.anm2"
local art_attempted = false

local function load_panel_sprite(path)
	if not Sprite then
		return nil
	end
	local spr = Sprite()
	local ok = pcall(function()
		spr:Load(path, true)
		spr:Play("Idle", true)
	end)
	if not ok or not spr.GetAnimation or spr:GetAnimation() ~= "Idle" then
		return nil
	end
	return spr
end

local function ensure_panel_art()
	if art_attempted or not Sprite then
		return
	end
	art_attempted = true
	local menu = load_panel_sprite(MENU_ANM2)
	local panel = load_panel_sprite(PANEL_ANM2)
	local banish = load_panel_sprite(BANISH_ANM2)
	local border = load_panel_sprite(BORDER_ANM2)
	if not menu or not panel then
		Isaac.DebugString("[ExonerationUI] panel art failed to load; using placeholder")
	end
	if not banish or not border then
		Isaac.DebugString("[ExonerationUI] option icons failed to load; using placeholder")
	end
	M.set_assets({
		menu_overlay = menu,
		catalog_overlay = panel,
		icon_banish = banish,
		icon_border = border,
	})
end

ensure_panel_art()

return M
