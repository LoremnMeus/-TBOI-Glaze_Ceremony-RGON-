-- Blueprint panel geometry / UI model / render.
-- Structural extract from Item_Blue_Print.lua. No gameplay/UI semantic changes.
local save = require("Qing_Remaster_scripts.core.savedata")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local Mouse_UI = require("Qing_Remaster_scripts.others.Mouse_UI_holder")
local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")

local M = {}

function M.attach(item, BP)

function BP.get_debug_number(key, default_value)
	local root = save.ModConfigSettings
	local debug_settings = root and root.QingRemasterOptions and root.QingRemasterOptions.Debug
	return tonumber(debug_settings and debug_settings[key]) or default_value
end

function BP.get_debug_bool(key, default_value)
	local root = save.ModConfigSettings
	local debug_settings = root and root.QingRemasterOptions and root.QingRemasterOptions.Debug
	local v = debug_settings and debug_settings[key]
	if v == nil then return default_value and true or false end
	return v == true
end

--- ImGui：显示材料来源角标（原/审）与来源描边；默认关闭

function BP.show_source_marks()
	return BP.get_debug_bool("BlueprintShowSourceMarks", false)
end

--- 全道具审计目录是否允许（Debug 开关；开发树默认开，公开包默认关）

function BP.get_dot_offset()
	local def = item.dot_offset_default or Vector(-2, -9)
	return Vector(
		BP.get_debug_number("BlueprintDotOffsetX", def.X),
		BP.get_debug_number("BlueprintDotOffsetY", def.Y)
	)
end

function BP.get_bg_offset()
	local def = item.bg_offset_default or Vector(0, 0)
	return Vector(
		BP.get_debug_number("BlueprintBgOffsetX", def.X),
		BP.get_debug_number("BlueprintBgOffsetY", def.Y)
	)
end

function BP.get_audit_text_y()
	return BP.get_debug_number("BlueprintAuditTextY", item.audit_text_y_default or 2)
end

function BP.get_cost_y_offset()
	return BP.get_debug_number("BlueprintCostOffsetY", item.cost_offset_y_default or 21)
end

function BP.get_craft_group_y()
	return BP.get_debug_number("BlueprintCraftGroupY", item.craft_group_y_default or 14)
end

function BP.get_tag_col_offset()
	local def = item.tag_col_offset_default or Vector(-36, 0)
	return Vector(
		BP.get_debug_number("BlueprintTagColOffsetX", def.X),
		BP.get_debug_number("BlueprintTagColOffsetY", def.Y)
	)
end

function BP.get_tag_col_width()
	local n = BP.get_debug_number("BlueprintTagColWidth", item.tag_col_width_default or 56)
	return math.max(40, math.min(96, n))
end

function BP.get_cost_token_scale()
	return BP.get_debug_number("BlueprintCostTokenScale", item.cost_token_scale or 0.5)
end

function BP.get_cost_slot_size()
	local n = BP.get_debug_number("BlueprintCostSlotSize", item.cost_slot_size_default or 18)
	return math.max(8, math.min(48, n))
end

function BP.get_cost_slot_spacing()
	-- 中心距随小槽尺寸：尺寸 + 2
	return BP.get_cost_slot_size() + 2
end

function BP.get_cost_qmark_offset()
	local def = item.cost_qmark_offset_default or Vector(-2, 1)
	return Vector(
		BP.get_debug_number("BlueprintCostQmarkOffsetX", def.X),
		BP.get_debug_number("BlueprintCostQmarkOffsetY", def.Y)
	)
end

function BP.get_cost_extra_count()
	local n = math.floor(BP.get_debug_number("BlueprintCostExtraCount", item.cost_extra_count_default or 0) + 0.5)
	return math.max(0, math.min(12, n))
end

function BP.get_slot_count()
	local n = math.floor(BP.get_debug_number("BlueprintSlotCount", item.slot_count_default or 3) + 0.5)
	return math.max(1, math.min(7, n))
end

function BP.cost_display_count(craft)
	if not craft then return 1 end
	if craft.hide_cost then return 0 end
	local need = craft.required_cost or 0
	local have = #(craft.cost_ids or {})
	return math.max(1, need, have) + BP.get_cost_extra_count()
end

function BP.cost_cols_for_width(avail_w)
	local spacing = BP.get_cost_slot_spacing()
	local max_cols = item.cost_slot_max_cols or 8
	return math.max(1, math.min(max_cols, math.floor(math.max(8, avail_w) / spacing)))
end

function BP.cost_row_count(n, cols)
	if n <= 0 then return 0 end
	return math.ceil(n / math.max(1, cols))
end

--- 成本带相对目标中心的顶/底 oy（材料槽整框不得侵入）；无成本时返回 nil

function BP.cost_band_oy_range(cost_n, avail_w)
	if not cost_n or cost_n <= 0 then return nil, nil, 0 end
	local size = BP.get_cost_slot_size()
	local cost_y = BP.get_cost_y_offset() -- 首行中心
	local cols = BP.cost_cols_for_width(avail_w or 160)
	local rows = math.max(1, BP.cost_row_count(cost_n, cols))
	local row_gap = item.cost_slot_row_gap or 2
	local top = cost_y - size * 0.5
	local bot = top + rows * size + (rows - 1) * row_gap
	return top, bot, rows
end

--- 材料槽椭圆环绕。底座至多 1 个、画在图标下方，不再为成本带预留整行。

function BP.make_slot_layout(n, _cost_n, _avail_w)
	n = math.max(0, math.min(7, n or 0))
	if n <= 0 then return {} end
	local rx = item.slot_ellipse_rx or 56
	local ry = item.slot_ellipse_ry or 28
	if n == 1 then return {{ox = rx, oy = 0}} end
	local start = (n % 2 == 0) and (-90 + 180 / n) or -90
	local out = {}
	for i = 1, n do
		local ang = math.rad(start + (i - 1) * (360 / n))
		out[i] = {ox = math.cos(ang) * rx, oy = math.sin(ang) * ry}
	end
	return out
end

--- 按当前成本行数刷新材料槽偏移（每帧，保证成本带始终占行）

function BP.refresh_slot_offsets(craft, avail_w)
	if not craft or not craft.slots then return end
	local n = #craft.slots
	local cost_n = BP.cost_display_count(craft)
	local layout = BP.make_slot_layout(n, cost_n, avail_w)
	for i, slot in ipairs(craft.slots) do
		local L = layout[i]
		if L then
			slot._to_ox = L.ox
			slot._to_oy = L.oy
			local anim_t = slot._anim_t
			if anim_t ~= nil and anim_t < 1 then
				anim_t = math.min(1, anim_t + 0.14)
				slot._anim_t = anim_t
				local t = anim_t * anim_t * (3 - 2 * anim_t)
				local fx = slot._from_ox or 0
				local fy = slot._from_oy or 0
				slot.ox = fx + (L.ox - fx) * t
				slot.oy = fy + (L.oy - fy) * t
			else
				slot.ox = L.ox
				slot.oy = L.oy
				slot._anim_t = nil
			end
		end
	end
end

function BP.ensure_cost_qmark_sprite()
	-- alchemy_pot_item：pivot 16,16 居中；贴图可单独替换
	local path = item.cost_qmark_path or "gfx/effects/questionmark_black.png"
	if item._cost_qmark and item._cost_qmark_ver == 3 and item._cost_qmark_path == path then
		return item._cost_qmark
	end
	local s = Sprite()
	s:Load("gfx/mimics/Alchemy_Pot/alchemy_pot_item.anm2", true)
	s:ReplaceSpritesheet(0, path)
	s:LoadGraphics()
	s:Play("Idle", true)
	item._cost_qmark = s
	item._cost_qmark_path = path
	item._cost_qmark_ver = 3
	return s
end

function BP.panel_alpha()
	local a = item._draw_alpha
	if a == nil then return 1 end
	return a
end

function BP.tint_kcolor(color, mul_a)
	color = color or KColor(1, 1, 1, 1)
	mul_a = mul_a or BP.panel_alpha()
	return KColor(color.Red, color.Green, color.Blue, (color.Alpha or 1) * mul_a)
end

function BP.tint_color(r, g, b, a)
	return Color(r or 1, g or 1, b or 1, (a or 1) * BP.panel_alpha())
end

local TUT_DIM = KColor(0.4, 0.4, 0.46, 0.42)
function BP.tut_dim_id(id, color)
	if BP.get_tutorial().is_locking() and not BP.get_tutorial().allows(id) then
		return TUT_DIM
	end
	return color
end

--- 成本小槽中的道具不参与配方效果：无论其原始状态，图标都显示为真灰度。
--- 这里只供 tok.cost 使用；背包/材料槽继续沿用原有 Tint 状态色。

function BP.cost_token_color()
	local a = BP.panel_alpha()
	return auxi.table2color({R = 0.88, G = 0.88, B = 0.88, A = a * 0.88, RC = 1, GC = 1, BC = 1, AC = 1})
end

function BP.clear_sprite_color(spr)
	if not spr then return end
	spr.Color = auxi.table2color({R = 1, G = 1, B = 1, A = 1, RC = 0, GC = 0, BC = 0, AC = 0})
end

function BP.is_mirror_only_token(tok)
	if not tok then return false end
	if tok.mirror_copy == true then return true end
	local id = tok.id
	return type(id) == "string" and (id:sub(1, 7) == "mirror_" or id:sub(1, 11) == "mirrorfill_")
end

function BP.apply_mirror_token_visual(spr, col_id)
	if not spr then return end
	if REPENTOGON then
		temp_hud.apply_sprite_shader(spr, item.mirror_shader)
		local t = (Game():GetFrameCount() % 150) / 150
		local seed = ((tonumber(col_id) or 0) * 0.061803399) % 1
		local col = Color(1, 1, 1, 1, 0, 0, 0)
		if col.SetColorize then
			col:SetColorize(seed, 1.0, 0, t)
		else
			col = Color(1, 1, 1, 1, 0, 0, 0, seed, 1.0, 0, t)
		end
		spr.Color = col
	else
		spr.Color = BP.tint_color(0.68, 0.9, 1.0, 0.98)
	end
end

function BP.clear_mirror_token_visual(spr)
	if not spr then return end
	if REPENTOGON then
		temp_hud.clear_sprite_shader(spr)
	end
	BP.clear_sprite_color(spr)
end

--- 在矩形内绘制文本（水平居中 + 垂直居中；可选左对齐留白）

function BP.draw_text_in_rect(rect, text, color, opts)
	if not rect or not text then return end
	opts = opts or {}
	local sx = opts.sx or 1
	local sy = opts.sy or 1
	local font = opts.font or gui.f
	local line_h = (font.GetLineHeight and font:GetLineHeight() or 12) * sy
	local pad_x = opts.pad_x or 0
	local y = rect.y + (opts.pad_y ~= nil and opts.pad_y or ((rect.h - line_h) * 0.5))
	local x = rect.x + pad_x
	local box_w = math.max(0, math.floor(rect.w - pad_x * 2))
	color = BP.tint_kcolor(color)
	if opts.align == "left" then
		font:DrawStringScaledUTF8(text, x, y, sx, sy, color, 0, false)
	else
		font:DrawStringScaledUTF8(text, x, y, sx, sy, color, box_w, true)
	end
end

function BP.lang_is_zh()
	return Options.Language == "zh" or Options.Language == "zh_cn"
end

function BP.tab_label(tab)
	return BP.lang_is_zh() and tab.zh or tab.en
end

function BP.ensure_bg_sprite()
	if item._bg_sprite == nil then
		local s = Sprite()
		s:Load(item.bg_anm2, true)
		s:Play("Idle", true)
		item._bg_sprite = s
	end
	return item._bg_sprite
end

function BP.ensure_charge_slider_sprite()
	if item._charge_slider_sprite == nil then
		local s = Sprite()
		s:Load("gfx/mimics/Blueprint/slider.anm2", true)
		s:SetFrame("Idle", 0)
		item._charge_slider_sprite = s
	end
	return item._charge_slider_sprite
end

function BP.slider_layer_color(kcolor, alpha_mul)
	kcolor = kcolor or KColor(1, 1, 1, 1)
	return Color(
		kcolor.Red, kcolor.Green, kcolor.Blue,
		(kcolor.Alpha or 1) * BP.panel_alpha() * (alpha_mul or 1)
	)
end

function BP.load_col_sprite(col_id)
	if not col_id then return nil end
	item._col_spr_cache = item._col_spr_cache or {}
	local cached = item._col_spr_cache[col_id]
	if cached then return cached end
	local spr = auxi.load_item(col_id, {
		Anm = "gfx/mimics/Alchemy_Pot/alchemy_pot_item.anm2",
	})
	item._col_spr_cache[col_id] = spr
	return spr
end

function BP.quality_to_frame(quality)
	local q = tonumber(quality)
	if q == nil then return 5 end
	if q >= 0 and q <= 4 then return math.floor(q) end
	if q < 0 then return 5 end
	return 6
end

function BP.get_quality_sprite()
	if item._quality_spr then return item._quality_spr end
	local s = Sprite()
	s:Load(item.quality_anm2, true)
	s:Play("Quality", true)
	item._quality_spr = s
	return s
end

function BP.render_token_quality_icon(tok)
	if not tok or tok.cost or tok.slot then return end
	if not tok.from_bag then return end
	local q = CraftProfile.collectible_quality(tok.collectible)
	if q == nil then return end
	local s = BP.get_quality_sprite()
	s.Color = Color(1, 1, 1, BP.panel_alpha())
	s:SetFrame("Quality", BP.quality_to_frame(q))
	s:Render(tok.pos + (item.quality_icon_offset or Vector(8, -12)), Vector.Zero, Vector.Zero)
	s.Color = Color(1, 1, 1, 1)
end

function BP.token_rect(tok)
	return Mouse_UI.make_rect_centered(tok.pos, item.token_size, item.token_size)
end

function BP.clamp_to_rect(pos, rect, half)
	half = half or item.token_size * 0.5
	return Vector(
		math.max(rect.x + half, math.min(rect.x + rect.w - half, pos.X)),
		math.max(rect.y + half, math.min(rect.y + rect.h - half, pos.Y))
	)
end

function BP.smoothstep(t)
	t = math.max(0, math.min(1, t))
	return t * t * (3 - 2 * t)
end

function BP.bag_area_anchor(tok)
	local panel = item.panel
	local craft = panel and panel.craft
	local g = panel and panel.ui and panel.ui.craft_geom
	local bag = g and g.bag_inner
	if not bag then
		if tok then return Vector(tok.pos.X + 40, tok.pos.Y) end
		return Vector(0, 0)
	end

	local tsize = item.token_size or 28
	local cell = tsize + 4
	local cols = math.max(1, math.floor(bag.w / cell))

	-- 当前页背包图标占用的行数（与 bag_layout_positions 一致）
	local page_count = 0
	if craft then
		for _, t in ipairs(craft.tokens or {}) do
			if t.from_bag then page_count = page_count + 1 end
		end
	end
	local rows_used = (page_count > 0) and math.ceil(page_count / cols) or 0
	local free_top = bag.y + rows_used * cell + 2
	local free_bottom = bag.y + bag.h - 6
	if free_top > free_bottom - tsize then
		free_top = math.max(bag.y + 2, free_bottom - tsize)
	end

	-- 已在空隙带落脚的挤出物，横向错开
	local taken = {}
	if craft then
		for _, t in ipairs(craft.tokens or {}) do
			if t ~= tok and not t.from_bag and not t.slot and not t.cost then
				local p = t.home or (t.anim and t.anim.to) or t.pos
				if p and p.Y >= free_top - cell * 0.35 then
					taken[#taken + 1] = p
				end
			end
		end
	end

	local function blocked(px, py)
		for _, p in ipairs(taken) do
			if math.abs(p.X - px) < cell * 0.85 and math.abs(p.Y - py) < cell * 0.85 then
				return true
			end
		end
		return false
	end

	local y = free_top + tsize * 0.5
	local x0 = bag.x + tsize * 0.5 + 2
	local x = x0
	local guard = 0
	while blocked(x, y) and guard < 48 do
		x = x + cell
		if x > bag.x + bag.w - tsize * 0.5 then
			x = x0
			y = y + cell
			if y > free_bottom - tsize * 0.25 then
				y = free_top + tsize * 0.5
			end
		end
		guard = guard + 1
	end
	return Vector(x, y)
end

function BP.tick_token_anim(tok)
	local a = tok.anim
	if not a then return false end
	a.t = a.t + 1
	local u = BP.smoothstep(a.t / a.dur)
	tok.pos = auxi.Lerp(a.from, a.to, u)
	if a.t >= a.dur then
		tok.pos = Vector(a.to.X, a.to.Y)
		tok.anim = nil
		return false
	end
	return true
end

function BP.page_slice(list, page, page_size)
	page = math.max(0, page or 0)
	page_size = page_size or item.bag_page_size
	local total = #list
	local pages = math.max(1, math.ceil(total / page_size))
	if page >= pages then page = pages - 1 end
	local from = page * page_size + 1
	local to = math.min(total, from + page_size - 1)
	local slice = {}
	for i = from, to do
		slice[#slice + 1] = list[i]
	end
	return slice, page, pages, total
end

function BP.bag_layout_positions(bag_rect, count)
	local positions = {}
	local cell = item.token_size + 4
	local cols = math.max(1, math.floor(bag_rect.w / cell))
	for i = 1, count do
		local idx = i - 1
		local cx = bag_rect.x + (idx % cols) * cell + item.token_size * 0.5 + 2
		local cy = bag_rect.y + math.floor(idx / cols) * cell + item.token_size * 0.5 + 2
		positions[i] = Vector(cx, cy)
	end
	return positions
end

-- ---------- 制造页几何 ----------

function BP.craft_geometry(panel_rect, content, craft)
	local mid = content.x + content.w * 0.42
	local left = Mouse_UI.make_rect(content.x, content.y, mid - content.x - 4, content.h)
	local right = Mouse_UI.make_rect(mid + 4, content.y, content.x + content.w - mid - 4, content.h)
	local target_pos = Vector(left.x + left.w * 0.5, left.y + 48 + BP.get_craft_group_y())
	local confirm_rect = Mouse_UI.make_rect(left.x + 8, left.y + left.h - 22, left.w - 16, 18)
	-- 蓄力条固定 144×12，便于后续用同尺寸贴图替换字符占位绘制。
	local slider_w, slider_h, slider_gap = 144, 12, 3
	local charge_slider_rects = {}
	for i = 1, 2 do
		charge_slider_rects[i] = Mouse_UI.make_rect(
			left.x + (left.w - slider_w) * 0.5,
			confirm_rect.y - 18 - (i - 1) * (slider_h + slider_gap),
			slider_w,
			slider_h
		)
	end
	local back_rect = Mouse_UI.make_rect(panel_rect.x + 8, panel_rect.y + panel_rect.h - 18, 52, 14)
	local qbtn_w = 40
	local quality_rect = Mouse_UI.make_rect(right.x + 2, right.y, qbtn_w, 13)
	local mode_rect = Mouse_UI.make_rect(right.x + 4 + qbtn_w, right.y, right.w - 6 - qbtn_w, 13)
	local hide_gray_rect = nil -- 有效/无效/未实装已并入右侧标签列

	-- 全道具：标签列锚在背包右缘 + ImGui 偏移（默认负 X 靠内侧）；真实背包不占位
	local tag_col = nil
	local bag_right = right
	if craft and craft.all_items then
		local tag_defs = CraftProfile.audit_filter_tag_defs()
		local off = BP.get_tag_col_offset()
		local tag_w = BP.get_tag_col_width()
		local screen = gui.GetScreenSize()
		local screen_w = screen and screen.X or 480
		local tag_x = right.x + right.w + off.X
		local tag_y = right.y + off.Y
		if tag_x + tag_w > screen_w - 2 then
			tag_x = math.max(right.x + 4, screen_w - tag_w - 2)
			tag_w = math.max(40, math.min(tag_w, screen_w - 2 - tag_x))
		end
		if tag_x < 2 then tag_x = 2 end
		local tag_rect = Mouse_UI.make_rect(tag_x, tag_y, tag_w, right.h)
		local btn_h, btn_gap = 11, 2
		local all_rect = Mouse_UI.make_rect(tag_rect.x, tag_rect.y, (tag_w - btn_gap) * 0.5, btn_h)
		local inv_rect = Mouse_UI.make_rect(
			tag_rect.x + all_rect.w + btn_gap, tag_rect.y, tag_w - all_rect.w - btn_gap, btn_h
		)
		local tag_rects = {}
		local y = tag_rect.y + btn_h + 4
		local row_h = 12
		for _, def in ipairs(tag_defs) do
			tag_rects[def.key] = Mouse_UI.make_rect(tag_rect.x, y, tag_w, row_h)
			y = y + row_h + 1
		end
		tag_col = {
			rect = tag_rect,
			all_rect = all_rect,
			invert_rect = inv_rect,
			tag_rects = tag_rects,
			defs = tag_defs,
		}
	end

	local bag_inner = Mouse_UI.make_rect(bag_right.x, bag_right.y + 15, bag_right.w, bag_right.h - 28)
	local prev_rect = Mouse_UI.make_rect(bag_right.x + 2, bag_right.y + bag_right.h - 12, 26, 11)
	local next_rect = Mouse_UI.make_rect(bag_right.x + bag_right.w - 28, bag_right.y + bag_right.h - 12, 26, 11)
	local cost_size = BP.get_cost_slot_size()
	local spacing = BP.get_cost_slot_spacing()
	local row_gap = item.cost_slot_row_gap or 2
	-- 成本小槽在道具图标下方；过多时自动换行；底座槽始终显示
	local display_n = BP.cost_display_count(craft)
	local cost_pos, cost_rect = nil, nil
	local cost_cols, cost_rows = 1, 0
	if display_n > 0 then
		cost_cols = BP.cost_cols_for_width(left.w - 8)
		cost_rows = BP.cost_row_count(display_n, cost_cols)
		cost_pos = Vector(target_pos.X, target_pos.Y + BP.get_cost_y_offset())
		local cols_top = math.min(display_n, cost_cols)
		local block_w = (cols_top - 1) * spacing + cost_size
		local block_h = (cost_rows - 1) * (cost_size + row_gap) + cost_size
		cost_rect = Mouse_UI.make_rect(
			cost_pos.X - block_w * 0.5,
			cost_pos.Y - cost_size * 0.5,
			block_w,
			block_h
		)
	end
	local geom = {
		left = left,
		right = right,
		bag_right = bag_right,
		tag_col = tag_col,
		target_pos = target_pos,
		confirm_rect = confirm_rect,
		charge_slider_rects = charge_slider_rects,
		main_charge_slider_rect = charge_slider_rects[1],
		back_rect = back_rect,
		quality_rect = quality_rect,
		mode_rect = mode_rect,
		hide_gray_rect = hide_gray_rect,
		bag_inner = bag_inner,
		prev_rect = prev_rect,
		next_rect = next_rect,
		cost_pos = cost_pos,
		cost_rect = cost_rect,
		cost_size = cost_size,
		cost_spacing = spacing,
		cost_row_gap = row_gap,
		cost_cols = cost_cols,
		cost_rows = cost_rows,
		cost_display_n = display_n,
	}
	if craft and craft.mirror_slot_enabled then
		local mirror_pos = Vector(target_pos.X, target_pos.Y + (item.mirror_slot_oy or 54))
		geom.mirror_pos = mirror_pos
		geom.mirror_rect = Mouse_UI.make_rect_centered(mirror_pos, item.slot_size, item.slot_size)
	end
	return geom
end

function BP.draw_region_outline(rect, color, force)
	if not force and not item.debug_draw_regions then return end
	if not rect then return end
	color = BP.tint_kcolor(color or KColor(0.4, 0.9, 0.6, 0.8))
	local off = BP.get_dot_offset()
	local step = 8
	for x = 0, rect.w, step do
		gui.draw_ch(Vector(rect.x + x + off.X, rect.y + off.Y), ".", 1, 1, color, true)
		gui.draw_ch(Vector(rect.x + x + off.X, rect.y + rect.h - 2 + off.Y), ".", 1, 1, color, true)
	end
	for y = 0, rect.h, step do
		gui.draw_ch(Vector(rect.x + off.X, rect.y + y + off.Y), ".", 1, 1, color, true)
		gui.draw_ch(Vector(rect.x + rect.w - 2 + off.X, rect.y + y + off.Y), ".", 1, 1, color, true)
	end
end

function BP.build_list_ui(panel, panel_rect, content)
	local entries = {}
	local tab = item.tabs[panel.tab]
	local y0 = content.y + 4
	panel._bw_bar_rect = nil
	panel._form_bench_pages = 1
	if tab.id == "formation" then
		-- 编队页只读一次带宽快照；broken 由仓库/确认路径更新。
		local BW = BP.get_bandwidth()
		local snap = BW.get_snapshot(panel.player)
		panel._bw_summary = {
			used_units = snap.used_units,
			capacity_units = snap.capacity_units,
			used_slots = snap.used_slots,
			capacity_slots = snap.capacity_slots,
			active = #(snap.active or {}),
			standby = #(snap.standby or {}),
		}
		panel._bw_bar_rect = Mouse_UI.make_rect(content.x + 4, y0, content.w - 8, 16)
		y0 = y0 + 20
		local remain_h = content.y + content.h - y0
		local queue_h = math.max(72, math.floor(remain_h * 0.58))
		local bench_h = math.max(56, remain_h - queue_h - 6)
		local queue_rect = Mouse_UI.make_rect(content.x + 4, y0, content.w - 8, queue_h)
		local bench_rect = Mouse_UI.make_rect(content.x + 4, y0 + queue_h + 4, content.w - 8, bench_h)
		local order = snap.order or {}
		local actives = {}
		local hangar = {}
		for _, uid in ipairs(order) do
			local rec = snap.rec_by_uid and snap.rec_by_uid[tostring(uid)]
			if rec then
				if not rec.display_name then BP.refresh_rec_display_name(rec, panel.player) end
				if BP.get_tutorial().should_show_rec(rec) then
					if snap.effective_active[tostring(rec.uid)] == true then
						actives[#actives + 1] = rec
					else
						hangar[#hangar + 1] = rec
					end
				end
			end
		end
		local sum = panel._bw_summary
		local cap_docks = math.max(3, math.floor((tonumber(sum and sum.capacity_slots) or 3) + 0.5))
		local dock_n = cap_docks
		local gap = 6
		local card_w = math.min(96, math.floor((queue_rect.w - gap * (dock_n + 1)) / math.max(1, dock_n)))
		local card_h = queue_rect.h - 16
		local queue_cards = {}
		local layouts = {}
		for i = 1, dock_n do
			local cx = queue_rect.x + gap + (i - 1) * (card_w + gap)
			local rect = Mouse_UI.make_rect(cx, queue_rect.y + 8, card_w, card_h)
			local rec = actives[i]
			if rec then
				local e = {
					uid = "form_q_"..rec.uid,
					kind = "form_card",
					zone = "queue",
					rec = rec,
					label = BP.rec_label(rec),
					active = true,
					active_index = i,
				}
				layouts[#layouts + 1] = {entry = e, rect = rect}
				queue_cards[#queue_cards + 1] = {uid = rec.uid, rect = rect, active_index = i}
			else
				layouts[#layouts + 1] = {
					entry = {uid = "form_dock_"..i, kind = "form_dock", zone = "queue", active_index = i},
					rect = rect,
				}
			end
		end
		local page_size = item.form_bench_page_size or 4
		local pages = math.max(1, math.ceil(#hangar / page_size))
		local page = math.max(0, math.min(pages - 1, panel.form_bench_page or 0))
		panel.form_bench_page = page
		panel._form_bench_pages = pages
		local prev_rect = Mouse_UI.make_rect(bench_rect.x + 2, bench_rect.y + (bench_rect.h - 14) * 0.5, 16, 14)
		local next_rect = Mouse_UI.make_rect(bench_rect.x + bench_rect.w - 18, bench_rect.y + (bench_rect.h - 14) * 0.5, 16, 14)
		layouts[#layouts + 1] = {entry = {uid = "form_prev", kind = "form_page"}, rect = prev_rect}
		layouts[#layouts + 1] = {entry = {uid = "form_next", kind = "form_page"}, rect = next_rect}
		local inner_x = prev_rect.x + prev_rect.w + 4
		local inner_w = next_rect.x - inner_x - 4
		local b_gap = 5
		local b_w = math.min(78, math.floor((inner_w - b_gap * (page_size - 1)) / page_size))
		local b_h = bench_rect.h - 8
		local start_i = page * page_size + 1
		local bench_cards = {}
		for n = 0, page_size - 1 do
			local rec = hangar[start_i + n]
			local bx = inner_x + n * (b_w + b_gap)
			local rect = Mouse_UI.make_rect(bx, bench_rect.y + 4, b_w, b_h)
			if rec then
				local active = snap.effective_active[tostring(rec.uid)] == true
				local e = {
					uid = "form_b_"..rec.uid,
					kind = "form_card",
					zone = "bench",
					rec = rec,
					label = BP.rec_label(rec),
					active = active == true,
				}
				layouts[#layouts + 1] = {entry = e, rect = rect}
				bench_cards[#bench_cards + 1] = {uid = rec.uid, rect = rect}
			end
		end
		panel._form_queue_rect = queue_rect
		panel._form_bench_rect = bench_rect
		panel._form_queue_cards = queue_cards
		panel._form_bench_cards = bench_cards
		return layouts
	elseif tab.id == "build" then
		for i, info in ipairs(item.build_targets) do
			entries[i] = {
				uid = "build_opt_"..i,
				kind = "build_target",
				target = info.id,
				label = BP.target_label(info, panel.player),
				info = info,
			}
		end
	elseif tab.id == "inventory" then
		local del_w = 30
		for _, rec in ipairs(item.get_crafted_list(panel.player)) do
			if rec and rec.uid and BP.get_tutorial().should_show_rec(rec) then
				if not rec.display_name then BP.refresh_rec_display_name(rec, panel.player) end
				entries[#entries + 1] = {
					uid = "stock_"..rec.uid,
					del_uid = "stock_del_"..rec.uid,
					kind = "stock",
					rec = rec,
					label = BP.rec_label(rec),
					broken = rec.broken == true,
				}
			end
		end
		-- del_w 在 layouts 里用
		panel._stock_del_w = del_w
	end

	local layouts = {}
	local y = y0
	local row_h = 28
	local del_w = panel._stock_del_w or 30
	for i, e in ipairs(entries) do
		local rect = Mouse_UI.make_rect(content.x + 4, y, content.w - 8, row_h)
		local del_rect = nil
		local tog_rect, up_rect, dn_rect, ed_rect = nil, nil, nil, nil
		if e.kind == "stock" and e.del_uid then
			del_rect = Mouse_UI.make_rect(rect.x + rect.w - del_w - 3, rect.y + 5, del_w, row_h - 10)
		elseif e.kind == "formation" then
			local bx = rect.x + rect.w - 3
			local bh = row_h - 10
			local by = rect.y + 5
			ed_rect = Mouse_UI.make_rect(bx - 28, by, 28, bh)
			dn_rect = Mouse_UI.make_rect(ed_rect.x - 16, by, 14, bh)
			up_rect = Mouse_UI.make_rect(dn_rect.x - 16, by, 14, bh)
			tog_rect = Mouse_UI.make_rect(up_rect.x - 36, by, 34, bh)
		end
		layouts[i] = {
			entry = e, rect = rect, del_rect = del_rect,
			tog_rect = tog_rect, up_rect = up_rect, dn_rect = dn_rect, ed_rect = ed_rect,
		}
		y = y + row_h + 4
	end
	return layouts
end

function BP.build_and_register_ui(panel)
	local screen = gui.GetScreenSize()
	local panel_rect = item.get_panel_rect()
	local tab_rects = item.get_tab_rects(panel_rect)
	local content = item.get_content_rect(panel_rect)
	local tab = item.tabs[panel.tab]

	Mouse_UI.begin_frame(panel.player)

	local function reg(id, rect, opts)
		opts = opts or {}
		if BP.get_tutorial().is_locking() then
			local allow = BP.get_tutorial().allows(id) == true
			opts.enabled = allow
			if not allow then opts.draggable = false end
		end
		Mouse_UI.register(id, rect, opts)
	end

	-- 拖动跟随
	if panel.drag and panel.craft then
		local tok = panel.craft.token_map[panel.drag.token_id]
		if tok then
			tok.pos = Mouse_UI.mouse - panel.drag.grab_offset
			tok.vel = Mouse_UI.mouse_delta * 0.85
			tok.pos = BP.clamp_to_rect(tok.pos, panel_rect)
		end
	elseif panel.drag and panel.drag.kind == "form_card" then
		panel.drag.pos = Mouse_UI.mouse - panel.drag.grab_offset
	end

	reg("modal_dim", Mouse_UI.make_rect(0, 0, screen.X, screen.Y), {z = item.z_modal, block = true})
	reg("panel_body", panel_rect, {z = item.z_panel, block = true})

	for i = 1, #item.tabs do
		reg("tab_"..i, tab_rects[i], {z = item.z_tab, block = true})
	end

	local ui = {
		panel_rect = panel_rect,
		tab_rects = tab_rects,
		content = content,
		states = {},
		layouts = {},
		craft_geom = nil,
	}

	local in_craft = (panel.view == "craft" or panel.view == "edit") and panel.craft

	if in_craft then
		local g = BP.craft_geometry(panel_rect, content, panel.craft)
		ui.craft_geom = g
		-- 按当前成本块高度刷新材料槽，保证成本行始终被占住
		BP.refresh_slot_offsets(panel.craft, g.left.w - 8)
		BP.rebuild_bag_tokens(panel, g.bag_inner, panel.player)
		-- 按当前槽位解析主武器，刷新条件亮起（炸弹→博士/史诗；剖腹产副武器→678）
		do
			local parts = {}
			for i, slot in ipairs(panel.craft.slots or {}) do
				local tok = slot.token and panel.craft.token_map and panel.craft.token_map[slot.token]
				parts[i] = tostring(tok and tok.collectible or 0)
			end
			local sig = table.concat(parts, ",")
			if panel.craft._preview_sig ~= sig then
				panel.craft._preview_sig = sig
				local ctx = CraftProfile.preview_weapon_context_from_craft(panel.craft, panel.player)
				panel.craft.preview_weapon = ctx.weapon
				panel.craft.preview_list = ctx.list
				for _, tok in ipairs(panel.craft.tokens or {}) do
					local col = tok.collectible
					if col then
						tok.gate_kind = CraftProfile.effect_gate_kind(col)
						tok.form_synergy = CraftProfile.form_synergy_for_collectible(col, panel.player)
						tok.lit = CraftProfile.is_effectively_lit(col, ctx)
					else
						tok.lit = true
						tok.form_synergy = nil
					end
				end
			end
		end
		-- 槽位世界矩形
		for i, slot in ipairs(panel.craft.slots) do
			slot._rect = Mouse_UI.make_rect_centered(
				Vector(g.target_pos.X + slot.ox, g.target_pos.Y + slot.oy),
				item.slot_size, item.slot_size
			)
		end
		BP.tick_tokens(panel, panel_rect, g.bag_inner, g)

		reg("btn_back", g.back_rect, {z = item.z_button, block = true})
		reg("btn_confirm", g.confirm_rect, {z = item.z_button, block = true})
		if g.quality_rect then
			reg("btn_quality", g.quality_rect, {z = item.z_button, block = true})
		end
		if not (panel.craft and panel.craft.tutorial_bag) and BP.all_items_mode_allowed() then
			reg("btn_mode", g.mode_rect, {z = item.z_button, block = true})
		end
		reg("btn_prev", g.prev_rect, {z = item.z_button, block = true})
		reg("btn_next", g.next_rect, {z = item.z_button, block = true})
		if g.tag_col then
			reg("btn_tag_all", g.tag_col.all_rect, {z = item.z_button, block = true})
			reg("btn_tag_invert", g.tag_col.invert_rect, {z = item.z_button, block = true})
			for key, rect in pairs(g.tag_col.tag_rects or {}) do
				reg("btn_tag_"..key, rect, {z = item.z_button, block = true})
			end
		end
		local charge_list = BP.list_charge_sliders(panel.craft)
		ui.charge_sliders = charge_list
		for i, info in ipairs(charge_list) do
			local rect = g.charge_slider_rects and g.charge_slider_rects[i]
			if rect then
				info.rect = rect
				-- 球体在两端会贴住视觉槽边；交互区左右各外扩 8px，比例仍按原 144px 槽计算。
				local hit_rect = Mouse_UI.make_rect(rect.x - 8, rect.y, rect.w + 16, rect.h)
				reg(info.id, hit_rect, {z = item.z_button + 1, block = true})
			end
		end
		if g.cost_rect then
			reg("cost_slot", g.cost_rect, {z = item.z_slot, block = true, drop_target = true})
		end
		if g.mirror_rect then
			reg("mirror_slot", g.mirror_rect, {z = item.z_slot, block = true, drop_target = true})
		end
		for i, slot in ipairs(panel.craft.slots) do
			reg("cslot_"..i, slot._rect, {z = item.z_slot, block = true, drop_target = true})
		end
		for _, tok in ipairs(panel.craft.tokens) do
			local z = item.z_token
			if panel.drag and panel.drag.token_id == tok.id then z = item.z_token + 5 end
			reg(tok.id, BP.token_rect(tok), {z = z, block = true, draggable = true})
		end
	else
		ui.layouts = BP.build_list_ui(panel, panel_rect, content)
		ui.form_queue_rect = panel._form_queue_rect
		ui.form_bench_rect = panel._form_bench_rect
		ui.form_queue_cards = panel._form_queue_cards
		ui.form_bench_cards = panel._form_bench_cards
		if ui.form_queue_rect then
			reg("form_queue", ui.form_queue_rect, {z = item.z_button - 2, block = true, drop_target = true})
		end
		if ui.form_bench_rect then
			reg("form_bench", ui.form_bench_rect, {z = item.z_button - 2, block = true, drop_target = true})
		end
		for _, lay in ipairs(ui.layouts) do
			local z = item.z_button
			local draggable = lay.entry.kind == "form_card"
			if panel.drag and panel.drag.kind == "form_card" and panel.drag.uid == (lay.entry.rec and lay.entry.rec.uid) then
				z = item.z_token + 5
			end
			reg(lay.entry.uid, lay.rect, {z = z, block = true, draggable = draggable})
			if lay.del_rect and lay.entry.del_uid then
				reg(lay.entry.del_uid, lay.del_rect, {z = item.z_button + 2, block = true})
			end
		end
	end

	ui.tut = BP.get_tutorial().prepare_overlay(panel, panel_rect)
	if ui.tut then
		for _, b in ipairs(ui.tut.buttons or {}) do
			local r = b.rect
			reg(b.id, Mouse_UI.make_rect(r.x, r.y, r.w, r.h), {z = item.z_token + 20, block = true})
		end
	end

	Mouse_UI.end_frame()

	ui.hovered = Mouse_UI.get_hovered_id()
	for i = 1, #item.tabs do
		ui.states["tab_"..i] = Mouse_UI.get_state("tab_"..i)
	end
	ui.states.btn_back = Mouse_UI.get_state("btn_back")
	ui.states.btn_confirm = Mouse_UI.get_state("btn_confirm")
	ui.states.btn_quality = Mouse_UI.get_state("btn_quality")
	ui.states.btn_mode = Mouse_UI.get_state("btn_mode")
	ui.states.btn_prev = Mouse_UI.get_state("btn_prev")
	ui.states.btn_next = Mouse_UI.get_state("btn_next")
	ui.states.btn_tag_all = Mouse_UI.get_state("btn_tag_all")
	ui.states.btn_tag_invert = Mouse_UI.get_state("btn_tag_invert")
	if ui.craft_geom and ui.craft_geom.tag_col then
		for _, def in ipairs(ui.craft_geom.tag_col.defs or {}) do
			ui.states["btn_tag_"..def.key] = Mouse_UI.get_state("btn_tag_"..def.key)
		end
	end
	ui.states.main_charge_slider = Mouse_UI.get_state("main_charge_slider")
	ui.states.modal_dim = Mouse_UI.get_state("modal_dim")
	if panel.craft then
		for i = 1, #panel.craft.slots do
			ui.states["cslot_"..i] = Mouse_UI.get_state("cslot_"..i)
		end
		ui.states.mirror_slot = Mouse_UI.get_state("mirror_slot")
		for _, tok in ipairs(panel.craft.tokens) do
			ui.states[tok.id] = Mouse_UI.get_state(tok.id)
		end
	end
	for _, lay in ipairs(ui.layouts) do
		ui.states[lay.entry.uid] = Mouse_UI.get_state(lay.entry.uid)
		if lay.entry.del_uid then
			ui.states[lay.entry.del_uid] = Mouse_UI.get_state(lay.entry.del_uid)
		end
	end
	if ui.tut then
		for _, b in ipairs(ui.tut.buttons or {}) do
			ui.states[b.id] = Mouse_UI.get_state(b.id)
		end
	end
	panel.ui = ui
	return ui
end

-- ---------- 分组四向导航（tabs 与内容分离；边缘前进回第一项）----------

function BP.render_tabs(ui, panel)
	for i, tab in ipairs(item.tabs) do
		local rect = ui.tab_rects[i]
		local st = ui.states["tab_"..i]
		local tid = "tab_"..i
		local on = panel.tab == i
		local focused = BP.focus_equals(panel, tid)
		local color = on and KColor(1, 0.92, 0.45, 1)
			or ((focused or (st and st.hovered)) and KColor(0.9, 1, 1, 1) or KColor(0.65, 0.75, 0.85, 1))
		color = BP.tut_dim_id(tid, color)
		if focused or (BP.get_tutorial().is_locking() and BP.get_tutorial().allows(tid)) then
			BP.draw_region_outline(rect, KColor(1, 0.85, 0.35, 1), true)
		end
		BP.draw_text_in_rect(rect, BP.tab_label(tab), color)
	end
end

function BP.form_card_sprite_color(active, broken)
	local c
	if broken then
		c = Color(1, 0.32, 0.32, 1)
		c:SetColorize(1.55, 0.12, 0.08, 1)
	else
		-- 待命只靠卡框/标题区分；图标保持全彩，避免看起来像不能用。
		c = Color(1, 1, 1, active and 1 or 0.92)
	end
	return c
end

function BP.form_mirror_sprite_color()
	local col = Color(0.72, 0.9, 1.0, 0.95, 0, 0, 0)
	if col.SetColorize then
		col:SetColorize(0.15, 0.45, 1.1, 1)
	end
	return col
end

--- 环绕件：普通模块 + 镜像（同圈同尺寸；镜像仅配色不同）

function BP.form_orbit_parts(rec)
	local base_id, mods, mirror_id = BP.rec_loadout_ids(rec)
	local parts = {}
	for _, id in ipairs(mods or {}) do
		parts[#parts + 1] = {id = id, mirror = false}
	end
	if mirror_id then
		parts[#parts + 1] = {id = mirror_id, mirror = true}
	end
	return base_id, parts
end

--- 仓库行：底座 → 模块 → 镜像，同尺寸横向排开

function BP.stock_loadout_parts(rec)
	local base_id, mods, mirror_id = BP.rec_loadout_ids(rec)
	local parts = {}
	if base_id then
		parts[#parts + 1] = {id = base_id, kind = "base"}
	end
	for _, id in ipairs(mods or {}) do
		parts[#parts + 1] = {id = id, kind = "mod"}
	end
	if mirror_id then
		parts[#parts + 1] = {id = mirror_id, kind = "mirror"}
	end
	return parts
end

function BP.draw_form_col_icon(col_id, pos, scale, col)
	local spr = BP.load_col_sprite(col_id)
	if not spr then return end
	spr.Scale = Vector(scale, scale)
	spr.Color = col
	spr:Render(pos, Vector.Zero, Vector.Zero)
	BP.clear_sprite_color(spr)
	spr.Scale = Vector(1, 1)
end

function BP.draw_stock_loadout_strip(origin, rec)
	if not origin or not rec then return 0 end
	local parts = BP.stock_loadout_parts(rec)
	if #parts < 1 then return 0 end
	local scale = item.stock_loadout_icon_scale or 0.42
	local step = item.stock_loadout_icon_step or 12
	local mod_col = Color(1, 1, 1, 1)
	local mirror_col = BP.form_mirror_sprite_color()
	local base_col = BP.cost_token_color()
	for i, p in ipairs(parts) do
		local col = mod_col
		if p.kind == "base" then
			col = base_col
		elseif p.kind == "mirror" then
			col = mirror_col
		end
		BP.draw_form_col_icon(p.id, Vector(origin.X + (i - 1) * step, origin.Y), scale, col)
	end
	return #parts * step
end

function BP.draw_form_craft_card(rect, rec, active, focused)
	if not rect or not rec then return end
	local broken = rec.broken == true
	local outline = focused and KColor(1, 0.95, 0.45, 1)
		or (active and KColor(0.95, 0.9, 0.55, 0.95) or KColor(0.4, 0.42, 0.5, 0.65))
	BP.draw_region_outline(rect, outline, true)
	local name_h = 12
	local name_rect = Mouse_UI.make_rect(rect.x + 2, rect.y + 1, rect.w - 4, name_h)
	local tcol = active and KColor(1, 0.96, 0.72, 1) or KColor(0.78, 0.8, 0.86, 1)
	if broken then tcol = KColor(1, 0.4, 0.38, 1) end
	BP.draw_text_in_rect(name_rect, BP.rec_label(rec), tcol)
	local craft_col = BP.form_card_sprite_color(active, broken)
	local item_col = Color(1, 1, 1, 1)
	local mirror_col = BP.form_mirror_sprite_color()
	local base_id, orbit = BP.form_orbit_parts(rec)
	local area = Mouse_UI.make_rect(rect.x + 4, rect.y + name_h + 2, rect.w - 8, rect.h - name_h - 6)
	local cx = area.x + area.w * 0.5
	local cy = area.y + area.h * 0.5
	local body_scale = math.min(1.05, math.min(area.w, area.h) * 0.42 / 32)
	if body_scale < 0.7 then body_scale = 0.7 end
	if rec.target then
		BP.draw_form_col_icon(rec.target, Vector(cx, cy), body_scale, craft_col)
	end
	local radius = math.min(area.w, area.h) * 0.34
	if radius < 16 then radius = 16 end
	local item_scale = math.min(0.95, (radius * 0.85) / 32)
	if item_scale < 0.62 then item_scale = 0.62 end
	if base_id then
		local base_oy = math.max(10, radius * 0.42)
		BP.draw_form_col_icon(base_id, Vector(cx, cy + base_oy), item_scale * 0.5, BP.cost_token_color())
	end
	local n = #orbit
	if n < 1 then return end
	local spin = (Game():GetFrameCount() * (item.form_orbit_spin_deg or 0.55)) % 360
	for i = 1, n do
		local ang = spin - 90 + (i - 1) * (360 / n)
		local rad = ang * math.pi / 180
		local px = cx + math.cos(rad) * radius
		local py = cy + math.sin(rad) * radius
		local col = orbit[i].mirror and mirror_col or item_col
		BP.draw_form_col_icon(orbit[i].id, Vector(px, py), item_scale, col)
	end
end

function BP.render_list(ui, panel)
	if panel._bw_bar_rect then
		local sum = panel._bw_summary or {used_slots = 0, capacity_slots = 3}
		local used = tonumber(sum.used_slots) or 0
		local cap = math.max(0.001, tonumber(sum.capacity_slots) or 3)
		local ratio = math.max(0, math.min(1, used / cap))
		local bar = panel._bw_bar_rect
		BP.draw_region_outline(bar, KColor(0.55, 0.7, 0.85, 0.7), true)
		local fill_w = math.max(0, (bar.w - 4) * ratio)
		if fill_w > 1 then
			local fill = Mouse_UI.make_rect(bar.x + 2, bar.y + 2, fill_w, bar.h - 4)
			BP.draw_region_outline(fill, KColor(0.45, 0.85, 1, 0.95), true)
		end
		local txt = BP.lang_is_zh()
			and string.format("控制带宽：%.0f / %.0f", used, cap)
			or string.format("Bandwidth: %.0f / %.0f", used, cap)
		BP.draw_text_in_rect(bar, txt, KColor(0.95, 0.97, 1, 1))
	end
	if ui.form_queue_rect then
		BP.draw_region_outline(ui.form_queue_rect, KColor(0.45, 0.55, 0.7, 0.45), true)
	end
	if ui.form_bench_rect then
		BP.draw_region_outline(ui.form_bench_rect, KColor(0.4, 0.45, 0.55, 0.4), true)
	end
	if #ui.layouts == 0 then
		local msg = BP.lang_is_zh() and "（空）" or "(Empty)"
		BP.draw_text_in_rect(ui.content, msg, KColor(0.7, 0.7, 0.75, 1), {align = "left", pad_x = 8})
		return
	end
	local drag = panel.drag
	for _, lay in ipairs(ui.layouts) do
		local st = ui.states[lay.entry.uid]
		local focused = BP.focus_equals(panel, lay.entry.uid)
		local color = (focused or (st and st.hovered)) and KColor(1, 0.95, 0.55, 1) or KColor(0.8, 0.85, 0.95, 1)
		local e = lay.entry
		local dragging_this = drag and drag.kind == "form_card" and e.rec and drag.uid == e.rec.uid
		if e.kind == "form_card" then
			if not dragging_this then
				local hot = focused or (st and st.hovered) or (panel.form_carry and panel.form_carry.uid == e.rec.uid)
				BP.draw_form_craft_card(lay.rect, e.rec, e.active, hot)
				if BP.get_tutorial().is_locking() and BP.get_tutorial().allows(e.uid) then
					BP.draw_region_outline(lay.rect, KColor(1, 0.9, 0.35, 1), true)
				end
			end
		elseif e.kind == "form_dock" then
			BP.draw_region_outline(lay.rect, (focused or (st and st.hovered)) and KColor(0.85, 0.9, 1, 0.7) or KColor(0.35, 0.4, 0.5, 0.45), true)
		elseif e.kind == "form_page" then
			local txt = (e.uid == "form_prev") and "<" or ">"
			BP.draw_region_outline(lay.rect, (focused or (st and st.hovered)) and KColor(1, 0.85, 0.35, 1) or KColor(0.5, 0.6, 0.7, 0.5), true)
			BP.draw_text_in_rect(lay.rect, txt, color)
		else
			BP.draw_region_outline(lay.rect, (focused or (st and st.hovered)) and KColor(1, 1, 1, 0.9) or KColor(0.5, 0.6, 0.7, 0.5), true)
		if e.info and e.info.gfx then
			if not e._spr then
				e._spr = BP.load_col_sprite(e.target)
			end
			e._spr.Scale = Vector(0.85, 0.85)
			e._spr.Color = BP.tint_color(1, 1, 1, 1)
			e._spr:Render(Vector(lay.rect.x + 18, lay.rect.y + lay.rect.h * 0.5), Vector(0, 0), Vector(0, 0))
			e._spr.Color = Color(1, 1, 1, 1)
			local text_rect = Mouse_UI.make_rect(lay.rect.x + 34, lay.rect.y, lay.rect.w - 38, lay.rect.h)
			BP.draw_text_in_rect(text_rect, e.label, color, {align = "left", pad_x = 2})
		elseif e.kind == "stock" then
			local info = BP.get_target_info(e.rec.target)
			local broken = e.broken or (e.rec and e.rec.broken)
			local icon_tint = broken and BP.tint_color(1, 0.25, 0.25, 1) or BP.tint_color(1, 1, 1, 1)
			if info then
				if not e._spr then e._spr = BP.load_col_sprite(e.rec.target) end
				e._spr.Scale = Vector(0.85, 0.85)
				e._spr.Color = icon_tint
				e._spr:Render(Vector(lay.rect.x + 18, lay.rect.y + lay.rect.h * 0.5), Vector(0, 0), Vector(0, 0))
				BP.clear_sprite_color(e._spr)
			end
			local strip_origin = Vector(lay.rect.x + 34, lay.rect.y + lay.rect.h * 0.5)
			local strip_w = BP.draw_stock_loadout_strip(strip_origin, e.rec)
			local del_w = (lay.del_rect and lay.del_rect.w) or 30
			local text_x = lay.rect.x + 34 + strip_w + (strip_w > 0 and 4 or 0)
			local text_rect = Mouse_UI.make_rect(
				text_x,
				lay.rect.y,
				math.max(24, lay.rect.x + lay.rect.w - text_x - del_w - 8),
				lay.rect.h
			)
			local tcol = broken and KColor(1, 0.35, 0.35, 1)
				or ((focused or (st and st.hovered)) and KColor(1, 0.95, 0.55, 1) or KColor(0.8, 0.85, 0.95, 1))
			tcol = BP.tut_dim_id(e.uid, tcol)
			if BP.get_tutorial().is_locking() and BP.get_tutorial().allows(e.uid) then
				BP.draw_region_outline(lay.rect, KColor(1, 0.9, 0.35, 1), true)
			end
			if broken then
				BP.draw_region_outline(lay.rect, KColor(1, 0.3, 0.3, 0.85), true)
			end
			BP.draw_text_in_rect(text_rect, e.label, tcol, {align = "left", pad_x = 2})
			if lay.del_rect and e.del_uid then
				local dst = ui.states[e.del_uid]
				local del_focused = BP.focus_equals(panel, e.del_uid)
				local armed = panel.delete_confirm_uid == e.rec.uid
				local dcol = armed and KColor(1, 0.35, 0.3, 1)
					or ((del_focused or (dst and dst.hovered)) and KColor(1, 0.7, 0.55, 1) or KColor(0.95, 0.55, 0.5, 0.95))
				dcol = BP.tut_dim_id(e.del_uid, dcol)
				if BP.get_tutorial().is_locking() and BP.get_tutorial().allows(e.del_uid) then
					BP.draw_region_outline(lay.del_rect, KColor(1, 0.45, 0.35, 1), true)
				else
					BP.draw_region_outline(lay.del_rect, (del_focused or armed) and KColor(1, 0.45, 0.35, 1) or KColor(0.7, 0.35, 0.35, 0.7), true)
				end
				local dtxt = armed
					and (BP.lang_is_zh() and "确认?" or "OK?")
					or (BP.lang_is_zh() and "删" or "Del")
				BP.draw_text_in_rect(lay.del_rect, dtxt, dcol)
			end
		else
			BP.draw_text_in_rect(lay.rect, e.label, color, {align = "left", pad_x = 8})
		end
		end
	end
	if drag and drag.kind == "form_card" and drag.rec and drag.pos then
		local r = Mouse_UI.make_rect(drag.pos.X, drag.pos.Y, drag.w or 72, drag.h or 80)
		BP.draw_form_craft_card(r, drag.rec, true, true)
	end
end

function BP.render_craft(ui, panel)
	local g = ui.craft_geom
	local craft = panel.craft
	local player = panel.player
	local zh = BP.lang_is_zh()

	-- 背包左边：道具品质显示。默认关，底座空时自动开。
	if g.quality_rect then
		local qst = ui.states.btn_quality
		local q_focused = BP.focus_equals(panel, "btn_quality")
		local q_on = craft.show_quality == true
		local q_txt = zh and (q_on and "品质开" or "品质关") or (q_on and "Q.On" or "Q.Off")
		local qc
		if q_focused or (qst and qst.hovered) then
			qc = KColor(1, 0.95, 0.5, 1)
		elseif q_on then
			qc = KColor(0.95, 0.85, 0.45, 1)
		else
			qc = KColor(0.55, 0.58, 0.62, 1)
		end
		if q_focused then BP.draw_region_outline(g.quality_rect, KColor(1, 0.85, 0.35, 1), true) end
		BP.draw_text_in_rect(g.quality_rect, q_txt, qc)
	end
	-- 背包 / 全道具切换；全道具下用右侧标签列筛选（有效/无效/未实装 + 类别）
	if craft.tutorial_bag then
		BP.draw_text_in_rect(g.mode_rect, zh and "教学背包" or "LESSON", KColor(0.7, 0.82, 0.9, 1))
	elseif BP.all_items_mode_allowed() then
		local mst = ui.states.btn_mode
		local mode_focused = BP.focus_equals(panel, "btn_mode")
		local mode_txt = craft.all_items
			and (zh and "全道具" or "ALL")
			or (zh and "背包" or "BAG")
		local mc = (mode_focused or (mst and mst.hovered)) and KColor(1, 0.95, 0.5, 1)
			or (craft.all_items and KColor(1, 0.75, 0.45, 1) or KColor(0.7, 0.9, 0.8, 1))
		if mode_focused then BP.draw_region_outline(g.mode_rect, KColor(1, 0.85, 0.35, 1), true) end
		BP.draw_text_in_rect(g.mode_rect, mode_txt, mc)
	end
	if g.tag_col then
		local enabled = craft.tag_enabled or CraftProfile.default_audit_tag_enabled()
		local all_st = ui.states.btn_tag_all
		local all_focused = BP.focus_equals(panel, "btn_tag_all")
		local all_c = (all_focused or (all_st and all_st.hovered)) and KColor(1, 0.95, 0.5, 1) or KColor(0.85, 0.9, 1, 1)
		if all_focused then BP.draw_region_outline(g.tag_col.all_rect, KColor(1, 0.85, 0.35, 1), true) end
		BP.draw_text_in_rect(g.tag_col.all_rect, zh and "全开" or "All", all_c)
		local inv_st = ui.states.btn_tag_invert
		local inv_focused = BP.focus_equals(panel, "btn_tag_invert")
		local inv_c = (inv_focused or (inv_st and inv_st.hovered)) and KColor(1, 0.95, 0.5, 1) or KColor(0.85, 0.9, 1, 1)
		if inv_focused then BP.draw_region_outline(g.tag_col.invert_rect, KColor(1, 0.85, 0.35, 1), true) end
		BP.draw_text_in_rect(g.tag_col.invert_rect, zh and "反转" or "Inv", inv_c)
		for _, def in ipairs(g.tag_col.defs or {}) do
			local rect = g.tag_col.tag_rects and g.tag_col.tag_rects[def.key]
			if rect then
				local bid = "btn_tag_"..def.key
				local st = ui.states[bid]
				local focused = BP.focus_equals(panel, bid)
				local on = enabled[def.key] == true
				local label = zh and def.zh or def.en
				local tc
				if focused or (st and st.hovered) then
					tc = KColor(1, 0.95, 0.5, 1)
				elseif not on then
					tc = KColor(0.45, 0.45, 0.5, 0.85)
				elseif def.key == "valid" then
					tc = KColor(0.55, 0.95, 0.65, 1)
				elseif def.key == "invalid" then
					tc = KColor(0.75, 0.75, 0.8, 1)
				elseif def.key == "unimplemented" then
					tc = KColor(1, 0.82, 0.3, 1)
				else
					tc = KColor(0.7, 0.95, 0.85, 1)
				end
				if focused then BP.draw_region_outline(rect, KColor(1, 0.85, 0.35, 1), true) end
				BP.draw_text_in_rect(rect, label, tc, {align = "left", pad_x = 2})
			end
		end
	end
	if panel.pad_carry then
		local tip = Mouse_UI.make_rect(g.left.x, g.left.y + 12, g.left.w, 12)
		BP.draw_text_in_rect(tip, zh and "搬运中:选槽位/背包放置" or "Carrying: slot/bag", KColor(1, 0.8, 0.4, 1), {align = "left", pad_x = 4})
	end

	-- 目标
	if not craft._target_spr then
		craft._target_spr = BP.load_col_sprite(craft.target)
	end
	craft._target_spr.Scale = Vector(0.95, 0.95)
	craft._target_spr.Color = BP.tint_color(1, 1, 1, 1)
	craft._target_spr:Render(g.target_pos, Vector(0, 0), Vector(0, 0))
	craft._target_spr.Color = Color(1, 1, 1, 1)
	local title_rect = Mouse_UI.make_rect(g.left.x, g.left.y, g.left.w, 14)
	local title_txt = BP.craft_preview_name(craft, panel.player)
	if not title_txt or title_txt == "" then title_txt = BP.target_label(craft.info, panel.player) end
	local title_broken = false
	if craft.edit_uid and panel.player then
		local erec = item.find_craft(panel.player, craft.edit_uid)
		title_broken = erec and erec.broken == true
		if title_broken then title_txt = "!" .. title_txt end
	end
	BP.draw_text_in_rect(title_rect, title_txt, title_broken and KColor(1, 0.35, 0.35, 1) or KColor(1, 0.95, 0.7, 1))

	-- 成本小槽（可多行；空槽画问号；不显示成本文字）
	if g.cost_rect and (g.cost_display_n or 0) > 0 then
		local need = craft.required_cost or 0
		local have = #(craft.cost_ids or {})
		local real_cost_n = 0
		for _, tid in ipairs(craft.cost_ids or {}) do
			local tok = craft.token_map[tid]
			if tok and tok.source ~= "audit" then
				real_cost_n = real_cost_n + 1
			end
		end
		local pure_audit = CraftProfile.craft_is_pure_audit(
			BP.read_ingredients(craft), BP.read_cost_items(craft), false
		)
		local ok = pure_audit or real_cost_n >= need
		local ccol = ok and KColor(0.55, 0.9, 0.65, 0.95) or KColor(1, 0.55, 0.45, 0.95)
		local focus_cost = BP.focus_equals(panel, "cost_slot")
		local display_n = g.cost_display_n or BP.cost_display_count(craft)
		local cell = g.cost_size or BP.get_cost_slot_size()
		local qmark = BP.ensure_cost_qmark_sprite()
		local qscale = BP.get_cost_token_scale()
		local qoff = BP.get_cost_qmark_offset()
		for i = 1, display_n do
			local p = BP.cost_stack_pos(craft, g, i)
			local cell_rect = Mouse_UI.make_rect_centered(p, cell, cell)
			local filled = i <= have
			local outline = focus_cost and KColor(1, 0.9, 0.35, 1)
				or (filled and KColor(0.55, 0.9, 0.65, 0.85) or ccol)
			-- 已放入道具时不画槽框，避免边框压在图标上；聚焦成本行时仍高亮
			if not filled or focus_cost then
				BP.draw_region_outline(cell_rect, outline, true)
			end
			if not filled then
				qmark.Scale = Vector(qscale, qscale)
				qmark.Color = Color(1, 1, 1, 0.9)
				qmark:SetFrame("Idle", 0)
				qmark:Render(p + qoff, Vector(0, 0), Vector(0, 0))
				qmark.Color = Color(1, 1, 1, 1)
			end
		end
	end

	-- 槽位
	local lowest_y = g.target_pos.Y + 16
	for i, slot in ipairs(craft.slots) do
		local st = ui.states["cslot_"..i]
		local sid = "cslot_"..i
		local focused = BP.focus_equals(panel, sid)
		local near = focused
		if panel.drag then
			local tok = craft.token_map[panel.drag.token_id]
			if tok and slot._rect and (tok.pos - Mouse_UI.rect_center(slot._rect)):Length() <= item.snap_dist then
				near = true
			end
		end
		if panel.pad_carry and focused then near = true end
		local filled = slot.token ~= nil
		local outline = near and KColor(1, 0.95, 0.4, 1)
			or ((st and st.hovered) and KColor(1, 1, 1, 0.9) or KColor(0.55, 0.7, 0.95, 0.85))
		-- 空槽常显框；满槽仅在靠近/聚焦/悬停时高亮，否则不画边框
		if not filled or near or focused or (st and st.hovered) then
			BP.draw_region_outline(slot._rect, outline, true)
		end
		if not filled and not (panel.pad_carry and focused) then
			BP.draw_text_in_rect(slot._rect, "+", KColor(0.5, 0.6, 0.75, 0.7))
		end
		if slot._rect then
			lowest_y = math.max(lowest_y, slot._rect.y + slot._rect.h)
		end
	end
	if g.mirror_rect then
		local mst = ui.states.mirror_slot
		local mfilled = craft.mirror_token_id ~= nil
		local mfocused = BP.focus_equals(panel, "mirror_slot")
		local mnear = mfocused
		if panel.drag then
			local dtok = craft.token_map[panel.drag.token_id]
			if dtok and BP.can_assign_mirror(craft, dtok)
				and (dtok.pos - g.mirror_pos):Length() <= item.snap_dist
			then
				mnear = true
			end
		end
		if panel.pad_carry and mfocused then mnear = true end
		local moutline = mnear and KColor(0.55, 0.85, 1, 1)
			or ((mst and mst.hovered) and KColor(0.65, 0.8, 1, 0.95) or KColor(0.45, 0.62, 0.95, 0.55))
		if not mfilled or mnear or mfocused or (mst and mst.hovered) then
			BP.draw_region_outline(g.mirror_rect, moutline, true)
		end
		if not mfilled and not (panel.pad_carry and mfocused) then
			local mlabel = zh and "镜" or "M"
			BP.draw_text_in_rect(g.mirror_rect, mlabel, KColor(0.45, 0.62, 0.95, 0.75))
		end
		lowest_y = math.max(lowest_y, g.mirror_rect.y + g.mirror_rect.h)
	end
	if g.cost_rect then
		lowest_y = math.max(lowest_y, g.cost_rect.y + g.cost_rect.h)
	end

	-- 实时档案审计：紧贴上方最低槽位/成本块下方（含所属玩家动态项）
	-- 红豆汤等持续状态预览只读；谷底石头在预览时立即比较并记录峰值。
	local live = CraftProfile.build_profile(BP.profile_ingredients(craft), {
		player = player,
		rec = craft.edit_uid and item.find_craft(player, craft.edit_uid) or craft,
		commit_state = false,
		commit_rock_bottom = true,
		base_quality = craft.remembered_quality or craft.base_quality,
	})
	live.craft_uid = craft.edit_uid
	CraftProfile.apply_craft_settings(live, {
		main_charge_ratio = craft.main_charge_ratio,
	})
	local lines = CraftProfile.audit_lines(live, zh, player)
	local charge_list = ui.charge_sliders or BP.list_charge_sliders(craft)
	local n_charge = #charge_list
	local slider_top = g.confirm_rect.y - 12
	if n_charge > 0 and g.charge_slider_rects and g.charge_slider_rects[n_charge] then
		slider_top = g.charge_slider_rects[n_charge].y - 2
	end
	local audit_top = lowest_y + BP.get_audit_text_y()
	local visible_count = math.max(0, math.floor((slider_top - audit_top) / 10) + 1)
	local audit_max = math.max(0, #lines - visible_count)
	local audit_scroll = math.max(0, math.min(audit_max, tonumber(craft.audit_scroll) or 0))
	craft.audit_scroll = audit_scroll
	panel.audit_scroll_max = audit_max
	panel.audit_scroll_rect = Mouse_UI.make_rect(
		g.left.x + 2,
		audit_top - 2,
		g.left.w - 4,
		math.max(0, slider_top - audit_top + 10)
	)
	local ay = audit_top
	for i = audit_scroll + 1, math.min(#lines, audit_scroll + visible_count) do
		gui.draw_ch(Vector(g.left.x + 4, ay), lines[i], 1, 1, BP.tint_kcolor(KColor(0.78, 0.88, 0.95, 1)), true)
		ay = ay + 10
	end
	-- 只有确实存在隐藏行时提示可滚动，避免常驻装饰干扰数值。
	if audit_max > 0 then
		local hint_x = g.left.x + g.left.w - 8
		if audit_scroll > 0 then
			gui.draw_ch(Vector(hint_x, audit_top), "▲", 1, 1, BP.tint_kcolor(KColor(0.7, 0.85, 1, 0.85)), true)
		end
		if audit_scroll < audit_max then
			gui.draw_ch(Vector(hint_x, slider_top), "▼", 1, 1, BP.tint_kcolor(KColor(0.7, 0.85, 1, 0.85)), true)
		end
	end

	-- 主攻击蓄力条：素材已将 front/ball 插值预制为 Idle 0..99 帧，无需裁切或缩放。
	for i, info in ipairs(charge_list) do
		local rect = info.rect or (g.charge_slider_rects and g.charge_slider_rects[i])
		if rect then
			local live = info.profile or BP.live_charge_profile(craft)
			local r = CraftProfile.canonicalize_main_charge(live, craft[info.key])
			local st = ui.states[info.id]
			local focused = BP.focus_equals(panel, info.id)
			local active = st and st.active
			local fill_col = (info.colors and info.colors[info.color_key]) or KColor(0.8, 0.65, 0.95, 0.95)
			local progress = CraftProfile.slider_progress(r, live)
			local frame = math.max(0, math.min(99, math.floor(progress * 99 + 0.5)))
			local slider = BP.ensure_charge_slider_sprite()
			slider:SetFrame("Idle", frame)
			local pos = Vector(rect.x + rect.w * 0.5, rect.y + rect.h * 0.5)
			-- back/front 均为白色素材；front 单独染色，main 保留黑边，ball 保留原色。
			slider.Color = BP.slider_layer_color(KColor(1, 1, 1, 0.72))
			slider:RenderLayer(1, pos)
			slider.Color = BP.slider_layer_color(fill_col)
			slider:RenderLayer(3, pos)
			slider.Color = BP.slider_layer_color(KColor(1, 1, 1, 1))
			slider:RenderLayer(0, pos)
			slider:RenderLayer(2, pos)
			if focused or active or (st and st.hovered) then
				-- 聚焦反馈只加轻微暖色，不改帧和图层几何。
				slider.Color = BP.slider_layer_color(KColor(1, 0.9, 0.55, 0.28))
				slider:RenderLayer(0, pos)
			end
			local pct = math.floor(r * 100 + 0.5)
			local label = (zh and info.zh or info.en) .. " " .. pct .. "%"
			BP.draw_text_in_rect(
				Mouse_UI.make_rect(rect.x, rect.y - 1, rect.w, rect.h),
				label,
				KColor(1, 0.92, 0.75, 1),
				{align = "center"}
			)
		end
	end

	-- 确认 / 返回 / 翻页
	local cst = ui.states.btn_confirm
	local bst = ui.states.btn_back
	local confirm_txt = panel.view == "edit"
		and (zh and "更改" or "Apply")
		or (zh and (craft.all_items and "审计制造" or "确认制造") or (craft.all_items and "Audit Craft" or "Craft"))
	local back_txt = "< "..(zh and "返回" or "Back")
	local c_focus = BP.focus_equals(panel, "btn_confirm")
	local b_focus = BP.focus_equals(panel, "btn_back")
	local cc = (c_focus or (cst and cst.hovered)) and KColor(1, 0.95, 0.5, 1) or KColor(0.85, 0.9, 1, 1)
	local bc = (b_focus or (bst and bst.hovered)) and KColor(1, 0.95, 0.5, 1) or KColor(0.75, 0.8, 0.9, 1)
	cc = BP.tut_dim_id("btn_confirm", cc)
	bc = BP.tut_dim_id("btn_back", bc)
	if BP.get_tutorial().is_locking() and BP.get_tutorial().allows("btn_confirm") then
		BP.draw_region_outline(g.confirm_rect, KColor(1, 0.9, 0.4, 1), true)
	else
		BP.draw_region_outline(g.confirm_rect, (c_focus or (cst and cst.hovered)) and KColor(1, 0.9, 0.4, 1) or KColor(0.5, 0.65, 0.9, 0.7), true)
	end
	if b_focus then BP.draw_region_outline(g.back_rect, KColor(1, 0.85, 0.35, 1), true) end
	BP.draw_text_in_rect(g.confirm_rect, confirm_txt, cc)
	BP.draw_text_in_rect(g.back_rect, back_txt, bc)

	local page = (craft.bag_page or 0) + 1
	local pages = craft.bag_pages or 1
	local pst = ui.states.btn_prev
	local nst = ui.states.btn_next
	local p_focus = BP.focus_equals(panel, "btn_prev")
	local n_focus = BP.focus_equals(panel, "btn_next")
	if p_focus then BP.draw_region_outline(g.prev_rect, KColor(1, 0.85, 0.35, 1), true) end
	if n_focus then BP.draw_region_outline(g.next_rect, KColor(1, 0.85, 0.35, 1), true) end
	BP.draw_text_in_rect(g.prev_rect, "<", (p_focus or (pst and pst.hovered)) and KColor(1, 1, 0.6, 1) or KColor(0.75, 0.8, 0.9, 1))
	BP.draw_text_in_rect(g.next_rect, ">", (n_focus or (nst and nst.hovered)) and KColor(1, 1, 0.6, 1) or KColor(0.75, 0.8, 0.9, 1))
	local page_rect = Mouse_UI.make_rect(g.prev_rect.x + g.prev_rect.w, g.prev_rect.y, g.next_rect.x - (g.prev_rect.x + g.prev_rect.w), g.prev_rect.h)
	BP.draw_text_in_rect(page_rect, tostring(page).."/"..tostring(pages), KColor(0.65, 0.75, 0.85, 1))

	-- tokens（已实装偏绿，未实装偏灰，失去标红）；焦点/搬运高亮
	for _, tok in ipairs(craft.tokens) do
		local st = ui.states[tok.id]
		local spr = tok.sprite or BP.load_col_sprite(tok.collectible)
		tok.sprite = spr
		local carrying = panel.pad_carry and panel.pad_carry.token_id == tok.id
		local focused = BP.focus_equals(panel, tok.id) or (panel.pad_carry and BP.focus_equals(panel, "dropbag_"..tok.id))
		local scale = 1
		if (panel.drag and panel.drag.token_id == tok.id) or carrying then scale = 1.14
		elseif focused or (st and st.hovered) then scale = 1.08 end
		scale = scale * (tok.visual_scale or 1)
		spr.Scale = Vector(scale, scale)
		local impl = tok.impl
		if impl == nil then impl = CraftProfile.has_impl(tok.collectible) tok.impl = impl end
		local missing_stat = tok.missing_stat
		if missing_stat == nil then
			missing_stat = CraftProfile.missing_stat_delta(tok.collectible)
			tok.missing_stat = missing_stat
		end
		local form_syn = tok.form_synergy
		local lit = tok.lit
		if lit == nil then lit = (impl or form_syn) and true or false tok.lit = lit end
		local gated_off = impl and tok.gate_kind and lit == false
		local lost = tok.lost == true or tok.lost_ghost == true
		if tok.cost then
			-- 成本仅用于支付，绝不生效；其视觉优先级高于 lost/prototype/impl 等状态。
			spr.Color = BP.cost_token_color()
		elseif lost then
			-- 失去（背包/材料槽）：优先标红
			spr.Color = BP.tint_color(1.0, 0.28, 0.28, 1)
		elseif tok.is_prototype or tok.source == "prototype" then
			spr.Color = BP.tint_color(0.7, 0.9, 1.0, 1)
		elseif tok.is_mirror or tok.source == "mirror" then
			BP.apply_mirror_token_visual(spr, tok.collectible)
		elseif missing_stat then
			spr.Color = BP.tint_color(1.0, 0.82, 0.35, 1)
		elseif gated_off then
			-- 已实装但当前配方不满足武器条件（如无博士/史诗的炸弹道具）
			spr.Color = BP.tint_color(0.42, 0.4, 0.38, 0.72)
		elseif form_syn and not impl then
			-- 套装材料亮起（书套/宝宝套/超级猫套/针套等），无独立接线也偏绿
			spr.Color = BP.tint_color(0.8, 0.95, 1.0, 1)
		elseif impl or lit then
			spr.Color = BP.tint_color(0.85, 1.0, 0.85, 1)
		else
			spr.Color = BP.tint_color(0.45, 0.42, 0.42, 0.85)
		end
		if BP.get_tutorial().is_locking() then
			local seated = tok.slot or tok.cost or tok.mirror_slot
			if not BP.get_tutorial().allows_token(tok) and not seated then
				spr.Color = BP.tint_color(0.32, 0.32, 0.36, 0.38)
			elseif BP.get_tutorial().allows_token(tok) and not seated then
				BP.draw_region_outline(Mouse_UI.make_rect_centered(tok.pos, item.slot_size, item.slot_size), KColor(1, 0.9, 0.35, 1), true)
			end
		end
		-- 与材料槽共用完全相同的边界尺寸；避免 32px 点阵步进越过边缘，看起来比 34px 槽框更大。
		local token_outline_rect = Mouse_UI.make_rect_centered(tok.pos, item.slot_size, item.slot_size)
		-- 成本 token 已由上方的小槽负责聚焦反馈；不能再套用正常 token 的大框。
		if not tok.cost and (focused or carrying) then
			BP.draw_region_outline(token_outline_rect, KColor(1, 0.9, 0.35, 1), true)
		end
		if not tok.cost and lost then
			BP.draw_region_outline(token_outline_rect, KColor(1, 0.3, 0.3, 0.9), true)
		elseif not tok.cost and BP.show_source_marks() and (tok.is_prototype or tok.source == "prototype") then
			BP.draw_region_outline(token_outline_rect, KColor(0.35, 0.85, 1, 0.95), true)
		elseif not tok.cost and BP.show_source_marks() and (tok.is_mirror or tok.source == "mirror") then
			BP.draw_region_outline(token_outline_rect, KColor(0.35, 0.55, 1, 0.9), true)
		elseif not tok.cost and BP.show_source_marks() and tok.source == "audit" then
			BP.draw_region_outline(token_outline_rect, KColor(1, 0.75, 0.4, 0.85), true)
		end
		spr:Render(tok.pos, Vector(0, 0), Vector(0, 0))
		if tok.is_mirror or tok.source == "mirror" then
			BP.clear_mirror_token_visual(spr)
		else
			BP.clear_sprite_color(spr)
		end
		if craft.show_quality then
			BP.render_token_quality_icon(tok)
		end
		local show_src = BP.show_source_marks()
		local mark = zh and "○" or "."
		local mk = KColor(0.75, 0.35, 0.35, 0.95)
		if lost then
			mark = "!"
			mk = KColor(1, 0.35, 0.35, 1)
		elseif show_src and (tok.is_mirror or tok.source == "mirror") then
			mark = zh and "镜" or "M"
			mk = KColor(0.35, 0.55, 1, 1)
		elseif show_src and (tok.is_prototype or tok.source == "prototype") then
			mark = zh and "原" or "P"
			mk = KColor(0.35, 0.85, 1, 1)
		elseif show_src and tok.source == "audit" then
			mark = zh and "审" or "A"
			mk = KColor(1, 0.75, 0.4, 1)
		elseif missing_stat then
			mark = "△"
			mk = KColor(1, 0.82, 0.2, 1)
		elseif gated_off then
			mark = zh and "◎" or "o"
			mk = KColor(0.7, 0.65, 0.55, 1)
		elseif form_syn and not impl then
			mark = zh and "套" or "F"
			mk = KColor(0.45, 0.85, 1, 1)
		elseif impl or lit then
			mark = zh and "●" or "*"
			mk = KColor(0.35, 0.95, 0.45, 1)
		end
		-- 成本槽只传达“灰色=不生效”，不叠加背包/材料状态标记。教学背包也不打这些记号。
		if not tok.cost and mark and mark ~= "" and not BP.get_tutorial().bag_collectibles() then
			gui.draw_ch(tok.pos + Vector(8, -14), mark, 1, 1, BP.tint_kcolor(mk), true)
		end
	end
end

function BP.render_tutorial_overlay(ui, panel)
	local tut = ui and ui.tut
	if not tut then return end
	local hint = tut.hint
	if tut.box then
		BP.draw_region_outline(tut.box, KColor(1, 0.9, 0.45, 1), true)
		if hint and hint ~= "" then
			local y = tut.box.y + 8
			for line in string.gmatch(hint.."\n", "([^\n]*)\n") do
				if line ~= "" then
					BP.draw_text_in_rect(Mouse_UI.make_rect(tut.box.x + 8, y, tut.box.w - 16, 12), line, KColor(1, 0.95, 0.75, 1))
					y = y + 13
				end
			end
		end
	elseif hint and hint ~= "" then
		-- 贴屏幕底部，避开页签、暂停选项和顶部拾取字幕
		BP.get_tutorial().draw_bottom_hint(hint, KColor(1, 0.95, 0.75, 1))
	end
	for _, b in ipairs(tut.buttons or {}) do
		local st = ui.states[b.id]
		local hot = (st and st.hovered) or BP.focus_equals(panel, b.id)
		BP.draw_region_outline(b.rect, hot and KColor(1, 0.92, 0.4, 1) or KColor(0.7, 0.8, 0.95, 0.85), true)
		BP.draw_text_in_rect(b.rect, b.label, hot and KColor(1, 0.95, 0.55, 1) or KColor(0.9, 0.93, 1, 1))
	end
end

function BP.render_panel()
	BP.scrub_stale_panel()
	local panel = item.panel
	if not panel then return end
	if not BP.panel_is_alive() then
		BP.close_panel()
		return
	end
	BP.enforce_all_items_gate(panel)

	-- 切屏等进暂停：不强制关菜单；标记 was_paused，回来后松手再响应（对齐逢魔）
	if BP.pause_menu_open() then
		panel.was_paused = true
		return
	end

	item._draw_alpha = item.get_panel_alpha()
	pcall(function() BP.get_tutorial().observe_panel(panel) end)
	if not item.panel then item._draw_alpha = nil return end
	local can_read_wheel = not panel.was_paused and not Game():IsPaused()
	local ui = BP.build_and_register_ui(panel)
	ui = BP.handle_render_phase_input(panel, ui, can_read_wheel)
	if not item.panel or not ui then item._draw_alpha = nil return end

	local panel_rect = ui.panel_rect
	local bg = BP.ensure_bg_sprite()
	local a = BP.panel_alpha()
	bg.Color = Color(1, 1, 1, a)
	local bg_off = BP.get_bg_offset()
	bg:Render(panel_rect.center + bg_off, Vector(0, 0), Vector(0, 0))
	bg.Color = Color(1, 1, 1, 1)
	BP.render_tabs(ui, panel)

	local tab = item.tabs[panel.tab]
	local in_craft = (tab.id == "build" or tab.id == "inventory") and panel.craft and ui.craft_geom
	if in_craft then
		BP.render_craft(ui, panel)
	else
		BP.render_list(ui, panel)
	end
	BP.render_tutorial_overlay(ui, panel)

	if item.debug_draw_regions then
		gui.draw_ch(Vector(8, 8), "hover="..tostring(ui.hovered or "-"), 1, 1, BP.tint_kcolor(KColor(1, 1, 1, 0.7)), true)
	end
	item._draw_alpha = nil
end

function item.get_panel_rect()
	local rise = item.get_panel_rise_offset()
	local center = gui.GetScreenCenter() + item.panel_offset + Vector(0, rise)
	local half = item.panel_size * 0.5
	return {
		x = center.X - half.X,
		y = center.Y - half.Y,
		w = item.panel_size.X,
		h = item.panel_size.Y,
		center = center,
	}
end

function item.get_tab_rects(panel_rect)
	local n = #item.tabs
	local pad = item.content_pad
	local avail_w = panel_rect.w - pad.X * 2
	local tab_w = (avail_w - item.tab_gap * (n - 1)) / n
	local y = panel_rect.y + pad.Y
	local rects = {}
	for i = 1, n do
		local x = panel_rect.x + pad.X + (i - 1) * (tab_w + item.tab_gap)
		rects[i] = Mouse_UI.make_rect(x, y, tab_w, item.tab_height)
	end
	return rects
end

function item.get_content_rect(panel_rect)
	local pad = item.content_pad
	local top = panel_rect.y + pad.Y + item.tab_height + 6
	return Mouse_UI.make_rect(
		panel_rect.x + pad.X,
		top,
		panel_rect.w - pad.X * 2,
		panel_rect.y + panel_rect.h - pad.Y - top
	)
end

end

return M
