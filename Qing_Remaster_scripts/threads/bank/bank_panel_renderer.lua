-- Screen-space bank terminal. Scenario H: the panel uses the viewport size only.
-- The terminal is drawn from MC_POST_HUD_RENDER, after the vanilla HUD.
-- Zone icons are drawn by the caller after WorldToScreen(zone world position).

local bank_state = require("Qing_Remaster_scripts.threads.bank.bank_state")
local pixel_ui = require("Qing_Remaster_scripts.auxiliary.pixel_ui")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")

local panel = {}

local PARTS_ANM2 = "gfx/ui/bank/bank_panel_parts.anm2"
local ICONS_ANM2 = "gfx/ui/bank/bank_icons.anm2"
local BORDER = 12
local PANEL_W = 288

local INK = KColor(0x2B / 255, 0x1E / 255, 0x18 / 255, 1)
local CREAM = KColor(0xF2 / 255, 0xE8 / 255, 0xD0 / 255, 1)
local LABEL = KColor(0xC1 / 255, 0x8A / 255, 0x53 / 255, 1)
local VALUE = KColor(0xE6 / 255, 0xAE / 255, 0x5E / 255, 1)
local OPTION = KColor(0xB8 / 255, 0x81 / 255, 0x4D / 255, 1)
local SELECTED_TEXT = KColor(0xFF / 255, 0xE2 / 255, 0xA0 / 255, 1)
local HINT = KColor(0xA4 / 255, 0x7E / 255, 0x55 / 255, 1)
local GREEN = KColor(0xA5 / 255, 0xD2 / 255, 0x7B / 255, 1)

local function lang_zh()
	return Options and Options.Language ~= "en"
end

local function tr(zh, en)
	return lang_zh() and zh or en
end

local function load_sprite(path)
	local sprite = Sprite()
	local ok = pcall(function()
		sprite:Load(path, true)
	end)
	if not ok then return nil end
	return sprite
end

local function parts_sprite()
	if panel._parts == false then return nil end
	if panel._parts then return panel._parts end
	panel._parts = load_sprite(PARTS_ANM2) or false
	return panel._parts ~= false and panel._parts or nil
end

local function icons_sprite()
	if panel._icons == false then return nil end
	if panel._icons then return panel._icons end
	panel._icons = load_sprite(ICONS_ANM2) or false
	return panel._icons ~= false and panel._icons or nil
end

local function paint(anim, x, y, w, h, tile_w, tile_h)
	local sprite = parts_sprite()
	if not sprite then return end
	sprite.Scale = Vector(w / tile_w, h / tile_h)
	sprite:Play(anim, true)
	sprite:SetFrame(0)
	sprite:Render(Vector(math.floor(x + 0.5), math.floor(y + 0.5)), Vector(0, 0), Vector(0, 0))
	sprite.Scale = Vector(1, 1)
end

local function icon(name, x, y)
	local sprite = icons_sprite()
	if not sprite or not name then return end
	sprite.Scale = Vector(1, 1)
	sprite:Play(name, true)
	sprite:SetFrame(0)
	sprite:Render(Vector(math.floor(x + 0.5), math.floor(y + 0.5)), Vector(0, 0), Vector(0, 0))
end

local function text_opts(font)
	return {font = font, context = "bank_panel"}
end

local function fit_text(text, scale, max_w, font)
	text = tostring(text or "")
	if pixel_ui.measure_text(text, scale, font) <= max_w then return text end
	local glyphs = {}
	for glyph in pixel_ui.iter_utf8_glyphs(text) do
		glyphs[#glyphs + 1] = glyph
	end
	while #glyphs > 1 do
		glyphs[#glyphs] = nil
		local trial = table.concat(glyphs) .. "..."
		if pixel_ui.measure_text(trial, scale, font) <= max_w then return trial end
	end
	return "..."
end

local function item_sprite(item_id)
	panel._items = panel._items or {}
	local found = panel._items[item_id]
	if found then return found end
	local sprite = Sprite()
	sprite:Load("gfx/005.100_collectible.anm2", true)
	if EntityPickup.SetupCollectibleGraphics then
		EntityPickup.SetupCollectibleGraphics(sprite, 1, item_id, false, 1, true)
	else
		local cfg = Isaac.GetItemConfig():GetCollectible(item_id)
		if cfg and cfg.GfxFileName and cfg.GfxFileName ~= "" then
			sprite:ReplaceSpritesheet(1, cfg.GfxFileName)
			sprite:LoadGraphics()
		end
	end
	local anim = "PlayerPickup"
	sprite:Play(anim, true)
	sprite:SetFrame(0)
	sprite.Scale = Vector(1, 1)
	panel._items[item_id] = sprite
	if panel._item_count and panel._item_count > 32 then
		panel._items = {[item_id] = sprite}
		panel._item_count = 1
	else
		panel._item_count = (panel._item_count or 0) + 1
	end
	return sprite
end

function panel.clear_item_sprites()
	panel._items = nil
	panel._item_count = 0
end

local function render_item_icon(item_id, slot_x, slot_y, slot)
	local sprite = item_sprite(item_id)
	if not sprite then return end
	sprite.Scale = Vector(1, 1)
	sprite:SetFrame(0)
	local center = Vector(slot_x + slot * 0.5, slot_y + slot * 0.5)
	local render_pos = ui.VisualCenterToRenderPos(center, sprite, 1, 1)
	sprite:Render(render_pos, Vector(0, 0), Vector(0, 0))
end

local function frame(x, y, w, h, warning)
	paint("corner_tl", x, y, 12, 12, 12, 12)
	paint("corner_tr", x + w - 12, y, 12, 12, 12, 12)
	paint("corner_bl", x, y + h - 12, 12, 12, 12, 12)
	paint("corner_br", x + w - 12, y + h - 12, 12, 12, 12, 12)
	paint("edge_t", x + 12, y, w - 24, 12, 8, 12)
	paint("edge_b", x + 12, y + h - 12, w - 24, 12, 8, 12)
	paint("edge_l", x, y + 12, 12, h - 24, 12, 8)
	paint("edge_r", x + w - 12, y + 12, 12, h - 24, 12, 8)
	paint(warning and "warn" or "paper", x + 12, y + 12, w - 24, h - 24, 8, 8)
end

local function snap_width(screen_w)
	local limit = math.floor((screen_w - 16) / 8) * 8
	local width = PANEL_W
	if width > limit then width = limit end
	local tiles = math.floor((width - 24) / 8)
	if tiles < 16 then tiles = 16 end
	width = 24 + tiles * 8
	if width > limit and limit >= 24 + 16 * 8 then
		tiles = math.floor((limit - 24) / 8)
		width = 24 + tiles * 8
	end
	return width
end

local function amount_of(player, sess, choice)
	if choice == "all" then
		if sess.page == "deposit" then return player:GetNumCoins() end
		return bank_state.get_deposit()
	end
	return tonumber(choice) or 0
end

local function choice_label(choice)
	if choice == "all" then return tr("全部", "ALL") end
	if type(choice) == "number" then return tostring(choice) .. "¢" end
	local labels = {
		deposit = tr("存入硬币", "Deposit"),
		withdraw = tr("取出硬币", "Withdraw"),
		exit = tr("返回", "Back"),
		repay = tr("偿还", "Repay"),
		forfeit = tr("放弃抵押物", "Forfeit"),
		replace = tr("重新抵押", "Re-collateral"),
		confirm_loan = tr("确认贷款", "Confirm loan"),
		confirm_replace = tr("确认更换", "Confirm change"),
		reselect = tr("重新选择", "Choose again"),
		back = tr("返回", "Back"),
	}
	return labels[choice] or tostring(choice)
end

local function choice_icon(choice, selected, warning)
	local base = {
		deposit = "arrow_down",
		withdraw = "arrow_up",
		exit = "door",
		repay = "wallet",
		forfeit = "alert",
		replace = "lock",
		confirm_loan = "wallet",
		confirm_replace = "lock",
		reselect = "arrow_up",
		back = "door",
		all = "coins",
	}
	local name = base[choice] or (type(choice) == "number" and "coins" or nil)
	if not name then return nil end
	if selected then return name .. "_selected" end
	if warning then return name .. "_warning" end
	return name
end

local TEXT_OFFSET_Y = 2

local function text_y(top, local_y, scale, box_h)
	local line = pixel_ui.measure_line_height(scale or 1)
	local y = local_y + TEXT_OFFSET_Y
	if box_h and y + line > box_h then
		y = math.max(local_y, box_h - line)
	end
	return top + y
end

local function space(ctx)
	return ctx.compact and 2 or 4
end

local function value_fit(text, max_w, font)
	text = tostring(text or "")
	if max_w >= 8 and pixel_ui.measure_text(text, 2, font) <= max_w then
		return 2, text
	end
	if pixel_ui.measure_text(text, 1, font) <= max_w then
		return 1, text
	end
	return 1, fit_text(text, 1, math.max(8, max_w), font)
end

local function begin_body(ctx, subtitle)
	local h = ctx.compact and 24 or 36
	if ctx.draw then
		paint("brass", ctx.x, ctx.y, ctx.w, h, 8, 12)
		icon(ctx.warning and "landmark_warning" or "landmark_header", ctx.x + 4, ctx.y + math.floor((h - 24) * 0.5))
		local opts = text_opts(ctx.font)
		local text_w = math.max(8, ctx.w - 36)
		if ctx.compact then
			local line = fit_text("BANK OF BUM  " .. subtitle, 1, text_w, ctx.font)
			pixel_ui.draw_text(Vector(ctx.x + 30, text_y(ctx.y, 4, 1, h)), line, 1, CREAM, opts)
		else
			pixel_ui.draw_text(Vector(ctx.x + 30, text_y(ctx.y, 2, 1, h)), fit_text("BANK OF BUM", 1, text_w, ctx.font), 1, CREAM, opts)
			pixel_ui.draw_text(Vector(ctx.x + 30, text_y(ctx.y, 16, 1, h)), fit_text(subtitle, 1, text_w, ctx.font), 1, CREAM, opts)
		end
	end
	ctx.y = ctx.y + h + space(ctx)
end

local function card_text_width(card_w)
	return math.max(8, card_w - 34)
end

local function stat_pair_fits(ctx, left_label, left_value, right_label, right_value)
	local gap = 8
	local card_w = math.floor((ctx.w - gap) / 2)
	card_w = card_w - (card_w % 8)
	local text_w = card_text_width(card_w)
	if text_w < 36 then return false end
	local font = ctx.font
	if pixel_ui.measure_text(left_label, 1, font) > text_w then return false end
	if pixel_ui.measure_text(right_label, 1, font) > text_w then return false end
	local left_scale, left_shown = value_fit(left_value, text_w, font)
	local right_scale, right_shown = value_fit(right_value, text_w, font)
	return left_scale >= 1 and left_shown == tostring(left_value) and right_shown == tostring(right_value)
end

local function stat_pair(ctx, left_icon, left_label, left_value, right_icon, right_label, right_value, value_color)
	local h = 48
	local gap = 8
	local card_w = math.floor((ctx.w - gap) / 2)
	card_w = card_w - (card_w % 8)
	local text_w = card_text_width(card_w)
	if ctx.draw then
		paint("card", ctx.x, ctx.y, card_w, h, 8, 8)
		paint("card", ctx.x + ctx.w - card_w, ctx.y, card_w, h, 8, 8)
		icon(left_icon, ctx.x + 4, ctx.y + 4)
		icon(right_icon, ctx.x + ctx.w - card_w + 4, ctx.y + 4)
		local opts = text_opts(ctx.font)
		local left_scale, left_shown = value_fit(left_value, text_w, ctx.font)
		local right_scale, right_shown = value_fit(right_value, text_w, ctx.font)
		pixel_ui.draw_text(Vector(ctx.x + 30, text_y(ctx.y, 4, 1, h)), fit_text(left_label, 1, text_w, ctx.font), 1, LABEL, opts)
		pixel_ui.draw_text(Vector(ctx.x + 30, text_y(ctx.y, 20, left_scale, h)), left_shown, left_scale, value_color or VALUE, opts)
		local right_x = ctx.x + ctx.w - card_w + 30
		pixel_ui.draw_text(Vector(right_x, text_y(ctx.y, 4, 1, h)), fit_text(right_label, 1, text_w, ctx.font), 1, LABEL, opts)
		pixel_ui.draw_text(Vector(right_x, text_y(ctx.y, 20, right_scale, h)), right_shown, right_scale, value_color or VALUE, opts)
	end
	ctx.y = ctx.y + h + space(ctx)
end

local function info_line(ctx, icon_name, label, value, value_color)
	local h = 24
	if ctx.draw then
		paint("card", ctx.x, ctx.y, ctx.w, h, 8, 8)
		icon(icon_name, ctx.x + 2, ctx.y)
		local value_text = tostring(value or "")
		local value_w = pixel_ui.measure_text(value_text, 1, ctx.font)
		local room = math.max(8, ctx.w - 36 - value_w - 8)
		local shown = fit_text(label, 1, room, ctx.font)
		local label_color = ctx.warning and CREAM or LABEL
		local label_y = text_y(ctx.y, 4, 1, h)
		pixel_ui.draw_text(Vector(ctx.x + 28, label_y), shown, 1, label_color, text_opts(ctx.font))
		pixel_ui.draw_text_right(Vector(ctx.x + ctx.w - 8, label_y), value_text, 1, value_color or GREEN, text_opts(ctx.font))
	end
	ctx.y = ctx.y + h + space(ctx)
end

local function hero(ctx, value)
	local scale, shown = value_fit(value, math.max(8, ctx.w - 8), ctx.font)
	local h = ctx.compact and 24 or 28
	if ctx.draw then
		pixel_ui.draw_text_centered(ctx.x + ctx.w * 0.5, text_y(ctx.y, 0, scale, h), shown, scale, ctx.warning and CREAM or VALUE, text_opts(ctx.font))
	end
	ctx.y = ctx.y + h
end

local function plain_line(ctx, label, value)
	local h = 16
	if ctx.draw then
		local value_text = tostring(value or "")
		local value_w = pixel_ui.measure_text(value_text, 1, ctx.font)
		local room = math.max(8, ctx.w - 16 - value_w - 8)
		local shown = fit_text(label, 1, room, ctx.font)
		local body = ctx.warning and CREAM or VALUE
		local line_y = text_y(ctx.y, 0, 1, h)
		pixel_ui.draw_text(Vector(ctx.x + 8, line_y), shown, 1, body, text_opts(ctx.font))
		pixel_ui.draw_text_right(Vector(ctx.x + ctx.w - 8, line_y), value_text, 1, body, text_opts(ctx.font))
	end
	ctx.y = ctx.y + h
end

local function choice_row(ctx, label, icon_name, selected)
	local h = 24
	if ctx.draw then
		if selected then
			paint("brass", ctx.x, ctx.y, ctx.w, h, 8, 16)
			icon("chevron_selected", ctx.x + 2, ctx.y)
		end
		if icon_name then icon(icon_name, ctx.x + 26, ctx.y) end
		local color = selected and SELECTED_TEXT or (ctx.warning and CREAM or OPTION)
		local shown = fit_text(label, 1, math.max(8, ctx.w - 58), ctx.font)
		pixel_ui.draw_text(Vector(ctx.x + 54, text_y(ctx.y, 4, 1, h)), shown, 1, color, text_opts(ctx.font))
	end
	ctx.y = ctx.y + h
end

local function footer(ctx, hint)
	ctx.y = ctx.y + space(ctx)
	local h = 16
	if ctx.draw then
		paint("divider", ctx.x, ctx.y, ctx.w, 2, 8, 2)
		local shown = fit_text(hint, 1, math.max(8, ctx.w - 8), ctx.font)
		pixel_ui.draw_text(Vector(ctx.x + 4, ctx.y + 4), shown, 1, ctx.warning and CREAM or HINT, text_opts(ctx.font))
	end
	ctx.y = ctx.y + h
end

local function choices(ctx, opts, cursor, warning)
	for i, choice in ipairs(opts) do
		choice_row(ctx, choice_label(choice), choice_icon(choice, i == cursor, warning), i == cursor)
	end
end

local function read_money(ctx, player)
	if ctx.sample then
		return tonumber(ctx.sample.cash) or 0, tonumber(ctx.sample.deposit) or 0
	end
	return player and player:GetNumCoins() or 0, bank_state.get_deposit()
end

local function read_loan(ctx)
	if ctx.sample then return ctx.sample.loan end
	return bank_state.get_active_loan()
end

local function layout_saving(ctx, player, sess)
	local cash, deposit = read_money(ctx, player)
	local cash_text = tostring(cash) .. "¢"
	local bank_text = tostring(deposit) .. "¢"
	begin_body(ctx, tr("储蓄业务", "Savings"))
	if sess.page == "root" then
		local left_label = tr("随身现金", "Cash")
		local right_label = tr("银行存款", "Bank")
		if stat_pair_fits(ctx, left_label, cash_text, right_label, bank_text) then
			stat_pair(ctx, "coins", left_label, cash_text, "vault", right_label, bank_text)
		else
			info_line(ctx, "coins", left_label, cash_text, INK)
			info_line(ctx, "vault", right_label, bank_text, INK)
		end
		local interest = ctx.sample and ctx.sample.interest or bank_state.preview_interest(deposit)
		info_line(ctx, "coins", tr("下次结息预计", "Next return"), "+" .. tostring(interest) .. "¢", GREEN)
		choices(ctx, {"deposit", "withdraw", "exit"}, sess.cursor or 1, false)
		footer(ctx, tr("上下选择   使用键确认   丢弃键返回", "Up/Down  Item confirm  Drop back"))
		return
	end
	local opts = {1, 5, 10, "all"}
	local choice = opts[sess.cursor] or opts[1]
	local amount
	if choice == "all" then
		amount = sess.page == "deposit" and cash or deposit
	else
		amount = amount_of(player, sess, choice)
	end
	local cash_after, bank_after, verb
	if sess.page == "deposit" then
		verb = tr("存入", "Deposit")
		cash_after = cash - amount
		bank_after = deposit + amount
	else
		verb = tr("取出", "Withdraw")
		cash_after = cash + amount
		bank_after = deposit - amount
	end
	hero(ctx, (choice == "all" and tr("全部 ", "ALL ") or "") .. tostring(amount) .. "¢")
	plain_line(ctx, verb .. tr("后现金", " cash"), tostring(cash_after) .. "¢")
	plain_line(ctx, verb .. tr("后存款", " bank"), tostring(bank_after) .. "¢")
	choices(ctx, opts, sess.cursor or 1, false)
	footer(ctx, tr("上下选择   使用键确认   丢弃键返回", "Up/Down  Item confirm  Drop back"))
end

local function collectible_display_name(player, item_id, fallback)
	if not player or not item_id then
		return fallback or tostring(item_id or "")
	end
	local lang = Options and Options.Language or ""
	local ok, hash = pcall(GetPtrHash, player)
	local key = tostring(ok and hash or 0) .. ":" .. tostring(item_id) .. ":" .. tostring(lang)
	if panel._display_name_key == key then
		return panel._display_name_value
	end
	local text = item_displaying_holder.resolve_display_text(player, "Item", item_id)
	local shown = (text and text.Name) or fallback or tostring(item_id)
	panel._display_name_key = key
	panel._display_name_value = shown
	return shown
end

local function item_block(ctx, item_id, name, detail)
	local h = 40
	if ctx.draw then
		render_item_icon(item_id or 1, ctx.x + 4, ctx.y + 4, 32)
		local shown = fit_text(name, 1, math.max(8, ctx.w - 48), ctx.font)
		local name_color = ctx.warning and CREAM or LABEL
		pixel_ui.draw_text(Vector(ctx.x + 44, text_y(ctx.y, 4, 1, h)), shown, 1, name_color, text_opts(ctx.font))
		pixel_ui.draw_text(Vector(ctx.x + 44, text_y(ctx.y, 20, 1, h)), detail, 1, name_color, text_opts(ctx.font))
	end
	ctx.y = ctx.y + h
end

local GRID_COLS = 4
local GRID_ROWS = 4
local GRID_PAGE = GRID_COLS * GRID_ROWS
local GRID_CELL = 30
local GRID_GAP = 3

local function collateral_header(ctx, subtitle, page, pages)
	local h = 20
	if ctx.draw then
		paint("brass", ctx.x, ctx.y, ctx.w, h, 8, 12)
		local line = string.format("%s  %d/%d", subtitle, page or 1, pages or 1)
		pixel_ui.draw_text(
			Vector(ctx.x + 8, text_y(ctx.y, 2, 1, h)),
			fit_text(line, 1, math.max(8, ctx.w - 16), ctx.font),
			1, CREAM, text_opts(ctx.font)
		)
	end
	ctx.y = ctx.y + h
end

local function paint_cell_frame(x, y, size)
	paint("gold", x, y, size, 2, 8, 2)
	paint("gold", x, y + size - 2, size, 2, 8, 2)
	paint("gold", x, y, 2, size, 2, 8)
	paint("gold", x + size - 2, y, 2, size, 2, 8)
end

local function candidate_named(ctx, player, row)
	if not row then return "" end
	if ctx.sample then return row.name or tostring(row.id) end
	return collectible_display_name(player, row.id, row.name or row.id)
end

local function find_selected(list, item_id)
	if not item_id then return nil end
	for _, row in ipairs(list) do
		if row.id == item_id then return row end
	end
	return nil
end

local function layout_collateral(ctx, player, sess)
	local list = sess.candidates or {}
	local ui = sess.loan_ui or {}
	local count = #list
	local pages = math.max(1, math.ceil(count / GRID_PAGE))
	if pages < 1 then pages = 1 end
	local page = tonumber(ui.page) or 1
	if page < 1 then page = 1 end
	if page > pages then page = pages end
	local focus = tonumber(ui.focus_index) or 1
	local phase = ui.phase == "confirm" and "confirm" or "browse"
	local fold = ctx.fold_grid == true and phase == "confirm"
	local spare = ctx.spare_collateral == true
	local subtitle = sess.page == "replace" and tr("更换抵押物", "Replace collateral") or tr("选择抵押物", "Collateral")
	collateral_header(ctx, subtitle, page, pages)
	if not fold then
		local grid_w = GRID_COLS * GRID_CELL + (GRID_COLS - 1) * GRID_GAP
		local grid_h = GRID_ROWS * GRID_CELL + (GRID_ROWS - 1) * GRID_GAP
		local origin_x = ctx.x + math.floor((ctx.w - grid_w) * 0.5)
		local origin_y = ctx.y + (spare and 0 or 2)
		if ctx.draw then
			for i = 1, GRID_PAGE do
				local index = (page - 1) * GRID_PAGE + i
				local local_i = i - 1
				local col = local_i % GRID_COLS
				local row = math.floor(local_i / GRID_COLS)
				local x = origin_x + col * (GRID_CELL + GRID_GAP)
				local y = origin_y + row * (GRID_CELL + GRID_GAP)
				local item = list[index]
				if item then
					paint("card", x, y, GRID_CELL, GRID_CELL, 8, 8)
					if phase == "browse" and index == focus then
						paint_cell_frame(x, y, GRID_CELL)
					end
					render_item_icon(item.id, x, y, GRID_CELL)
					if item.id == ui.selected_item_id then
						paint("brass", x + GRID_CELL - 10, y + 2, 8, 4, 8, 4)
					end
					local value = tostring(item.value or 0)
					pixel_ui.draw_text(Vector(x + 2, y + GRID_CELL - 12), value, 1, CREAM, text_opts(ctx.font))
				end
			end
		end
		ctx.y = origin_y + grid_h
		if not spare then
			ctx.y = ctx.y + space(ctx)
			local focused = list[focus]
			local focus_text = focused
				and (candidate_named(ctx, player, focused) .. "  " .. tostring(focused.value or 0) .. "¢")
				or tr("没有可抵押道具", "No collateral")
			plain_line(ctx, tr("当前", "Focus"), focus_text)
		end
	end
	local selected = find_selected(list, ui.selected_item_id)
	if phase == "confirm" and selected then
		item_block(
			ctx,
			selected.id,
			candidate_named(ctx, player, selected),
			string.format(tr("待抵押 %d¢", "To pledge %d¢"), selected.value or 0)
		)
	else
		local slot_text = selected
			and (candidate_named(ctx, player, selected) .. "  " .. tostring(selected.value or 0) .. "¢")
			or tr("尚未选择", "None yet")
		if not (spare and phase == "browse" and not selected) then
			plain_line(ctx, tr("待抵押道具", "To pledge"), slot_text)
		end
	end
	if phase == "confirm" then
		local first = sess.page == "replace" and "confirm_replace" or "confirm_loan"
		choices(ctx, {first, "reselect", "back"}, ui.confirm_cursor or 1, false)
		if not spare then
			footer(ctx, tr("上下选择  使用键确认  丢弃键返回", "Up/Down  Item confirm  Drop back"))
		end
	elseif not spare then
		footer(ctx, tr("方向键浏览  使用键放入  丢弃键返回", "Move  Item to pledge  Drop back"))
	end
end

local function layout_loan(ctx, player, sess)
	local loan = read_loan(ctx)
	local warning = sess.page == "due" or sess.page == "missing"
	ctx.warning = warning
	ctx.ink = warning and CREAM or INK
	if sess.page == "pick" or sess.page == "replace" then
		layout_collateral(ctx, player, sess)
		return
	end
	if sess.page == "due" and loan then
		begin_body(ctx, tr("还款到期", "Payment due"))
		hero(ctx, tostring(loan.remaining or loan.principal or 0) .. "¢")
		choices(ctx, {"repay", "forfeit", "exit"}, sess.cursor or 1, true)
		footer(ctx, tr("上下选择   使用键确认   丢弃键返回", "Up/Down  Item confirm  Drop back"))
		return
	end
	if sess.page == "missing" and loan then
		begin_body(ctx, tr("抵押物缺失", "Collateral missing"))
		hero(ctx, tostring(loan.remaining or 0) .. "¢")
		choices(ctx, {"repay", "replace", "exit"}, sess.cursor or 1, true)
		footer(ctx, tr("上下选择   使用键确认   丢弃键返回", "Up/Down  Item confirm  Drop back"))
		return
	end
	if sess.page == "manage" and loan then
		begin_body(ctx, tr("贷款", "Loan"))
		local name
		if ctx.sample and loan.name then
			name = loan.name
		else
			name = collectible_display_name(player, loan.item_id, loan.name or loan.item_id)
		end
		item_block(ctx, loan.item_id, name, tr("抵押物", "Collateral"))
		plain_line(ctx, tr("待还金额", "Remaining"), tostring(loan.remaining or 0) .. "¢")
		choices(ctx, {"repay", "exit"}, sess.cursor or 1, false)
		footer(ctx, tr("上下选择   使用键确认   丢弃键返回", "Up/Down  Item confirm  Drop back"))
		return
	end
	begin_body(ctx, tr("贷款", "Loan"))
	plain_line(ctx, tr("无可抵押道具", "No collateral items"), "")
	choices(ctx, {"exit"}, 1, false)
	footer(ctx, tr("使用键确认   丢弃键返回", "Item confirm  Drop back"))
end

local function feedback_line(ctx, sess)
	local fb = sess.feedback
	if not fb or not fb.message or fb.message == "" then return end
	local h = 24
	if ctx.draw then
		paint(fb.kind == "error" and "warn" or "card", ctx.x, ctx.y, ctx.w, h, 8, 8)
		local shown = fit_text(fb.message, 1, math.max(8, ctx.w - 16), ctx.font)
		local color = fb.kind == "error" and CREAM or GREEN
		pixel_ui.draw_text(Vector(ctx.x + 8, text_y(ctx.y, 4, 1, h)), shown, 1, color, text_opts(ctx.font))
	end
	ctx.y = ctx.y + h + space(ctx)
end

local function layout(ctx, player, sess)
	feedback_line(ctx, sess)
	if sess.mode == "saving" then
		layout_saving(ctx, player, sess)
	else
		layout_loan(ctx, player, sess)
	end
	local inner = ctx.y - ctx.origin
	if not ctx.spare_collateral then
		local rem = inner % 8
		if rem ~= 0 then ctx.y = ctx.y + (8 - rem) end
	end
end

function panel.fit_layout(sess, font, screen, sample, player)
	screen = screen or Vector(480, 270)
	local width = snap_width(screen.X)
	local max_h = math.floor((screen.Y - 16) / 8) * 8
	local function probe(plan)
		local box = {
			draw = false,
			x = 0,
			y = 0,
			origin = 0,
			w = width - BORDER * 2,
			bottom = 10000,
			font = font,
			warning = false,
			ink = INK,
			compact = plan.compact == true,
			fold_grid = plan.fold == true,
			spare_collateral = plan.spare == true,
			sample = sample,
		}
		layout(box, player, sess)
		return box.y - box.origin, box.warning
	end
	local collateral = sess.page == "pick" or sess.page == "replace"
	local confirm = collateral and sess.loan_ui and sess.loan_ui.phase == "confirm"
	local plans = {
		{compact = false, fold = false, spare = false},
		{compact = true, fold = false, spare = false},
	}
	if collateral then
		plans[#plans + 1] = {compact = true, fold = false, spare = true}
	end
	if confirm then
		plans[#plans + 1] = {compact = true, fold = true, spare = true}
	end
	local chosen = plans[1]
	local inner, warning = 0, false
	for _, plan in ipairs(plans) do
		chosen = plan
		inner, warning = probe(plan)
		if inner + BORDER * 2 <= max_h then break end
	end
	return {
		width = width,
		max_h = max_h,
		outer_h = inner + BORDER * 2,
		warning = warning == true,
		fits = inner + BORDER * 2 <= max_h,
		compact = chosen.compact == true,
		fold = chosen.fold == true,
		spare = chosen.spare == true,
	}
end

function panel.render(player, sess, font, sample)
	if not sess or not font then return end
	if not player and not sample then return end
	local screen = gui.GetScreenSize and gui.GetScreenSize() or Vector(480, 270)
	local fit = panel.fit_layout(sess, font, screen, sample, player)
	local width = fit.width
	local height = fit.outer_h
	local warning = fit.warning
	local x = math.floor((screen.X - width) * 0.5 + 0.5)
	local y = math.floor((screen.Y - height) * 0.5 + 0.5)
	if x < 8 then x = 8 end
	if y < 8 then y = 8 end
	frame(x, y, width, height, warning)
	local body = {
		draw = true,
		x = x + BORDER,
		y = y + BORDER,
		origin = y + BORDER,
		w = width - BORDER * 2,
		bottom = y + height - BORDER,
		font = font,
		warning = false,
		ink = INK,
		compact = fit.compact,
		fold_grid = fit.fold,
		spare_collateral = fit.spare,
		sample = sample,
	}
	layout(body, player, sess)
	panel._metrics = {
		outer_h = height,
		max_h = fit.max_h,
		fits = fit.fits,
		compact = fit.compact,
		spare = fit.spare,
		fold = fit.fold,
		x = x,
		y = y,
		w = width,
	}
	if sample and sample.show_bounds and Isaac.DrawLine then
		local col = height <= max_h and KColor(0.35, 0.85, 0.4, 1) or KColor(0.85, 0.25, 0.2, 1)
		local a = Vector(x, y)
		local b = Vector(x + width, y)
		local c = Vector(x + width, y + height)
		local d = Vector(x, y + height)
		Isaac.DrawLine(a, b, col, col, 1)
		Isaac.DrawLine(b, c, col, col, 1)
		Isaac.DrawLine(c, d, col, col, 1)
		Isaac.DrawLine(d, a, col, col, 1)
	end
end

local PREVIEW_PAGES = {
	saving_root = {mode = "saving", page = "root"},
	deposit = {mode = "saving", page = "deposit"},
	withdraw = {mode = "saving", page = "withdraw"},
	pick = {mode = "loan", page = "pick"},
	manage = {mode = "loan", page = "manage"},
	due = {mode = "loan", page = "due"},
	missing = {mode = "loan", page = "missing"},
}

function panel.set_preview(spec)
	if not spec then
		panel._preview = nil
		return
	end
	panel._preview = spec
end

function panel.preview_active()
	return panel._preview ~= nil
end

function panel.preview_metrics()
	return panel._metrics
end

function panel.metrics()
	return panel._metrics
end

function panel.render_preview(font)
	local spec = panel._preview
	if not spec or not font then return end
	local page = PREVIEW_PAGES[spec.page] or PREVIEW_PAGES.saving_root
	local name = spec.item_name or "The Sad Onion"
	local sess = {
		mode = page.mode,
		page = page.page,
		cursor = spec.cursor or 1,
		loan_ui = {
			phase = "browse",
			focus_index = spec.cursor or 1,
			page = 1,
			confirm_cursor = 1,
		},
		candidates = {
			{id = spec.item_id or 1, name = name, value = spec.loan_remaining or 15},
			{id = spec.item_id or 1, name = name, value = (spec.loan_remaining or 15) + 3},
			{id = spec.item_id or 1, name = name, value = (spec.loan_remaining or 15) + 6},
			{id = spec.item_id or 1, name = name, value = (spec.loan_remaining or 15) + 9},
		},
		feedback = spec.show_feedback and {
			kind = "error",
			message = "硬币已达上限，无法足额发放贷款",
		} or nil,
	}
	local sample = {
		cash = spec.cash or 0,
		deposit = spec.deposit or 0,
		interest = spec.interest,
		show_bounds = spec.show_bounds,
		loan = {
			item_id = spec.item_id or 1,
			name = name,
			remaining = spec.loan_remaining or 15,
			principal = spec.loan_remaining or 15,
		},
	}
	panel.render(nil, sess, font, sample)
end

function panel.draw_zone_icon(screen_pos, kind, active)
	if not screen_pos then return end
	local name = kind == "loan" and "lock_world" or "coins_world"
	if active then name = name .. "_selected" end
	icon(name, screen_pos.X - 12, screen_pos.Y - 30)
end

return panel
