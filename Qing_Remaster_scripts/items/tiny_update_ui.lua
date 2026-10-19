-- Steam-style Tiny Update notice. Modal input only; no extra world freeze.
local pixel_ui = require("Qing_Remaster_scripts.auxiliary.pixel_ui")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local enums = require("Qing_Remaster_scripts.core.enums")
local runtime = require("Qing_Remaster_scripts.items.tiny_update_runtime")
local Mouse_UI = require("Qing_Remaster_scripts.others.Mouse_UI_holder")

local MODAL = "tiny_update"
local TIME_STOP_KEY = "Item_Tiny_Update_Notice"
local ITEM_ANM2 = "gfx/mimics/Alchemy_Pot/alchemy_pot_item.anm2"
local POOL_ANM2 = "gfx/ui/EID/eid_inline_icons.anm2"

local DEFAULT_VISUAL = {
	offset_x = 0,
	offset_y = 8,
	close_x = -8,
	close_y = 0,
	pool_icon_x = 0,
	pool_icon_y = 6,
	footer_text_y = -8,
	change_line_height = 19,
	item_row_gap = 9,
	key_scroll_speed = 3,
	enter_margin = 8,
	exit_distance = 32,
	enter_frames = 22,
	exit_frames = 10,
	show_bounds = false,
}

local ui = {
	open = false,
	phase = "closed",
	block = false,
	scroll = 0,
	notice = nil,
	preview = false,
	mouse_ready = false,
	drag = nil,
	config = {},
}

for key, value in pairs(DEFAULT_VISUAL) do
	ui.config[key] = value
end

local COLOR = {
	title = KColor(0.902, 0.910, 0.925, 1),
	sub = KColor(0.722, 0.741, 0.776, 1),
	blue = KColor(0.400, 0.722, 0.925, 1),
	buff = KColor(0.612, 0.820, 0.545, 1),
	nerf = KColor(0.882, 0.627, 0.627, 1),
	text = KColor(0.902, 0.910, 0.925, 1),
}

local POOL_DISPLAY = {
	[ItemPoolType.POOL_TREASURE] = {zh = "宝箱房道具池", en = "Treasure Room Pool"},
	[ItemPoolType.POOL_SHOP] = {zh = "商店道具池", en = "Shop Pool"},
	[ItemPoolType.POOL_BOSS] = {zh = "Boss房道具池", en = "Boss Room Pool"},
	[ItemPoolType.POOL_DEVIL] = {zh = "恶魔房道具池", en = "Devil Room Pool"},
	[ItemPoolType.POOL_ANGEL] = {zh = "天使房道具池", en = "Angel Room Pool"},
	[ItemPoolType.POOL_SECRET] = {zh = "隐藏房道具池", en = "Secret Room Pool"},
	[ItemPoolType.POOL_LIBRARY] = {zh = "图书馆道具池", en = "Library Pool"},
	[ItemPoolType.POOL_CURSE] = {zh = "诅咒房道具池", en = "Curse Room Pool"},
	[ItemPoolType.POOL_PLANETARIUM] = {zh = "星象房道具池", en = "Planetarium Pool"},
	[ItemPoolType.POOL_GOLDEN_CHEST] = {zh = "金箱子道具池", en = "Golden Chest Pool"},
}

local sprite
local sprite_ok = false
local pool_sprite
local collectible_sprites = {}

local function ensure_sprite()
	if sprite_ok then return true end
	if not sprite then sprite = Sprite() end
	local ok = pcall(function()
		sprite:Load("gfx/ui/tiny_update/tiny_update_ui.anm2", true)
	end)
	sprite_ok = ok == true
	return sprite_ok
end

local function zh_ui()
	return Options and Options.Language == "zh"
end

local function font_for()
	if zh_ui() and gui.f2 then return gui.f2 end
	return gui.f or gui.f2
end

local function ui_scale(w, h)
	local raw = math.min(w / 960, h / 640)
	local best = 0.5
	local allowed = {0.5, 1, 2, 3, 4}
	for i = 1, #allowed do
		if allowed[i] <= raw + 0.001 then best = allowed[i] end
	end
	return best
end

local function smoothstep(t)
	t = math.max(0, math.min(1, t))
	return t * t * (3 - 2 * t)
end

local function ease_out_cubic(t)
	t = math.max(0, math.min(1, t))
	local inv = 1 - t
	return 1 - inv * inv * inv
end

local function animation_sample(rest_y, panel_height, scale)
	local cfg = ui.config
	local slide, panel_a, dim_a = 0, 1, 0.75
	if ui.phase ~= "entering" and ui.phase ~= "exiting" then
		return slide, panel_a, dim_a
	end
	local duration = ui.phase == "exiting" and (cfg.exit_frames or 10) or (cfg.enter_frames or 22)
	duration = math.max(1, duration)
	local t = (Isaac.GetFrameCount() - (ui.anim_frame or 0)) / duration
	t = math.max(0, math.min(1, t))
	if ui.phase == "entering" then
		local margin = (cfg.enter_margin or 8) * (scale or 1)
		local start_offset = -((rest_y or 0) + (panel_height or 0) + margin)
		slide = start_offset * (1 - ease_out_cubic(t))
		dim_a = 0.75 * smoothstep(math.min(1, t * 1.6))
	else
		local ease = smoothstep(t)
		slide = (cfg.exit_distance or 32) * ease * (scale or 1)
		panel_a = 1 - ease
		dim_a = 0.75 * (1 - smoothstep(math.max(0, (t - 0.35) / 0.65)))
	end
	return slide, panel_a, dim_a, t
end

local function layout()
	local w = Isaac.GetScreenWidth()
	local h = Isaac.GetScreenHeight()
	local s = ui_scale(w, h)
	local cfg = ui.config
	local px = (w - 960 * s) * 0.5 + 72 * s + (cfg.offset_x or 0) * s
	local rest_y = (h - 640 * s) * 0.5 + 38 * s + (cfg.offset_y or 0) * s
	local ph = 564 * s
	local slide, panel_a, dim_a = animation_sample(rest_y, ph, s)
	local py = rest_y + slide
	return {
		s = s,
		w = w,
		h = h,
		px = px,
		py = py,
		pw = 816 * s,
		ph = 564 * s,
		header = 118 * s,
		footer = 58 * s,
		pad = 24 * s,
		panel_a = panel_a,
		dim_a = dim_a,
		close_x = (cfg.close_x or 0) * s,
		close_y = (cfg.close_y or 0) * s,
	}
end

local function draw_anim(name, x, y, sx, sy)
	if not ensure_sprite() then return end
	sprite:SetFrame(name, 0)
	sprite.Scale = Vector(sx, sy)
	sprite:Render(Vector(math.floor(x), math.floor(y)), Vector(0, 0), Vector(0, 0))
end

local function draw_panel(box)
	if not ensure_sprite() then return end
	local s = box.s
	local edge = 16 * s
	local panel_a = box.panel_a or 1
	local dim_a = box.dim_a or 0.75
	sprite.Color = Color(8 / 255, 11 / 255, 17 / 255, dim_a, 0, 0, 0)
	draw_anim("dim", 0, 0, box.w / 8, box.h / 8)
	sprite.Color = Color(1, 1, 1, panel_a, 0, 0, 0)
	local x, y, w, h = box.px, box.py, box.pw, box.ph
	local inner_w = math.max(edge, w - edge * 2)
	local inner_h = math.max(edge, h - edge * 2)
	draw_anim("tl", x, y, s, s)
	draw_anim("t", x + edge, y, inner_w / 16, s)
	draw_anim("tr", x + w - edge, y, s, s)
	draw_anim("l", x, y + edge, s, inner_h / 16)
	draw_anim("c", x + edge, y + edge, inner_w / 16, inner_h / 16)
	draw_anim("r", x + w - edge, y + edge, s, inner_h / 16)
	draw_anim("bl", x, y + h - edge, s, s)
	draw_anim("b", x + edge, y + h - edge, inner_w / 16, s)
	draw_anim("br", x + w - edge, y + h - edge, s, s)
	sprite.Color = Color(0.90, 0.92, 0.96, panel_a, 0, 0, 0)
	draw_anim("c", x + edge, y + edge, inner_w / 16, math.max(1, (box.header - edge) / 16))
	sprite.Color = Color(0.78, 0.80, 0.84, panel_a, 0, 0, 0)
	draw_anim("c", x + edge, y + h - box.footer, inner_w / 16, math.max(1, (box.footer - edge) / 16))
	sprite.Color = Color(1, 1, 1, 1, 0, 0, 0)
end

local function get_collectible_sprite(id)
	if collectible_sprites[id] then return collectible_sprites[id] end
	local spr
	local ok = pcall(function()
		spr = auxi.load_item(id, {Anm = ITEM_ANM2})
	end)
	if not ok or not spr then spr = nil end
	collectible_sprites[id] = spr or false
	return spr
end

local function frame_metrics(spr)
	local frame = spr and spr.GetLayerFrameData and spr:GetLayerFrameData(0)
	if frame and frame.GetPivot and frame.GetWidth and frame.GetHeight then
		local pivot = frame:GetPivot()
		local w = frame:GetWidth()
		local h = frame:GetHeight()
		if pivot and w and h and w > 0 and h > 0 then
			return w, h, pivot.X, pivot.Y
		end
	end
	return nil
end

local function render_in_rect(spr, rect, view, alpha, fallback_w, fallback_h)
	if not spr or not rect then return end
	local fw, fh, pivot_x, pivot_y = frame_metrics(spr)
	if not fw then
		fw = fallback_w or 32
		fh = fallback_h or 32
		pivot_x = fw * 0.5
		pivot_y = fh * 0.5
	end
	local scale = math.min(rect.w / fw, rect.h / fh)
	if scale <= 0 then return end
	local center_x = rect.x + rect.w * 0.5
	local center_y = rect.y + rect.h * 0.5
	local render_x = center_x - (fw * 0.5 - pivot_x) * scale
	local render_y = center_y - (fh * 0.5 - pivot_y) * scale
	local top = render_y - pivot_y * scale
	local left = render_x - pivot_x * scale
	local bottom = top + fh * scale
	local right = left + fw * scale
	local crop_l, crop_t, crop_r, crop_b = 0, 0, 0, 0
	if view then
		if bottom <= view.top or top >= view.bottom or right <= view.left or left >= view.right then
			return
		end
		crop_t = math.max(0, (view.top - top) / scale)
		crop_b = math.max(0, (bottom - view.bottom) / scale)
		crop_l = math.max(0, (view.left - left) / scale)
		crop_r = math.max(0, (right - view.right) / scale)
	end
	spr.Scale = Vector(scale, scale)
	spr.Color = Color(1, 1, 1, alpha or 1, 0, 0, 0)
	spr:Render(Vector(math.floor(render_x), math.floor(render_y)), Vector(crop_l, crop_t), Vector(crop_r, crop_b))
end

local function draw_collectible(id, rect, view, alpha)
	local spr = get_collectible_sprite(id)
	if not spr then return end
	render_in_rect(spr, rect, view, alpha, 32, 32)
end

local function pool_display_name(pool_type, zh)
	local row = POOL_DISPLAY[tonumber(pool_type)]
	if not row then return nil end
	return zh and row.zh or row.en
end

local function draw_pool_icon(pool_type, rect, view, alpha)
	if not POOL_DISPLAY[tonumber(pool_type)] then return end
	if not pool_sprite then
		pool_sprite = Sprite()
		local ok = pcall(function()
			pool_sprite:Load(POOL_ANM2, true)
		end)
		if not ok then
			pool_sprite = false
		end
	end
	if not pool_sprite then return end
	pool_sprite:SetFrame("ItemPools", tonumber(pool_type))
	if frame_metrics(pool_sprite) then
		render_in_rect(pool_sprite, rect, view, alpha, 11, 11)
		return
	end
	local scale = math.min(rect.w / 11, rect.h / 11)
	local center = Vector(rect.x + rect.w * 0.5, rect.y + rect.h * 0.5)
	pool_sprite.Scale = Vector(scale, scale)
	pool_sprite.Color = Color(1, 1, 1, alpha or 1, 0, 0, 0)
	pool_sprite:Render(center + Vector(-5.5 * scale, -5.5 * scale), Vector(0, 0), Vector(0, 0))
end

local function item_name(id)
	if EID and EID.getObjectName then
		local ok, name = pcall(function()
			return EID:getObjectName(5, 100, id)
		end)
		if ok and type(name) == "string" and name ~= "" then return name end
	end
	local cfg = Isaac.GetItemConfig():GetCollectible(id)
	return (cfg and cfg.Name) or tostring(id)
end

local function signed_text(steps, scale, integer)
	local value = steps * scale
	local body
	if integer then
		body = tostring(math.abs(math.floor(value)))
	else
		body = string.format("%.1f", math.abs(value))
	end
	if steps > 0 then return "+" .. body end
	return "-" .. body
end

local function change_view(change, zh)
	local kind = change.kind
	if kind == "pool_add" or kind == "pool_remove" or kind == "pool_weight" then
		local pool_type = change.pool
		local pool = pool_display_name(pool_type, zh)
		if not pool then return nil end
		local label
		if kind == "pool_add" then
			label = (zh and "新增至" or "Added to ") .. pool
		elseif kind == "pool_remove" then
			label = (zh and "移出" or "Removed from ") .. pool
		else
			local from_w = string.format("%.1f", change.from or 0)
			local to_w = string.format("%.1f", change.to or 0)
			label = pool .. (zh and " 权重 " or " weight ") .. from_w .. " → " .. to_w
		end
		return {kind = kind, label = label, pool_type = pool_type, group = "pool"}
	end
	if kind == "hearts" or kind == "soul_hearts" or kind == "black_hearts" then
		local names = {
			hearts = zh and "红心上限 " or "Max Hearts ",
			soul_hearts = zh and "魂心 " or "Soul Hearts ",
			black_hearts = zh and "黑心 " or "Black Hearts ",
		}
		local label = (names[kind] or "") .. signed_text(change.steps, 1, true)
		return {kind = kind, label = label, group = change.steps > 0 and "buff" or "nerf"}
	end
	if kind == "charge" or kind == "charge_normal" then
		local label = (zh and "充能需求 " or "Charge requirement ") .. signed_text(change.steps, 1, true)
		return {kind = kind, label = label, group = change.steps < 0 and "buff" or "nerf"}
	end
	if kind == "charge_timed" then
		local label = (zh and "自动充能时间 " or "Timed charge ") .. signed_text(change.steps, 1, true) .. (zh and "秒" or "s")
		return {kind = kind, label = label, group = change.steps < 0 and "buff" or "nerf"}
	end
	local labels = {
		damage = zh and "攻击力 " or "Damage ",
		tears = zh and "射速 " or "Tears ",
		range = zh and "射程 " or "Range ",
		shot_speed = zh and "弹速 " or "Shot Speed ",
		speed = zh and "移速 " or "Speed ",
		luck = zh and "幸运 " or "Luck ",
	}
	local steps = change.steps or 0
	local label = (labels[kind] or "") .. signed_text(steps, 0.1, false)
	if labels[kind] == nil then return nil end
	return {kind = kind, label = label, group = steps > 0 and "buff" or "nerf"}
end

local function push_wrapped(nodes, text, color, scale, max_w, font, s)
	local chunk = ""
	local function flush()
		if chunk == "" then return end
		nodes[#nodes + 1] = {type = "text", text = chunk, color = color, scale = scale, h = 20 * s}
		chunk = ""
	end
	for glyph in pixel_ui.iter_utf8_glyphs(text) do
		local trial = chunk .. glyph
		if chunk ~= "" and pixel_ui.measure_text(trial, scale, font) > max_w then
			flush()
			chunk = glyph
		else
			chunk = trial
		end
	end
	flush()
end

local function font_line_px()
	return pixel_ui.measure_line_height(1)
end

local function change_line_px(s)
	return math.max((ui.config.change_line_height or 19) * s, font_line_px())
end

local function name_step_px(s)
	return math.max(18 * s, font_line_px())
end

local function item_row_gap_px(s)
	return math.max(0, (ui.config.item_row_gap or 9) * s)
end

local function build_nodes(notice, box)
	local zh = zh_ui()
	local font = font_for()
	local s = box.s
	local max_w = box.pw - box.pad * 2 - 56 * s
	local nodes = {}
	local intro = zh and "感谢您对游戏平衡性的持续支持。本次更新包括以下内容。" or "Thank you for supporting game balance. This update includes the following changes."
	push_wrapped(nodes, intro, COLOR.sub, 1, max_w, font, s)
	nodes[#nodes + 1] = {type = "spacer", h = 12 * s}
	local groups = {
		{key = "buff", title = zh and "增强" or "Buffs", color = COLOR.buff},
		{key = "nerf", title = zh and "削弱" or "Nerfs", color = COLOR.nerf},
		{key = "pool", title = zh and "道具池调整" or "Item Pool Changes", color = COLOR.blue},
	}
	local buckets = {buff = {}, nerf = {}, pool = {}}
	local entries = notice and notice.entries or {}
	for i = 1, #entries do
		local entry = entries[i]
		local grouped = {buff = {}, nerf = {}, pool = {}}
		for j = 1, #(entry.changes or {}) do
			local view = change_view(entry.changes[j], zh)
			if view then
				grouped[view.group][#grouped[view.group] + 1] = view
			end
		end
		for g = 1, #groups do
			local key = groups[g].key
			if #grouped[key] > 0 then
				buckets[key][#buckets[key] + 1] = {
					item_id = entry.item_id,
					name = item_name(entry.item_id),
					changes = grouped[key],
				}
			end
		end
	end
	for i = 1, #groups do
		local group = groups[i]
		local rows = buckets[group.key]
		if #rows > 0 then
			local count = 0
			for r = 1, #rows do count = count + #rows[r].changes end
			local title = group.title .. "  ·  " .. tostring(count) .. (zh and " 项" or "")
			nodes[#nodes + 1] = {type = "group", text = title, color = group.color, h = 30 * s}
			for r = 1, #rows do
				local row = rows[r]
				local line_h = change_line_px(s)
				local height = math.max(44 * s, 8 * s + name_step_px(s) + #row.changes * line_h)
				nodes[#nodes + 1] = {
					type = "item",
					item_id = row.item_id,
					name = row.name,
					changes = row.changes,
					h = height,
				}
				nodes[#nodes + 1] = {type = "spacer", h = item_row_gap_px(s)}
			end
			nodes[#nodes + 1] = {type = "spacer", h = 12 * s}
		end
	end
	local y = 0
	for i = 1, #nodes do
		nodes[i].y = y
		y = y + (nodes[i].h or 0)
	end
	return nodes, y
end

local function clamp_scroll()
	local max_scroll = ui._max_scroll or 0
	if ui.scroll < 0 then ui.scroll = 0 end
	if ui.scroll > max_scroll then ui.scroll = max_scroll end
end

local function add_scroll(delta)
	ui.scroll = ui.scroll + delta
	clamp_scroll()
end

local function hold_time()
	pcall(function() auxi.time_stop(TIME_STOP_KEY) end)
end

local function release_notice(swallow)
	ui.phase = "closed"
	ui.open = false
	ui.drag = nil
	ui.block = swallow == true
	Mouse_UI.release_modal(MODAL)
	pcall(function() auxi.time_free(TIME_STOP_KEY) end)
end

local function each_controller(callback)
	local seen = {}
	local count = Game():GetNumPlayers()
	for i = 0, count - 1 do
		local player = Isaac.GetPlayer(i)
		local ctrl = player and player.ControllerIndex or 0
		if not seen[ctrl] then
			seen[ctrl] = true
			if callback(ctrl) then return true end
		end
	end
	if not seen[0] then return callback(0) end
	return false
end

local function action_down(button)
	return each_controller(function(ctrl)
		return Input.IsActionPressed(button, ctrl)
	end)
end

local function action_triggered(button)
	return each_controller(function(ctrl)
		return Input.IsActionTriggered(button, ctrl)
	end)
end

function ui.show(notice, preview)
	ui.notice = notice or {version = 0, entries = {}}
	ui.scroll = 0
	ui.phase = "entering"
	ui.open = true
	ui.block = false
	ui.preview = preview == true
	ui.drag = nil
	ui.anim_frame = Isaac.GetFrameCount()
	ui.mouse_ready = not Mouse_UI.is_down(0)
	ui.item_ready = not action_down(ButtonAction.ACTION_ITEM)
	if not ui.preview then runtime.note_notice(ui.notice) end
	Mouse_UI.claim_modal(MODAL)
	hold_time()
end

function ui.show_last()
	local history = runtime.state().history
	if history then ui.show(history, false) end
end

function ui.request_close()
	if ui.phase ~= "reading" then return end
	ui.phase = "exiting"
	ui.anim_frame = Isaac.GetFrameCount()
	ui.drag = nil
end

function ui.force_close()
	if ui.phase == "closed" and not ui.open then return end
	release_notice(false)
end

function ui.close()
	ui.force_close()
end

function ui.is_open()
	return ui.phase ~= "closed"
end

function ui.is_blocking()
	return ui.phase ~= "closed" or ui.block
end

function ui.visual_get(key)
	return ui.config[key]
end

function ui.visual_set(key, value)
	if DEFAULT_VISUAL[key] == nil then return end
	if key == "show_bounds" then
		ui.config[key] = value == true
		return
	end
	ui.config[key] = tonumber(value) or ui.config[key]
end

function ui.visual_restore()
	for key, value in pairs(DEFAULT_VISUAL) do
		ui.config[key] = value
	end
end

local function ink(color, alpha)
	return KColor(color.Red, color.Green, color.Blue, (color.Alpha or 1) * (alpha or 1))
end

local function text_ink_center(text_top, scale)
	local font = font_for()
	local baseline = 10
	if font and font.GetBaselineHeight then
		local ok, value = pcall(function()
			return font:GetBaselineHeight()
		end)
		if ok and type(value) == "number" and value > 0 then baseline = value end
	end
	return text_top + baseline * scale * 0.5
end

local function draw_use_icon(rect, view, alpha)
	if not pool_sprite then
		pool_sprite = Sprite()
		local ok = pcall(function()
			pool_sprite:Load(POOL_ANM2, true)
		end)
		if not ok then pool_sprite = false end
	end
	if not pool_sprite then return end
	pool_sprite:SetFrame("XboxOne", 12)
	render_in_rect(pool_sprite, rect, view, alpha, 13, 13)
end

local function draw_header(box, notice)
	local zh = zh_ui()
	local font = font_for()
	local s = box.s
	local alpha = box.panel_a or 1
	local icon = enums.Items.Tiny_Update
	local icon_size = 32 * s
	if icon and icon > 0 then
		draw_collectible(icon, {
			x = box.px + box.pad,
			y = box.py + (box.header - icon_size) * 0.5,
			w = icon_size,
			h = icon_size,
		}, nil, alpha)
	end
	local text_x = box.px + box.pad + 48 * s
	local title_scale = s >= 1 and 2 or 1
	pixel_ui.draw_text(Vector(text_x, box.py + 16 * s), zh and "琉璃盛典  ·  更新日志" or "Glaze Ceremony  ·  Update Log", 1, ink(COLOR.blue, alpha), {font = font, context = "tiny_update"})
	pixel_ui.draw_text(Vector(text_x, box.py + 36 * s), (zh and "微型更新 " or "Tiny Update ") .. runtime.version_text(notice and notice.version or 0), title_scale, ink(COLOR.title, alpha), {font = font, context = "tiny_update"})
	pixel_ui.draw_text(Vector(text_x, box.py + 36 * s + pixel_ui.measure_line_height(title_scale) + 4), zh and "道具平衡性调整" or "Item balance adjustments", 1, ink(COLOR.sub, alpha), {font = font, context = "tiny_update"})
end

local function draw_nodes(box, nodes)
	local font = font_for()
	local s = box.s
	local alpha = box.panel_a or 1
	local view = {
		left = box.px + box.pad,
		right = box.px + box.pw - 56 * s,
		top = box.py + box.header,
		bottom = box.py + box.ph - box.footer,
	}
	local text_x = box.px + box.pad
	local function text_inside(y, h)
		return y >= view.top and y + h <= view.bottom
	end
	for i = 1, #nodes do
		local node = nodes[i]
		local y = view.top + node.y - ui.scroll
		if node.type == "text" or node.type == "group" then
			if text_inside(y, node.h) then
				pixel_ui.draw_text(Vector(text_x, y), node.text, node.scale or 1, ink(node.color, alpha), {font = font, context = "tiny_update"})
			end
		elseif node.type == "item" then
			local icon_size = 32 * s
			draw_collectible(node.item_id, {x = text_x, y = y, w = icon_size, h = icon_size}, view, alpha)
			local name_x = text_x + 44 * s
			local name_step = name_step_px(s)
			if text_inside(y, name_step) then
				pixel_ui.draw_text(Vector(name_x, y), node.name, 1, ink(COLOR.text, alpha), {font = font, context = "tiny_update"})
			end
			local line_h = change_line_px(s)
			for c = 1, #node.changes do
				local line_y = y + name_step + (c - 1) * line_h
				if text_inside(line_y, line_h) then
					local change = node.changes[c]
					local label_x = name_x
					if change.pool_type then
						local icon_size = 16 * s
						local center_y = text_ink_center(line_y, 1)
						local icon_rect = {
							x = name_x + (ui.config.pool_icon_x or 0) * s,
							y = center_y - icon_size * 0.5 + (ui.config.pool_icon_y or 0) * s,
							w = icon_size,
							h = icon_size,
						}
						draw_pool_icon(change.pool_type, icon_rect, view, alpha)
						if ui.config.show_bounds then
							sprite.Color = Color(0.25, 0.85, 1, 1, 0, 0, 0)
							draw_anim("c", icon_rect.x, icon_rect.y, icon_rect.w, 1)
							draw_anim("c", icon_rect.x, icon_rect.y + icon_rect.h - 1, icon_rect.w, 1)
							draw_anim("c", icon_rect.x, icon_rect.y, 1, icon_rect.h)
							draw_anim("c", icon_rect.x + icon_rect.w - 1, icon_rect.y, 1, icon_rect.h)
							sprite.Color = Color(1, 1, 1, alpha, 0, 0, 0)
						end
						label_x = name_x + icon_size + 6 * s
					end
					pixel_ui.draw_text(Vector(label_x, line_y), change.label, 1, ink(COLOR.sub, alpha), {font = font, context = "tiny_update"})
				end
			end
		end
	end
end

local function advance_phase()
	if ui.phase ~= "entering" and ui.phase ~= "exiting" then return end
	local duration = ui.phase == "exiting" and (ui.config.exit_frames or 10) or (ui.config.enter_frames or 22)
	if Isaac.GetFrameCount() - (ui.anim_frame or 0) < math.max(1, duration) then return end
	if ui.phase == "entering" then
		ui.phase = "reading"
		return
	end
	release_notice(true)
end

function ui.render()
	if ui.phase == "closed" then
		if ui.block then
			local busy = Input.IsActionPressed(ButtonAction.ACTION_BOMB, 0)
				or Input.IsActionPressed(ButtonAction.ACTION_ITEM, 0)
				or Input.IsActionPressed(ButtonAction.ACTION_PILLCARD, 0)
				or Input.IsActionPressed(ButtonAction.ACTION_MENUCONFIRM, 0)
				or Input.IsActionPressed(ButtonAction.ACTION_MENUBACK, 0)
			if not busy then ui.block = false end
		end
		return
	end
	advance_phase()
	if ui.phase == "closed" then return end
	local box = layout()
	ui._box_s = box.s
	local nodes, content_h = build_nodes(ui.notice, box)
	local view_h = box.ph - box.header - box.footer
	ui._max_scroll = math.max(0, content_h - view_h)
	clamp_scroll()
	local s = box.s
	local view_top = box.py + box.header
	local view_bottom = box.py + box.ph - box.footer
	local close_s = 46 / 64
	local close_w = 64 * close_s * s
	local cx = box.px + box.pw - 18 * s + (box.close_x or 0)
	local cy = box.py - 8 * s + (box.close_y or 0)
	local reading = ui.phase == "reading"
	local ax = box.px + box.pw - 52 * s
	local up_y = view_top + 8 * s
	local down_y = view_bottom - 40 * s
	local track_h = math.max(1, view_bottom - view_top - 80 * s)
	local thumb_h = ui._max_scroll > 0 and math.max(24 * s, track_h * (view_h / content_h)) or track_h
	local travel = math.max(1, track_h - thumb_h)
	local ty = view_top + 40 * s + travel * (ui._max_scroll > 0 and ui.scroll / ui._max_scroll or 0)
	local player = Isaac.GetPlayer(0)
	Mouse_UI.begin_modal_frame(MODAL, player)
	Mouse_UI.register("tiny_panel", Mouse_UI.make_rect(box.px, box.py, box.pw, box.ph), {z = 1, enabled = false, block = true})
	Mouse_UI.register("tiny_close", Mouse_UI.make_rect(cx, cy, close_w, close_w), {z = 20, enabled = reading})
	Mouse_UI.register("tiny_up", Mouse_UI.make_rect(ax, up_y, 40 * s, 32 * s), {z = 12, enabled = reading and ui.scroll > 0})
	Mouse_UI.register("tiny_down", Mouse_UI.make_rect(ax, down_y, 40 * s, 32 * s), {z = 12, enabled = reading and ui.scroll < ui._max_scroll})
	if ui._max_scroll > 0 then
		Mouse_UI.register("tiny_thumb", Mouse_UI.make_rect(ax + 12 * s, ty, 16 * s, thumb_h), {z = 14, draggable = true, enabled = reading})
	end
	Mouse_UI.end_frame()
	if reading then
		if not ui.mouse_ready then
			if not Mouse_UI.is_down(0) then ui.mouse_ready = true end
		elseif Mouse_UI.is_released("tiny_close") and Mouse_UI.is_hovered("tiny_close") then
			ui.request_close()
		end
		if Mouse_UI.is_active("tiny_up") then add_scroll(-8 * s) end
		if Mouse_UI.is_active("tiny_down") then add_scroll(8 * s) end
		if Mouse_UI.is_pressed("tiny_thumb") then
			ui.drag = {y = Mouse_UI.mouse.Y, scroll = ui.scroll}
		end
		if ui.drag and Mouse_UI.is_active("tiny_thumb") then
			local dy = Mouse_UI.mouse.Y - ui.drag.y
			ui.scroll = ui.drag.scroll + dy / travel * ui._max_scroll
			clamp_scroll()
		elseif not Mouse_UI.is_down(0) then
			ui.drag = nil
		end
	end
	draw_panel(box)
	draw_header(box, ui.notice)
	draw_nodes(box, nodes)
	local zh = zh_ui()
	local font = font_for()
	local footer_top = box.py + box.ph - box.footer
	local line_h = pixel_ui.measure_line_height(1)
	local text_y = footer_top + (box.footer - line_h) * 0.5 + (ui.config.footer_text_y or 0) * s
	local alpha = box.panel_a or 1
	local left_label = zh and "退出公告" or "Close notice"
	local hint = zh and "滚轮 / ↑↓ 滚动" or "Wheel / Up / Down"
	local icon_size = 16 * s
	local left_x = box.px + box.pad
	local icon_center = text_ink_center(text_y, 1)
	draw_use_icon({
		x = left_x,
		y = icon_center - icon_size * 0.5,
		w = icon_size,
		h = icon_size,
	}, nil, alpha)
	local label_x = left_x + icon_size + 6 * s
	pixel_ui.draw_text(Vector(label_x, text_y), left_label, 1, ink(COLOR.sub, alpha), {font = font, context = "tiny_update"})
	local hint_w = pixel_ui.measure_text(hint, 1, font)
	local label_w = pixel_ui.measure_text(left_label, 1, font)
	local hint_x = box.px + box.pw - 56 * s - hint_w
	if hint_x >= label_x + label_w + 12 * s then
		pixel_ui.draw_text(Vector(hint_x, text_y), hint, 1, ink(COLOR.sub, alpha), {font = font, context = "tiny_update"})
	end
	sprite.Color = Color(1, 1, 1, box.panel_a or 1, 0, 0, 0)
	local close_name = "close_normal"
	if Mouse_UI.is_active("tiny_close") then close_name = "close_pressed"
	elseif Mouse_UI.is_hovered("tiny_close") then close_name = "close_hover" end
	draw_anim(close_name, cx, cy, close_s * s, close_s * s)
	local up_name = ui.scroll <= 0 and "up_disabled" or "up_normal"
	local down_name = ui.scroll >= ui._max_scroll and "down_disabled" or "down_normal"
	if up_name ~= "up_disabled" and Mouse_UI.is_hovered("tiny_up") then up_name = "up_hover" end
	if down_name ~= "down_disabled" and Mouse_UI.is_hovered("tiny_down") then down_name = "down_hover" end
	draw_anim(up_name, ax, up_y, s, s)
	draw_anim(down_name, ax, down_y, s, s)
	if ui._max_scroll > 0 then
		local cap = 4 * s
		local thumb_x = ax + 16 * s
		local mid_h = thumb_h - cap * 2
		draw_anim("thumb_top", thumb_x, ty, s, s)
		if mid_h > 0 then
			draw_anim("thumb_middle", thumb_x, ty + cap, s, mid_h / 16)
		end
		draw_anim("thumb_bottom", thumb_x, ty + cap + math.max(0, mid_h), s, s)
	end
	sprite.Color = Color(1, 1, 1, 1, 0, 0, 0)
	if ui.config.show_bounds then
		sprite.Color = Color(0.4, 0.8, 1, 0.9, 0, 0, 0)
		draw_anim("c", view_top and box.px or box.px, view_top, box.pw, 2)
		draw_anim("c", box.px, view_bottom - 2, box.pw, 2)
		draw_anim("c", cx, cy, close_w, 2)
		draw_anim("c", cx, cy + close_w - 2, close_w, 2)
		sprite.Color = Color(1, 1, 1, 1, 0, 0, 0)
	end
end

function ui.tick()
	if ui.phase == "closed" then
		Mouse_UI.release_modal(MODAL)
		return
	end
	local frame = Isaac.GetFrameCount()
	if ui._tick_frame == frame then return end
	ui._tick_frame = frame
	Mouse_UI.claim_modal(MODAL)
	pcall(function() auxi.refresh_time_stop(TIME_STOP_KEY, 15) end)
	if ui.phase ~= "reading" then return end
	local s = (ui._box_s) or 1
	local step = 18 * s
	local direction = 0
	local down_held = Input.IsActionPressed(ButtonAction.ACTION_DOWN, 0) or Input.IsActionPressed(ButtonAction.ACTION_MENUDOWN, 0)
	local up_held = Input.IsActionPressed(ButtonAction.ACTION_UP, 0) or Input.IsActionPressed(ButtonAction.ACTION_MENUUP, 0)
	if down_held then
		direction = 1
	elseif up_held then
		direction = -1
	end
	if direction ~= 0 then
		local speed = ui.config.key_scroll_speed or 3
		add_scroll(direction * speed * s)
	end
	local wheel = Input.GetMouseWheel and Input.GetMouseWheel() or nil
	if wheel and wheel.Y and wheel.Y ~= 0 then
		add_scroll(-wheel.Y * step * 3)
	end
	if Input.IsActionTriggered(ButtonAction.ACTION_MENUCONFIRM, 0) or Input.IsActionTriggered(ButtonAction.ACTION_MENUBACK, 0) then
		ui.request_close()
	end
	if not ui.item_ready then
		if not action_down(ButtonAction.ACTION_ITEM) then ui.item_ready = true end
	elseif action_triggered(ButtonAction.ACTION_ITEM) then
		ui.request_close()
	end
end

function ui.preview_sample()
	ui.show({
		version = 1,
		entries = {
			{item_id = CollectibleType.COLLECTIBLE_JESUS_JUICE or 197, changes = {{kind = "damage", steps = 1}, {kind = "range", steps = -1}}},
			{item_id = CollectibleType.COLLECTIBLE_DINNER or 23, changes = {{kind = "hearts", steps = 1}}},
			{item_id = CollectibleType.COLLECTIBLE_D6 or 105, changes = {{kind = "charge", steps = -1}, {kind = "pool_add", pool = ItemPoolType.POOL_SHOP}}},
		},
	}, true)
end

return ui
