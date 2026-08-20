local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local Unlocker = require("Qing_Remaster_scripts.core.unlock_manager")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local Book_of_Belial_holder = require("Qing_Remaster_scripts.mimics.Book_of_Belial_holder")
local Card_All = require("Qing_Remaster_scripts.cards.Card_All")
local Mouse_UI = require("Qing_Remaster_scripts.others.Mouse_UI_holder")
local Select = require("Qing_Remaster_scripts.others.fullscreen_select_holder")

local item = {
	pre_ToCall = {},
	ToCall = {},
	post_ToCall = {},
	myToCall = {},
	entity = enums.Items.Book_of_Thoth,
	own_key = "Item_Book_of_Thoth_",
	max_revelation = 12,
	max_formation = 3,
	nav_repeat_initial = 22,
	nav_repeat_interval = 6,
	seen_weight = 1,
	unseen_weight = 3,
	Seija_desc = {
		["zh"] = {Name = "未知塔罗牌", Description = "所示不详",},
		["en"] = {Name = "Unknown Card", Description = "Not in detail",},
	},
}
auxi.add_to_seija(item.entity)

local translations = require("Qing_Remaster_scripts.translations.translate")
local card_spr = Sprite()
card_spr:Load("gfx/ui/EID/qing_cardpill_icons.anm2", true)
local back_spr = Sprite()
back_spr:Load("gfx/ui/EID/qing_cardpill_icons2.anm2", true)
local cdsprite2 = Sprite()
cdsprite2:Load("gfx/ui/EID/qing_cardpill_icons2.anm2", true)

local thoth_list_cache = nil
local card_meta_cache = {}
local PANEL_ID = "thoth"

local function is_zh()
	return auxi.get_EID_language() == "zh_cn"
end

local function debug_root()
	local root = save.ModConfigSettings
	local options = root and root.QingRemasterOptions
	return options and options.Debug
end

-- 卡册内缩仍按 HUD 安全区写死。占卜只暴露一个分区比例。
item.layout_defaults = {
	DivineSplit = 0.4,
	ConfirmY = 0,
	DotOffsetX = 0,
	DotOffsetY = -11,
}

function item.get_layout()
	local debug = debug_root() or {}
	local defaults = item.layout_defaults
	local function n(key, lo, hi)
		local value = tonumber(debug["BookOfThoth"..key])
		if value == nil then
			value = defaults[key]
		end
		if lo and value < lo then value = lo end
		if hi and value > hi then value = hi end
		return value
	end
	return {
		divine_split = n("DivineSplit", 0.2, 0.8),
		confirm_y = n("ConfirmY"),
		dot_x = n("DotOffsetX"),
		dot_y = n("DotOffsetY"),
	}
end

function item.force_seija()
	local debug = debug_root()
	return debug and debug.BookOfThothForceSeija == true
end

function item.is_seija(player)
	if item.force_seija() then return true end
	return player and auxi.should_do_Seija(player) == true
end

local function txt(key)
	local zh = {
		title = "透特之书",
		tab_catalog = "卡册",
		tab_divine = "占卜",
		rev = "启示",
		locked = "当前解读尚未结束",
		hint_catalog = "浏览已收录牌面  滚轮或两侧翻页  正逆位均收录后呈金色",
		hint_divine = "将已登记牌拖入上方槽位  超出启示的牌面为红  充能不足时无法确认",
		page_prev = "上一页",
		page_next = "下一页",
		empty = "???",
		spent = "已发动",
		next = "下一张",
		wait = "等待中",
		confirm = "确认占卜",
		unregistered = "尚未收录",
	}
	local en = {
		title = "Book of Thoth",
		tab_catalog = "Codex",
		tab_divine = "Reading",
		rev = "Revelation",
		locked = "This reading is not finished",
		hint_catalog = "Browse registered faces. Scroll or use the sides to turn pages. Gold when both faces are owned.",
		hint_divine = "Drag registered faces into slots. Faces beyond Revelation turn red; confirm stays locked until you can pay.",
		page_prev = "Prev",
		page_next = "Next",
		empty = "???",
		spent = "Spent",
		next = "Next",
		wait = "Waiting",
		confirm = "Confirm spread",
		unregistered = "Unregistered",
	}
	local bag = is_zh() and zh or en
	return bag[key] or key
end

local function player_index(player)
	if not player then return nil end
	local ok, d = pcall(function() return player:GetData() end)
	if not ok or type(d) ~= "table" then return nil end
	return d.__Index
end

local function data_root()
	save.elses = save.elses or {}
	save.elses[item.own_key.."data"] = save.elses[item.own_key.."data"] or {}
	return save.elses[item.own_key.."data"]
end

local function peek_bag(player)
	local idx = player_index(player)
	if idx == nil then return nil end
	local root = data_root()
	local bag = root[idx]
	if type(bag) ~= "table" then return nil end
	bag.registered = bag.registered or {}
	bag.formation = bag.formation or {}
	bag.formationIndex = bag.formationIndex or 1
	bag.revelation = math.max(0, math.min(item.max_revelation, tonumber(bag.revelation) or 0))
	return bag
end

local function get_bag(player)
	local idx = player_index(player)
	if idx == nil then return nil end
	local root = data_root()
	local bag = root[idx]
	if type(bag) ~= "table" then
		bag = {
			owned = false,
			revelation = 0,
			registered = {},
			formation = {},
			formationIndex = 1,
			pendingCast = nil,
		}
		root[idx] = bag
	end
	return peek_bag(player)
end

local function is_face_registered(bag, card_id)
	if not bag or not card_id then return false end
	return bag.registered[tostring(card_id)] == true
end

local function register_face(player, card_id)
	local bag = get_bag(player)
	if not bag or not bag.owned then return false end
	if not auxi.is_thoth_card(card_id) then return false end
	local key = tostring(card_id)
	if bag.registered[key] then return false end
	bag.registered[key] = true
	return true
end

local function formation_active(bag)
	if not bag then return false end
	local list = bag.formation or {}
	local idx = bag.formationIndex or 1
	return #list > 0 and idx <= #list
end

local function get_revelation(player)
	local bag = get_bag(player)
	if not bag then return 0 end
	return bag.revelation or 0
end

local function set_revelation(player, value)
	local bag = get_bag(player)
	if not bag then return 0 end
	bag.revelation = math.max(0, math.min(item.max_revelation, math.floor(tonumber(value) or 0)))
	return bag.revelation
end

local function add_revelation(player, amount)
	return set_revelation(player, get_revelation(player) + (amount or 1))
end

local function sync_charge(player)
	if not player or not auxi.has_have_coll(player, item.entity) then return end
	local rev = get_revelation(player)
	for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET do
		if player:GetActiveItem(slot) == item.entity then
			local current = (player:GetActiveCharge(slot) or 0) + (player:GetBatteryCharge(slot) or 0)
			if current ~= rev then
				player:SetActiveCharge(rev, slot)
			end
		end
	end
end

local function other_active_needs_charge(player)
	for slot = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET do
		local cid = player:GetActiveItem(slot)
		if cid and cid > 0 and cid ~= item.entity then
			local cfg = Isaac.GetItemConfig():GetCollectible(cid)
			if cfg and (cfg.MaxCharges or 0) > 0 then
				local cur = (player:GetActiveCharge(slot) or 0) + (player:GetBatteryCharge(slot) or 0)
				if cur < cfg.MaxCharges then return true end
			end
		end
	end
	return false
end

local function list_thoth_cards()
	if thoth_list_cache then return thoth_list_cache end
	thoth_list_cache = {}
	for _, entry in ipairs(Card_All.list_configurable_cards()) do
		if type(entry.id) == "number" and entry.id > 0 then
			thoth_list_cache[#thoth_list_cache + 1] = entry.id
		end
	end
	return thoth_list_cache
end

local function card_meta(card_id)
	card_id = tonumber(card_id)
	if not card_id then return {frame = 0, name = txt("empty")} end
	local cached = card_meta_cache[card_id]
	if cached then return cached end
	local name = txt("empty")
	local frame = 0
	for _, entry in pairs(translations.Cards or {}) do
		if entry.id == card_id then
			local lang = is_zh() and entry.zh or entry.en
			lang = lang or entry.zh or entry.en
			if lang then
				name = lang.Name or name
				frame = lang.Frame or frame
			end
			break
		end
	end
	if name == txt("empty") then
		local cfg = Isaac.GetItemConfig():GetCard(card_id)
		if cfg and cfg.Name then name = auxi.check_name_data and auxi.check_name_data(cfg.Name) or cfg.Name end
	end
	cached = {frame = frame, name = name}
	card_meta_cache[card_id] = cached
	return cached
end

local function is_face_unseen(card_id)
	local root = data_root()
	for _, bag in pairs(root) do
		if type(bag) == "table" and bag.owned and is_face_registered(bag, card_id) then
			return false
		end
	end
	return true
end

local function pick_weighted_thoth(rng)
	rng = auxi.rng_for_sake(rng)
	local pool = {}
	local total = 0
	for _, card_id in ipairs(list_thoth_cards()) do
		if Card_All.get_card_appear_rate(card_id) > 0 then
			local w = is_face_unseen(card_id) and item.unseen_weight or item.seen_weight
			pool[#pool + 1] = {id = card_id, weight = w}
			total = total + w
		end
	end
	if total <= 0 or #pool == 0 then return nil end
	local roll = rng:RandomInt(total)
	local acc = 0
	for i = 1, #pool do
		acc = acc + pool[i].weight
		if roll < acc then return pool[i].id end
	end
	return pool[#pool].id
end

local function anyone_holds_book()
	return auxi.have_player_has_collectible(item.entity) ~= nil
end

local function draft_compact(draft)
	local out = {}
	if type(draft) ~= "table" then return out end
	for i = 1, item.max_formation do
		local id = draft[i]
		if id then out[#out + 1] = id end
	end
	return out
end

local function slot_is_unpaid(draft, slot, revelation)
	if type(draft) ~= "table" or not slot or not draft[slot] then return false end
	local paid = 0
	local rev = math.max(0, math.floor(tonumber(revelation) or 0))
	for i = 1, item.max_formation do
		if draft[i] then
			paid = paid + 1
			if i == slot then
				return paid > rev
			end
		end
	end
	return false
end

local function deficit_color(alpha)
	local col = Color(1, 0.32, 0.32, alpha or 1)
	if col.SetColorize then col:SetColorize(1.55, 0.12, 0.08, 1) end
	return col
end

local function clear_sprite_color(spr)
	if not spr then return end
	local col = Color(1, 1, 1, 1)
	if col.SetColorize then col:SetColorize(0, 0, 0, 0) end
	spr.Color = col
end

local function draft_can_confirm(player, draft)
	local n = #draft_compact(draft)
	if n < 1 then return false end
	return n <= get_revelation(player)
end

local function draft_has(draft, card_id)
	if type(draft) ~= "table" then return nil end
	for i = 1, item.max_formation do
		if draft[i] == card_id then return i end
	end
	return nil
end

local function card_is_unpaid(draft, card_id, revelation)
	local slot = draft_has(draft, card_id)
	if not slot then return false end
	return slot_is_unpaid(draft, slot, revelation)
end

local function apply_draft(player, draft)
	local bag = get_bag(player)
	if not bag then return -1 end
	if formation_active(bag) then return -1 end
	local copy = draft_compact(draft)
	if #copy < 1 then return 0 end
	if #copy > item.max_formation then return -1 end
	if #copy > get_revelation(player) then return -1 end
	local seen = {}
	for i = 1, #copy do
		local id = copy[i]
		if not is_face_registered(bag, id) then return -1 end
		if seen[id] then return -1 end
		seen[id] = true
	end
	set_revelation(player, get_revelation(player) - #copy)
	bag.formation = copy
	bag.formationIndex = 1
	sync_charge(player)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOOK_PAGE_TURN_12, 1, 1, false, 0, 2)
	return 1
end

local function render_card_icon(card_id, pos, scale, col, registered)
	scale = scale or 1
	if registered then
		local meta = card_meta(card_id)
		card_spr.Color = col or Color(1, 1, 1, 1)
		card_spr.Scale = Vector(scale, scale)
		card_spr:SetFrame("Card", meta.frame or 0)
		card_spr:Render(pos, Vector(0, 0), Vector(0, 0))
	else
		back_spr.Color = col or Color(0.35, 0.35, 0.4, 0.9)
		back_spr.Scale = Vector(scale, scale)
		local frame = auxi.is_reversed_card(card_id) and 1 or 0
		back_spr:SetFrame("pickups", frame)
		back_spr:Render(pos, Vector(0, 0), Vector(0, 0))
	end
	card_spr.Scale = Vector(1, 1)
	back_spr.Scale = Vector(1, 1)
	clear_sprite_color(card_spr)
	clear_sprite_color(back_spr)
end

do
	local CARD_W, CARD_H = 16, 20
	local GOLDEN = (AnimRenderFlags and AnimRenderFlags.GOLDEN) or (1 << 7)
	local IGNORE_GT = (AnimRenderFlags and AnimRenderFlags.IGNORE_GAME_TIME) or (1 << 6)
	local dim_spr = Sprite()
	dim_spr:Load("gfx/Black.anm2", true)
	dim_spr:Play("Idle", true)
	local front_spr = Sprite()
	local front_path, front_hud, front_card = nil, nil, nil
	local pair_mates = nil
	local catalog_units = nil
	local catalog_pages = nil
	local catalog_pages_span = nil
	local PAIR_GAP = 6
	local GROUP_PAD = 8
	local INNER_GAP = 8
	local BAND_GAP = 10
	local MIN_SCALE = 1.0
	local MAX_SCALE_CATALOG = 2.2
	local MAX_SCALE_DIVINE = 1.7
	local SAFE_LEFT = 78
	local SAFE_RIGHT = 78
	local SAFE_TOP = 54
	local SAFE_BOTTOM = 44

	local function valid_card(id)
		return type(id) == "number" and id > 0
	end

	local function build_catalog_units()
		if catalog_units then return catalog_units end
		local C = enums.Cards
		catalog_units = {
			{kind = "pair", up = C.Fool, down = C.Fool_r},
			{kind = "fan_up", ups = {C.Witch, C.Invoker, C.Wizard}, down = C.Sage_r},
			{kind = "pair", up = C.Priestess, down = C.Priestess_r},
			{kind = "pair", up = C.Empress, down = C.Empress_r},
			{kind = "pair", up = C.Emperor, down = C.Emperor_r},
			{kind = "pair", up = C.Hierophant, down = C.Hierophant_r},
			{kind = "pair", up = C.Lover, down = C.Lover_r},
			{kind = "pair", up = C.Chariot, down = C.Chariot_r},
			{kind = "pair", up = C.Adjustment, down = C.Adjustment_r},
			{kind = "pair", up = C.Hermit, down = C.Hermit_r},
			{kind = "pair", up = C.Wheel_of_Destiny, down = C.Wheel_of_Destiny_r},
			{kind = "pair", up = C.Lure, down = C.Lure_r},
			{kind = "pair", up = C.Hanged_Man, down = C.Hanged_Man_r},
			{kind = "fan_down", up = C.Faint, downs = {C.Faint_r, C.Death_r, C.Corpse_r}},
			{kind = "pair", up = C.Art, down = C.Art_r},
			{kind = "pair", up = C.Devil, down = C.Devil_r},
			{kind = "pair", up = C.Tower, down = C.Tower_r},
			{kind = "pair", up = C.Star, down = C.Star_r},
			{kind = "pair", up = C.Moon, down = C.Moon_r},
			{kind = "pair", up = C.Sun, down = C.Sun_r},
			{kind = "pair", up = C.Aeon, down = C.Aeon_r},
			{kind = "pair", up = C.Universe, down = C.Universe_r},
			{kind = "pair", up = C.Eclipse, down = C.Eclipse_r},
			{kind = "pair", up = C.Profound, down = C.Profound_r},
			{kind = "pair", up = C.Sting, down = C.Sting_r},
		}
		return catalog_units
	end

	local function unit_span(u)
		if u and (u.kind == "fan_up" or u.kind == "fan_down") then return 3 end
		return 1
	end

	local function content_rect(screen, opts)
		opts = opts or {}
		local left = opts.left or SAFE_LEFT
		local right = opts.right or SAFE_RIGHT
		local top = opts.top or SAFE_TOP
		local bottom = opts.bottom or SAFE_BOTTOM
		return Mouse_UI.make_rect(
			left,
			top,
			math.max(80, screen.X - left - right),
			math.max(60, screen.Y - top - bottom)
		)
	end

	local function margin_rect(screen, y, h)
		return Mouse_UI.make_rect(SAFE_LEFT, y, math.max(80, screen.X - SAFE_LEFT - SAFE_RIGHT), h)
	end

	-- 先按高度放下 2 行正逆位带，再用剩余宽度决定一行多少列。
	-- 旧逻辑写死 4 列再居中放大，所以改内缩不会增加每行张数。
	local function grid_for_area(area, max_scale)
		max_scale = max_scale or MAX_SCALE_CATALOG
		local rows = 2
		local h_scale = (area.h - (rows - 1) * BAND_GAP - rows * INNER_GAP) / math.max(1, rows * 2 * CARD_H)
		if h_scale < MIN_SCALE then
			rows = 1
			h_scale = (area.h - INNER_GAP) / math.max(1, 2 * CARD_H)
		end
		local scale = math.min(max_scale, math.max(MIN_SCALE, h_scale))
		local cols = math.floor((area.w + PAIR_GAP) / (CARD_W * scale + PAIR_GAP))
		if cols < 4 then cols = 4 end
		if cols > 10 then cols = 10 end
		local w_scale = (area.w - math.max(0, cols - 1) * PAIR_GAP) / math.max(1, cols * CARD_W)
		scale = math.max(MIN_SCALE, math.min(scale, w_scale, max_scale))
		return cols, rows, scale
	end

	local function page_span_now()
		local screen = ui.GetScreenSize()
		local cols, rows = grid_for_area(content_rect(screen), MAX_SCALE_CATALOG)
		return math.max(4, cols * rows)
	end

	local function build_catalog_pages()
		local span = page_span_now()
		if catalog_pages and catalog_pages_span == span then return catalog_pages end
		catalog_pages = {}
		catalog_pages_span = span
		local cur, used = {}, 0
		for _, u in ipairs(build_catalog_units()) do
			local unit = unit_span(u)
			if used > 0 and used + unit > span then
				catalog_pages[#catalog_pages + 1] = cur
				cur, used = {}, 0
			end
			cur[#cur + 1] = u
			used = used + unit
		end
		if #cur > 0 then catalog_pages[#catalog_pages + 1] = cur end
		return catalog_pages
	end

	local function page_count()
		return #build_catalog_pages()
	end

	local function clamp_page(session)
		local n = math.max(1, page_count())
		session.page = math.max(1, math.min(n, math.floor(tonumber(session.page) or 1)))
		return session.page
	end

	local function current_page_units(session)
		local pages = build_catalog_pages()
		return pages[clamp_page(session)] or pages[1]
	end

	local function change_page(session, delta)
		local n = page_count()
		if n <= 1 or not delta or delta == 0 then return end
		session.page = ((clamp_page(session) - 1 + delta) % n) + 1
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOOK_PAGE_TURN_12, 0.85, 1, false, 0, 2)
	end

	local function page_linear(page, gap, group_pad)
		local coeff, const = 0, 0
		for i, u in ipairs(page) do
			if u.kind == "pair" then
				coeff = coeff + 1
			else
				coeff = coeff + 3
				const = const + 2 * gap
			end
			if i < #page then
				const = const + gap
				if u.kind ~= "pair" or page[i + 1].kind ~= "pair" then
					const = const + group_pad
				end
			end
		end
		return coeff, const
	end

	local function split_into_bands(page, band_span)
		band_span = math.max(3, math.floor(band_span or 8))
		local bands, cur, used = {}, {}, 0
		local function flush()
			if #cur > 0 then
				bands[#bands + 1] = cur
				cur, used = {}, 0
			end
		end
		for _, u in ipairs(page or {}) do
			local span = unit_span(u)
			if #cur > 0 and used + span > band_span then
				flush()
			end
			cur[#cur + 1] = u
			used = used + span
		end
		flush()
		return bands
	end

	local function emit_placements(page, origin_x, origin_y, w, h, gap, inner, group_pad)
		local x = origin_x
		local list = {}
		local groups = {}
		local function add(card_id, rx, ry)
			if not valid_card(card_id) then return end
			list[#list + 1] = {
				card_id = card_id,
				rect = Mouse_UI.make_rect(rx, ry, w, h),
				scale = w / CARD_W,
			}
		end
		for i, u in ipairs(page) do
			if u.kind == "pair" then
				add(u.up, x, origin_y)
				add(u.down, x, origin_y + h + inner)
				x = x + w
			elseif u.kind == "fan_up" then
				local gw = 3 * w + 2 * gap
				groups[#groups + 1] = Mouse_UI.make_rect(x - 4, origin_y - 4, gw + 8, h * 2 + inner + 8)
				for ui, up in ipairs(u.ups or {}) do
					add(up, x + (ui - 1) * (w + gap), origin_y)
				end
				add(u.down, x + (gw - w) * 0.5, origin_y + h + inner)
				x = x + gw
			else
				local gw = 3 * w + 2 * gap
				groups[#groups + 1] = Mouse_UI.make_rect(x - 4, origin_y - 4, gw + 8, h * 2 + inner + 8)
				add(u.up, x + (gw - w) * 0.5, origin_y)
				for di, down in ipairs(u.downs or {}) do
					add(down, x + (di - 1) * (w + gap), origin_y + h + inner)
				end
				x = x + gw
			end
			if i < #page then
				x = x + gap
				if u.kind ~= "pair" or page[i + 1].kind ~= "pair" then
					x = x + group_pad
				end
			end
		end
		return list, groups
	end

	local function fit_scale_for_bands(avail_w, avail_h, bands, max_scale)
		local n_bands = 0
		local w_scale = 99
		for _, band in ipairs(bands or {}) do
			if band and #band > 0 then
				n_bands = n_bands + 1
				local coeff, const = page_linear(band, PAIR_GAP, GROUP_PAD)
				local s = (avail_w - const) / math.max(1, coeff * CARD_W)
				if s < w_scale then w_scale = s end
			end
		end
		n_bands = math.max(1, n_bands)
		local h_budget = avail_h - (n_bands - 1) * BAND_GAP - n_bands * INNER_GAP
		local h_scale = h_budget / (n_bands * 2 * CARD_H)
		local scale = math.min(h_scale, w_scale, max_scale or MAX_SCALE_CATALOG)
		return math.max(MIN_SCALE, scale)
	end

	local function layout_page_bands(page, area, max_scale)
		local cols = grid_for_area(area, max_scale)
		local bands = split_into_bands(page, cols)
		local scale = fit_scale_for_bands(area.w, area.h, bands, max_scale)
		local w, h = CARD_W * scale, CARD_H * scale
		local band_h = h * 2 + INNER_GAP
		local n_bands = 0
		for _, band in ipairs(bands) do
			if #band > 0 then n_bands = n_bands + 1 end
		end
		n_bands = math.max(1, n_bands)
		local total_h = n_bands * band_h + (n_bands - 1) * BAND_GAP
		local y = area.y + math.max(0, (area.h - total_h) * 0.18)
		local placements, groups = {}, {}
		for _, band in ipairs(bands) do
			if #band > 0 then
				local coeff, const = page_linear(band, PAIR_GAP, GROUP_PAD)
				local total_w = coeff * w + const
				local x = area.x + math.max(0, (area.w - total_w) * 0.5)
				if x + total_w > area.x + area.w then
					x = area.x
				end
				local pl, gr = emit_placements(band, x, y, w, h, PAIR_GAP, INNER_GAP, GROUP_PAD)
				for i = 1, #pl do placements[#placements + 1] = pl[i] end
				for i = 1, #gr do groups[#groups + 1] = gr[i] end
				y = y + band_h + BAND_GAP
			end
		end
		return {
			scale = scale,
			w = w,
			h = h,
			placements = placements,
			groups = groups,
		}
	end

	local function build_pair_mates()
		if pair_mates then return pair_mates end
		pair_mates = {}
		local function link(a, b)
			if not valid_card(a) or not valid_card(b) then return end
			pair_mates[a] = pair_mates[a] or {}
			pair_mates[b] = pair_mates[b] or {}
			pair_mates[a][#pair_mates[a] + 1] = b
			pair_mates[b][#pair_mates[b] + 1] = a
		end
		for _, u in ipairs(build_catalog_units()) do
			if u.kind == "pair" then
				link(u.up, u.down)
			elseif u.kind == "fan_up" then
				for _, up in ipairs(u.ups or {}) do
					link(up, u.down)
				end
			elseif u.kind == "fan_down" then
				for _, down in ipairs(u.downs or {}) do
					link(u.up, down)
				end
			end
		end
		return pair_mates
	end

	local function should_gold(bag, card_id)
		if not is_face_registered(bag, card_id) then return false end
		local mates = build_pair_mates()[card_id]
		if not mates or #mates == 0 then return false end
		for i = 1, #mates do
			if is_face_registered(bag, mates[i]) then return true end
		end
		return false
	end

	local function resolve_card_front(card_id)
		local cfg = Isaac.GetItemConfig():GetCard(card_id)
		if not cfg then return nil, nil end
		local hud = cfg.HudAnim
		if (not hud or hud == "") and cfg.GetHudAnim then
			hud = cfg:GetHudAnim()
		end
		if hud and hud ~= "" then
			return hud, "gfx/ui/content/ui_cardfronts.anm2"
		end
		return "CardFronts", "gfx/ui/ui_cardspills.anm2"
	end

	local function prepare_front(card_id)
		local hud, path = resolve_card_front(card_id)
		if not hud or not path then return false end
		if path ~= front_path then
			front_spr:Load(path, true)
			front_path = path
			front_hud = nil
			front_card = nil
		end
		if hud ~= front_hud or card_id ~= front_card then
			if hud == "CardFronts" then
				front_spr:SetFrame("CardFronts", card_id)
			else
				front_spr:SetFrame(hud, 0)
			end
			front_hud = hud
			front_card = card_id
		end
		return true
	end

	local function apply_gold_look(on)
		if front_spr.SetRenderFlags then
			if on then
				front_spr:SetRenderFlags(GOLDEN | IGNORE_GT)
			else
				front_spr:SetRenderFlags(0)
			end
		elseif on and front_spr.SetCustomShader then
			pcall(function() front_spr:SetCustomShader("shaders/coloroffset_gold") end)
		elseif front_spr.ClearCustomShader then
			pcall(function() front_spr:ClearCustomShader() end)
		end
	end

	local function gray_color(alpha)
		local col = Color(0.55, 0.55, 0.55, alpha or 1)
		if col.SetColorize then col:SetColorize(1, 1, 1, 1) end
		return col
	end

	local function card_center_shift(scale)
		scale = scale or 1
		local frame = front_spr.GetLayerFrameData and front_spr:GetLayerFrameData(0)
		if frame and frame.GetPivot and frame.GetWidth and frame.GetHeight then
			local pivot = frame:GetPivot()
			local w, h = frame:GetWidth(), frame:GetHeight()
			if pivot and w and h and w > 0 and h > 0 then
				return Vector((pivot.X - w * 0.5) * scale, (pivot.Y - h * 0.5) * scale)
			end
		end
		-- 卡面默认 16x20、轴心 (8,12)：轴心低于几何中心，Render 在矩形中心会偏上
		return Vector(0, 2 * scale)
	end

	local function render_card_front(card_id, pos, scale, bag, opts)
		opts = opts or {}
		if not prepare_front(card_id) then return end
		local registered = bag and is_face_registered(bag, card_id)
		local gold = (not opts.no_gold) and (opts.color == nil) and should_gold(bag, card_id)
		if registered then
			front_spr.Color = opts.color or Color(1, 1, 1, opts.alpha or 1)
		else
			front_spr.Color = opts.color or gray_color(opts.alpha or 1)
		end
		front_spr.Scale = Vector(scale, scale)
		apply_gold_look(gold == true)
		front_spr:Render(pos + card_center_shift(scale), Vector(0, 0), Vector(0, 0))
		apply_gold_look(false)
		front_spr.Scale = Vector(1, 1)
		clear_sprite_color(front_spr)
	end

	local function screen_size()
		return ui.GetScreenSize()
	end

	local function draw_dim()
		local center = ui.GetScreenCenter()
		dim_spr.Color = Color(1, 1, 1, 0.72)
		dim_spr:Render(center, Vector(0, 0), Vector(0, 0))
		dim_spr.Color = Color(1, 1, 1, 1)
	end

	-- `.` 字形相对几何角点有 bearing；默认 (0,-11)，ImGui 可改
	local function dot_offset()
		local lay = item.get_layout()
		return Vector(lay.dot_x, lay.dot_y)
	end
	-- DrawString 原点在字框左上；与 `.` 不同，视觉中心偏上，X 仍用同一套横向 bearing
	local TEXT_OFFSET = Vector(-2, 2)

	local function ui_font()
		if is_zh() and gui.f2 and gui.f2.IsLoaded and gui.f2:IsLoaded() then
			return gui.f2
		end
		return gui.f
	end

	local function draw_text_in_rect(rect, text, color, opts)
		if not rect or not text then return end
		opts = opts or {}
		local sx = opts.sx or 1
		local sy = opts.sy or 1
		local font = opts.font or ui_font()
		local line_h = (font.GetLineHeight and font:GetLineHeight() or 12) * sy
		local pad_x = opts.pad_x or 0
		local y = rect.y + (opts.pad_y ~= nil and opts.pad_y or ((rect.h - line_h) * 0.5)) + TEXT_OFFSET.Y
		local x = rect.x + pad_x + TEXT_OFFSET.X
		local box_w = math.max(0, math.floor(rect.w - pad_x * 2))
		color = color or KColor(1, 1, 1, 1)
		if opts.align == "left" then
			font:DrawStringScaledUTF8(text, x, y, sx, sy, color, 0, false)
		else
			font:DrawStringScaledUTF8(text, x, y, sx, sy, color, box_w, true)
		end
	end

	local function draw_box(rect, hot)
		if not rect then return end
		local col = hot and KColor(1, 0.9, 0.4, 1) or KColor(0.45, 0.5, 0.7, 0.7)
		local off = dot_offset()
		local step = 6
		for x = 0, rect.w, step do
			gui.draw_ch(Vector(rect.x + x + off.X, rect.y + off.Y), ".", 1, 1, col, true)
			gui.draw_ch(Vector(rect.x + x + off.X, rect.y + rect.h - 2 + off.Y), ".", 1, 1, col, true)
		end
		for y = 0, rect.h, step do
			gui.draw_ch(Vector(rect.x + off.X, rect.y + y + off.Y), ".", 1, 1, col, true)
			gui.draw_ch(Vector(rect.x + rect.w - 2 + off.X, rect.y + y + off.Y), ".", 1, 1, col, true)
		end
	end

	local function nav_add(list, id, rect)
		if not id or not rect then return end
		list[#list + 1] = {
			id = id,
			x = rect.x + rect.w * 0.5,
			y = rect.y + rect.h * 0.5,
			rect = rect,
		}
	end

	local function index_of_id(list, id)
		if not list or not id then return nil end
		for i = 1, #list do
			if list[i].id == id then return i end
		end
		return nil
	end

	local function sort_reading(list)
		table.sort(list, function(a, b)
			if math.abs(a.y - b.y) > 10 then return a.y < b.y end
			return a.x < b.x
		end)
	end

	-- 组内前进无目标时回到第一项；后退无目标时回到最后一项。
	local function pick_forward_or_edge(list, from, dirx, diry)
		local best_id, best = nil, math.huge
		for i = 1, #list do
			local to = list[i]
			if to.id ~= from.id then
				local dx, dy = to.x - from.x, to.y - from.y
				local primary = dx * dirx + dy * diry
				local lateral = math.abs(dx * (-diry) + dy * dirx)
				if primary > 3 then
					local s = primary + lateral * 2.4
					if s < best then best, best_id = s, to.id end
				end
			end
		end
		if best_id then return best_id, false end
		if #list == 0 then return from.id, true end
		if dirx > 0 or diry > 0 then
			return list[1].id, true
		end
		return list[#list].id, true
	end

	local function is_top_row_of(list, id)
		local idx = index_of_id(list, id)
		if not idx then return true end
		local y0 = list[idx].y
		for i = 1, #list do
			if list[i].y < y0 - 10 then return false end
		end
		return true
	end

	local function snap_focus(session)
		local groups = session._nav_groups
		if not groups then return end
		local gname = session.nav_group
		if gname ~= "tabs" and gname ~= "body" then
			gname = "tabs"
			session.nav_group = "tabs"
		end
		local list = groups[gname]
		if list and index_of_id(list, session.focus_id) then return end
		if groups.tabs and index_of_id(groups.tabs, session.focus_id) then
			session.nav_group = "tabs"
			return
		end
		if groups.body and index_of_id(groups.body, session.focus_id) then
			session.nav_group = "body"
			return
		end
		list = groups[session.nav_group] or groups.body or groups.tabs
		if list and list[1] then
			session.focus_id = list[1].id
		end
	end

	local function move_focus(session, dir)
		local groups = session._nav_groups
		if not groups then return false end
		local gname = session.nav_group or "tabs"
		local list = groups[gname]
		if not list or #list == 0 then return false end
		local idx = index_of_id(list, session.focus_id) or 1
		local from = list[idx]

		if gname == "tabs" then
			if dir == "down" and groups.body and #groups.body > 0 then
				session.nav_group = "body"
				local mem = session.body_focus_mem
				if mem and index_of_id(groups.body, mem) then
					session.focus_id = mem
				else
					session.focus_id = groups.body[1].id
				end
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.25, 1.1, false, 0, 2)
				return true
			end
			if dir == "up" then return false end
			local dirx = (dir == "right" and 1) or (dir == "left" and -1) or 0
			if dirx == 0 then return false end
			local nidx
			if dir == "right" then
				nidx = (idx >= #list) and 1 or (idx + 1)
			else
				nidx = (idx <= 1) and #list or (idx - 1)
			end
			if list[nidx].id == session.focus_id then return false end
			session.focus_id = list[nidx].id
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.25, 1.1, false, 0, 2)
			return true
		end

		if dir == "up" and is_top_row_of(list, from.id) and groups.tabs and #groups.tabs > 0 then
			session.body_focus_mem = session.focus_id
			session.nav_group = "tabs"
			session.focus_id = (session.tab == "divine") and "tab_divine" or "tab_catalog"
			if not index_of_id(groups.tabs, session.focus_id) then
				session.focus_id = groups.tabs[1].id
			end
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.25, 1.1, false, 0, 2)
			return true
		end

		local dirx = (dir == "right" and 1) or (dir == "left" and -1) or 0
		local diry = (dir == "down" and 1) or (dir == "up" and -1) or 0
		local nxt, wrapped = pick_forward_or_edge(list, from, dirx, diry)
		local from_pager = from.id == "btn_prev" or from.id == "btn_next"
		local pager_steal = nxt == "btn_prev" or nxt == "btn_next"
		-- 内容组左右到边沿翻页；不要被底栏翻页钮拐走。搬运阵位时只在槽间循环。
		if (dir == "left" or dir == "right") and not session.pad_carry and (wrapped or (pager_steal and not from_pager)) then
			change_page(session, dir == "left" and -1 or 1)
			return true
		end
		if not nxt or nxt == session.focus_id then return false end
		session.focus_id = nxt
		session.body_focus_mem = nxt
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.25, 1.1, false, 0, 2)
		return true
	end

	local function get_held_nav_dir(ctrlid)
		local function down(a) return Input.IsActionPressed(a, ctrlid) end
		if down(ButtonAction.ACTION_LEFT) or down(ButtonAction.ACTION_MENULEFT) or down(ButtonAction.ACTION_SHOOTLEFT) then return "left" end
		if down(ButtonAction.ACTION_RIGHT) or down(ButtonAction.ACTION_MENURIGHT) or down(ButtonAction.ACTION_SHOOTRIGHT) then return "right" end
		if down(ButtonAction.ACTION_UP) or down(ButtonAction.ACTION_MENUUP) or down(ButtonAction.ACTION_SHOOTUP) then return "up" end
		if down(ButtonAction.ACTION_DOWN) or down(ButtonAction.ACTION_MENUDOWN) or down(ButtonAction.ACTION_SHOOTDOWN) then return "down" end
		return nil
	end

	local function catalog_layout(screen, page)
		return layout_page_bands(page, content_rect(screen), MAX_SCALE_CATALOG)
	end

	local function divine_layout(screen, page)
		local cfg = item.get_layout()
		local area = content_rect(screen)
		local split = cfg.divine_split
		local split_gap = 8
		local upper_h = math.max(48, (area.h - split_gap) * split)
		local lower_h = math.max(48, area.h - split_gap - upper_h)
		upper_h = area.h - split_gap - lower_h
		local slot_scale = math.min(2.15, math.max(1.45, area.w / 220))
		local slot_w, slot_h = CARD_W * slot_scale, CARD_H * slot_scale
		local gap = 14
		local confirm_h = 16
		local confirm_gap = 8
		local total_w = item.max_formation * slot_w + (item.max_formation - 1) * gap
		if total_w > area.w then
			slot_scale = (area.w - (item.max_formation - 1) * gap) / math.max(1, item.max_formation * CARD_W)
			slot_scale = math.max(MIN_SCALE, slot_scale)
			slot_w, slot_h = CARD_W * slot_scale, CARD_H * slot_scale
			total_w = item.max_formation * slot_w + (item.max_formation - 1) * gap
		end
		local max_slot_h = math.max(8, upper_h - confirm_h - confirm_gap)
		slot_scale = math.min(slot_scale, max_slot_h / CARD_H)
		slot_w, slot_h = CARD_W * slot_scale, CARD_H * slot_scale
		total_w = item.max_formation * slot_w + (item.max_formation - 1) * gap
		local start_x = area.x + math.max(0, (area.w - total_w) * 0.5)
		local slot_y = area.y + math.max(0, (max_slot_h - slot_h) * 0.5)
		local slot_bottom = slot_y + slot_h
		local upper_bottom = area.y + upper_h
		local gap_space = upper_bottom - slot_bottom
		local confirm_y
		if gap_space >= confirm_h then
			confirm_y = slot_bottom + (gap_space - confirm_h) * 0.5
		else
			confirm_y = upper_bottom - confirm_h
		end
		confirm_y = confirm_y + (cfg.confirm_y or 0)
		local pool_y = area.y + upper_h + split_gap
		local slots = {}
		for i = 1, item.max_formation do
			slots[i] = Mouse_UI.make_rect(start_x + (i - 1) * (slot_w + gap), slot_y, slot_w, slot_h)
		end
		local confirm = Mouse_UI.make_rect(area.x + area.w * 0.5 - 46, confirm_y, 92, confirm_h)
		local pool = Mouse_UI.make_rect(area.x, pool_y, area.w, math.max(48, area.y + area.h - pool_y))
		local lay = layout_page_bands(page, pool, MAX_SCALE_DIVINE)
		return {
			slot_scale = slot_scale,
			slots = slots,
			confirm = confirm,
			pool = pool,
			area = area,
			placements = lay.placements,
			groups = lay.groups,
		}
	end

	local function page_button_rects(screen)
		return {
			prev = Mouse_UI.make_rect(SAFE_LEFT, screen.Y - 24, 56, 16),
			next = Mouse_UI.make_rect(screen.X - SAFE_RIGHT - 56, screen.Y - 24, 56, 16),
			label = Mouse_UI.make_rect(screen.X * 0.5 - 36, screen.Y - 24, 72, 16),
		}
	end

	local function capture_mouse_wheel(session)
		if not session or not Input.GetMouseWheel then return end
		if session.was_paused or Game():IsPaused() then return end
		local ok, wheel = pcall(function() return Input.GetMouseWheel() end)
		if not ok or not wheel then return end
		local dy = tonumber(wheel.Y) or 0
		local dx = tonumber(wheel.X) or 0
		if dx ~= 0 or dy ~= 0 then
			session.wheel_pending = {x = dx, y = dy, serial = session.wheel_render_serial}
		end
	end

	local function try_mouse_wheel_page(session)
		if not session then return end
		if session.was_paused or Game():IsPaused() then return end
		-- 渲染帧率可高于 update；禁止用 Game frame 去重，否则会吞同一 update 帧内的滚轮脉冲。
		local serial = session.wheel_render_serial or 0
		if session.wheel_read_serial == serial then return end
		local wheel = session.wheel_pending
		if not wheel then return end
		session.wheel_pending = nil
		local dy = tonumber(wheel.y) or 0
		local dx = tonumber(wheel.x) or 0
		local delta = dy
		if delta == 0 then delta = dx end
		if delta == 0 then return end
		session.wheel_read_serial = serial
		local notches
		if math.abs(delta) >= 40 then
			notches = delta / 120
			if math.abs(notches) < 1 then notches = delta > 0 and 1 or -1 end
		else
			notches = delta > 0 and 1 or -1
		end
		session.wheel_accum = (session.wheel_accum or 0) + notches
		local steps = 0
		while session.wheel_accum >= 1 do
			session.wheel_accum = session.wheel_accum - 1
			steps = steps - 1
		end
		while session.wheel_accum <= -1 do
			session.wheel_accum = session.wheel_accum + 1
			steps = steps + 1
		end
		if steps ~= 0 then
			change_page(session, steps)
		end
		if page_count() <= 1 then session.wheel_accum = 0 end
	end

	item.capture_thoth_wheel = function()
		local session = Select.get(PANEL_ID)
		if not session or session.was_paused or Game():IsPaused() then return end
		session.wheel_render_serial = (session.wheel_render_serial or 0) + 1
		capture_mouse_wheel(session)
	end

	local function next_empty_slot(draft)
		for i = 1, item.max_formation do
			if draft[i] == nil then return i end
		end
		return nil
	end

	local function toggle_draft_card(session, card_id, bag)
		if not session or not card_id or not bag then return false end
		if formation_active(bag) then return false end
		if not is_face_registered(bag, card_id) then return false end
		local pos = draft_has(session.draft, card_id)
		if pos then
			session.draft[pos] = nil
			return true
		end
		local compact = draft_compact(session.draft)
		if #compact >= item.max_formation then return false end
		local slot = next_empty_slot(session.draft)
		if not slot then return false end
		session.draft[slot] = card_id
		return true
	end

	local function assign_slot(session, slot, card_id, bag)
		if not session or not slot or not card_id or not bag then return false end
		if formation_active(bag) then return false end
		if not is_face_registered(bag, card_id) then return false end
		local existing = draft_has(session.draft, card_id)
		if existing then session.draft[existing] = nil end
		session.draft[slot] = card_id
		return true
	end

	local function try_confirm(session)
		local player = session and session.player
		if not player then return end
		local bag = get_bag(player)
		if not bag or formation_active(bag) then
			Select.close(PANEL_ID)
			return
		end
		local n = #draft_compact(session.draft)
		if n < 1 then
			Select.close(PANEL_ID)
			return
		end
		if not draft_can_confirm(player, session.draft) then
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.55, 1.1, false, 0, 2)
			return
		end
		if apply_draft(player, session.draft) == 1 then
			Select.close(PANEL_ID)
		else
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.55, 1.1, false, 0, 2)
		end
	end

	local function activate(session, bag)
		local id = session.focus_id
		if not id then return end
		if id == "tab_catalog" then
			session.tab = "catalog"
			session.nav_group = "tabs"
			session.pad_carry = nil
			session.drag = nil
			return
		end
		if id == "tab_divine" then
			session.tab = "divine"
			session.nav_group = "tabs"
			return
		end
		if id == "btn_confirm" then
			try_confirm(session)
			return
		end
		if id == "btn_prev" then
			change_page(session, -1)
			return
		end
		if id == "btn_next" then
			change_page(session, 1)
			return
		end
		if id:sub(1, 5) == "slot_" then
			local slot = tonumber(id:sub(6))
			if session.pad_carry and slot then
				assign_slot(session, slot, session.pad_carry, bag)
				session.pad_carry = nil
				Select.lock_actions(session)
				return
			end
			if slot and session.draft[slot] then
				session.draft[slot] = nil
			end
			return
		end
		local card_id = nil
		if id:sub(1, 5) == "card_" then card_id = tonumber(id:sub(6)) end
		if id:sub(1, 5) == "pool_" then card_id = tonumber(id:sub(6)) end
		if not card_id then return end
		if session.tab == "divine" then
			if session.pad_carry == card_id then
				session.pad_carry = nil
			else
				if is_face_registered(bag, card_id) and not formation_active(bag) then
					session.pad_carry = card_id
					session.nav_group = "body"
					session.focus_id = "slot_1"
					session.body_focus_mem = "slot_1"
				end
			end
			return
		end
		toggle_draft_card(session, card_id, bag)
	end

	Select.register({
		id = PANEL_ID,
		own_key = item.own_key,
		item_id = item.entity,
		on_open = function(session)
			session.tab = "catalog"
			session.page = 1
			session.draft = {}
			session.drag = nil
			session.pad_carry = nil
			session.focus_id = "tab_catalog"
			session.nav_group = "tabs"
			session.body_focus_mem = nil
			session.nav_hold = nil
			session.wheel_pending = nil
			session.wheel_accum = 0
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOOK_PAGE_TURN_12, 1, 1, false, 0, 2)
		end,
		on_close = function(session)
			session.draft = nil
			session.drag = nil
			session.pad_carry = nil
		end,
		on_exit = function(session)
			-- ESC/放下：直接关，不自动确认占卜
			return false
		end,
		on_input = function(session, player, can_interact)
			if not can_interact then return end
			local bag = get_bag(player)
			local ctrlid = player.ControllerIndex or 0
			local frame = Game():GetFrameCount()
			local held = get_held_nav_dir(ctrlid)
			local hold = session.nav_hold
			if held then
				if not hold or hold.dir ~= held then
					session.nav_hold = {dir = held, next_fire = frame + item.nav_repeat_initial}
					move_focus(session, held)
				elseif frame >= (hold.next_fire or 0) then
					move_focus(session, held)
					hold.next_fire = frame + item.nav_repeat_interval
				end
			else
				session.nav_hold = nil
			end
			if Select.input_locked(session) then return end
			if Select.activate_triggered(session) then
				activate(session, bag)
				Select.lock_actions(session)
			end
		end,
		on_render = function(session)
			local player = session.player
			if not player then return end
			local bag = get_bag(player)
			if not bag then return end
			try_mouse_wheel_page(session)
			local screen = screen_size()
			local locked = formation_active(bag)
			if locked then
				session.draft = session.draft or {}
				for i = 1, item.max_formation do
					session.draft[i] = bag.formation[i]
				end
			end

			draw_dim()
			Mouse_UI.begin_frame(player)

			local tabs, body = {}, {}
			local tab_w, tab_h = 70, 18
			local tab_catalog = Mouse_UI.make_rect(screen.X * 0.5 - tab_w - 6, 6, tab_w, tab_h)
			local tab_divine = Mouse_UI.make_rect(screen.X * 0.5 + 6, 6, tab_w, tab_h)
			Mouse_UI.register("tab_catalog", tab_catalog, {z = 20})
			Mouse_UI.register("tab_divine", tab_divine, {z = 20})
			nav_add(tabs, "tab_catalog", tab_catalog)
			nav_add(tabs, "tab_divine", tab_divine)

			local layouts = {}
			local page = current_page_units(session)
			local pager = page_button_rects(screen)
			Mouse_UI.register("btn_prev", pager.prev, {z = 20})
			Mouse_UI.register("btn_next", pager.next, {z = 20})
			nav_add(body, "btn_prev", pager.prev)
			nav_add(body, "btn_next", pager.next)
			layouts.btn_prev = {rect = pager.prev}
			layouts.btn_next = {rect = pager.next}
			layouts.page_label = {rect = pager.label}

			if session.tab == "catalog" then
				local lay = catalog_layout(screen, page)
				session._groups = lay.groups
				for _, place in ipairs(lay.placements) do
					local id = "card_"..tostring(place.card_id)
					Mouse_UI.register(id, place.rect, {z = 10})
					nav_add(body, id, place.rect)
					layouts[id] = {rect = place.rect, card_id = place.card_id, scale = place.scale}
				end
			else
				local lay = divine_layout(screen, page)
				session._groups = lay.groups
				session._divine = lay
				for i = 1, item.max_formation do
					local id = "slot_"..tostring(i)
					Mouse_UI.register(id, lay.slots[i], {z = 12, drop_target = true})
					nav_add(body, id, lay.slots[i])
					layouts[id] = {rect = lay.slots[i], slot = i, scale = lay.slot_scale}
				end
				Mouse_UI.register("btn_confirm", lay.confirm, {z = 12})
				nav_add(body, "btn_confirm", lay.confirm)
				layouts.btn_confirm = {rect = lay.confirm}
				for _, place in ipairs(lay.placements) do
					local id = "pool_"..tostring(place.card_id)
					Mouse_UI.register(id, place.rect, {z = 11, draggable = not locked})
					if not session.pad_carry then
						nav_add(body, id, place.rect)
					end
					layouts[id] = {rect = place.rect, card_id = place.card_id, scale = place.scale, pool = true}
				end
				session._divine = lay
			end
			if session.pad_carry then
				local carry = {}
				for i = 1, #body do
					local id = body[i].id
					if type(id) == "string" and id:sub(1, 5) == "slot_" then
						carry[#carry + 1] = body[i]
					end
				end
				if #carry > 0 then body = carry end
			end
			sort_reading(tabs)
			sort_reading(body)
			session._nav_groups = {tabs = tabs, body = body}
			session._layouts = layouts
			snap_focus(session)

			Mouse_UI.end_frame()

			local can_mouse = Select.can_interact(session) and Mouse_UI.mouse_allowed(player) and not Select.input_locked(session)
			if can_mouse then
				local hovered = Mouse_UI.get_hovered_id()
				if hovered then
					session.focus_id = hovered
					if hovered == "tab_catalog" or hovered == "tab_divine" then
						session.nav_group = "tabs"
					else
						session.nav_group = "body"
						session.body_focus_mem = hovered
					end
				end
				if Mouse_UI.is_pressed("tab_catalog") then
					session.tab = "catalog"
					session.nav_group = "tabs"
					session.focus_id = "tab_catalog"
					session.pad_carry = nil
					session.drag = nil
				elseif Mouse_UI.is_pressed("tab_divine") then
					session.tab = "divine"
					session.nav_group = "tabs"
					session.focus_id = "tab_divine"
				elseif Mouse_UI.is_pressed("btn_confirm") then
					try_confirm(session)
				elseif Mouse_UI.is_pressed("btn_prev") then
					change_page(session, -1)
				elseif Mouse_UI.is_pressed("btn_next") then
					change_page(session, 1)
				end
				if session.tab == "divine" and not locked then
					if session.drag then
						if Mouse_UI.was_released(0) then
							local drop = Mouse_UI.drop_target_id or Mouse_UI.get_hovered_id()
							local placed = false
							if drop and type(drop) == "string" and drop:sub(1, 5) == "slot_" then
								placed = assign_slot(session, tonumber(drop:sub(6)), session.drag.card_id, bag)
							end
							if not placed and session.drag.from_slot then
								session.draft[session.drag.from_slot] = session.draft[session.drag.from_slot] or session.drag.card_id
							end
							session.drag = nil
						end
					else
						for id, info in pairs(layouts) do
							if info.pool and info.card_id and Mouse_UI.is_pressed(id) then
								if is_face_registered(bag, info.card_id) then
									session.drag = {
										card_id = info.card_id,
										grab_offset = Mouse_UI.mouse - Mouse_UI.rect_center(info.rect),
									}
									session.focus_id = id
									sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.4, 1, false, 0, 2)
								end
							end
							if info.slot and Mouse_UI.is_pressed(id) and session.draft[info.slot] then
								session.drag = {
									card_id = session.draft[info.slot],
									from_slot = info.slot,
									grab_offset = Mouse_UI.mouse - Mouse_UI.rect_center(info.rect),
								}
								session.draft[info.slot] = nil
							end
						end
					end
				elseif session.tab == "catalog" then
					for id, info in pairs(layouts) do
						if info.card_id and Mouse_UI.is_pressed(id) then
							if toggle_draft_card(session, info.card_id, bag) then
								sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.35, 1, false, 0, 2)
							end
						end
					end
				end
			end

			if not Select.get(PANEL_ID) then return end

			draw_text_in_rect(margin_rect(screen, 26, 12), txt("title").."  "..txt("rev")..": "..tostring(get_revelation(player)).."/"..tostring(item.max_revelation), KColor(0.9, 0.8, 1, 1))
			draw_box(tab_catalog, session.tab == "catalog" or session.focus_id == "tab_catalog")
			draw_box(tab_divine, session.tab == "divine" or session.focus_id == "tab_divine")
			draw_text_in_rect(tab_catalog, txt("tab_catalog"), KColor(1, 1, 1, 1))
			draw_text_in_rect(tab_divine, txt("tab_divine"), KColor(1, 1, 1, 1))
			draw_box(pager.prev, session.focus_id == "btn_prev")
			draw_box(pager.next, session.focus_id == "btn_next")
			draw_text_in_rect(pager.prev, txt("page_prev"), KColor(0.9, 0.9, 1, 1))
			draw_text_in_rect(pager.next, txt("page_next"), KColor(0.9, 0.9, 1, 1))
			draw_text_in_rect(pager.label, tostring(clamp_page(session)).." / "..tostring(page_count()), KColor(0.85, 0.8, 1, 1))
			if locked then
				draw_text_in_rect(Mouse_UI.make_rect(SAFE_LEFT, 38, 140, 12), txt("locked"), KColor(1, 0.45, 0.45, 1), {align = "left"})
			end

			if session.tab == "catalog" then
				for _, group in ipairs(session._groups or {}) do
					draw_box(group, false)
				end
				for id, info in pairs(layouts) do
					if info.card_id then
						local center = Mouse_UI.rect_center(info.rect)
						local in_draft = draft_has(session.draft, info.card_id)
						local unpaid = card_is_unpaid(session.draft, info.card_id, get_revelation(player))
						render_card_front(info.card_id, center, info.scale, bag, unpaid and {color = deficit_color()} or nil)
						if session.focus_id == id then draw_box(info.rect, true) end
						if in_draft then
							draw_text_in_rect(Mouse_UI.make_rect(info.rect.x, info.rect.y + info.rect.h, info.rect.w, 12), tostring(in_draft), unpaid and KColor(1, 0.4, 0.35, 1) or KColor(1, 0.9, 0.4, 1))
						end
					end
				end
				draw_text_in_rect(margin_rect(screen, screen.Y - 40, 12), txt("hint_catalog"), KColor(0.7, 0.8, 1, 0.9))
			else
				local lay = session._divine
				local can_pay = draft_can_confirm(player, session.draft)
				for i = 1, item.max_formation do
					local rect = lay.slots[i]
					local hot = session.focus_id == ("slot_"..tostring(i))
					draw_box(rect, hot)
					local cid = session.draft[i]
					if cid then
						local unpaid = slot_is_unpaid(session.draft, i, get_revelation(player))
						render_card_front(cid, Mouse_UI.rect_center(rect), lay.slot_scale, bag, unpaid and {color = deficit_color()} or nil)
					else
						draw_text_in_rect(rect, tostring(i), KColor(0.6, 0.65, 0.8, 0.8))
					end
				end
				draw_box(lay.confirm, (session.focus_id == "btn_confirm") and can_pay)
				draw_text_in_rect(lay.confirm, txt("confirm"), can_pay and KColor(1, 0.92, 0.55, 1) or KColor(0.45, 0.46, 0.52, 0.75))
				for _, group in ipairs(session._groups or {}) do
					draw_box(group, false)
				end
				for id, info in pairs(layouts) do
					if info.pool and info.card_id then
						local unpaid = card_is_unpaid(session.draft, info.card_id, get_revelation(player))
						if not (session.drag and session.drag.card_id == info.card_id) then
							render_card_front(info.card_id, Mouse_UI.rect_center(info.rect), info.scale, bag, unpaid and {color = deficit_color()} or nil)
						end
						if session.focus_id == id or session.pad_carry == info.card_id then
							draw_box(info.rect, true)
						end
						local mark = draft_has(session.draft, info.card_id)
						if mark then
							draw_text_in_rect(Mouse_UI.make_rect(info.rect.x, info.rect.y + info.rect.h, info.rect.w, 12), tostring(mark), unpaid and KColor(1, 0.4, 0.35, 1) or KColor(1, 0.9, 0.4, 1))
						end
					end
				end
				if session.drag then
					local pos = Mouse_UI.mouse - (session.drag.grab_offset or Vector(0, 0))
					render_card_front(session.drag.card_id, pos, lay.slot_scale, bag, {alpha = 0.95})
				elseif session.pad_carry then
					render_card_front(session.pad_carry, Mouse_UI.rect_center(lay.slots[1]) + Vector(0, -28), 1.4, bag, {alpha = 0.7, no_gold = true})
				end
				draw_text_in_rect(margin_rect(screen, screen.Y - 40, 12), txt("hint_divine"), KColor(0.7, 0.8, 1, 0.9))
			end

			local focus_info = layouts[session.focus_id]
			if focus_info and focus_info.card_id then
				local name = is_face_registered(bag, focus_info.card_id) and card_meta(focus_info.card_id).name or txt("unregistered")
				draw_text_in_rect(margin_rect(screen, 38, 12), name, KColor(0.95, 0.9, 0.75, 1))
			end
		end,
	})
end

-- 滚轮必须在 Render 读取，且单独用极早优先级捕获。
-- 不能只在 on_render 里读：该回调可能已晚于其他模组的鼠标输入，移动鼠标时 RGON/SDL 可丢失同帧滚轮脉冲。
table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_RENDER,
	params = nil,
	priority = -10000,
	Function = function(_)
		if item.capture_thoth_wheel then item.capture_thoth_wheel() end
	end,
})

local function resolve_pending()
	local frame = Game():GetFrameCount()
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		local bag = peek_bag(player)
		if bag and bag.pendingCast and (bag.pendingFrame or 0) < frame then
			local card_id = bag.pendingCast
			bag.pendingCast = nil
			bag.pendingFrame = nil
			if auxi.is_thoth_card(card_id) then
				local ok, d = pcall(function() return player:GetData() end)
				if ok and type(d) == "table" then d[item.own_key.."casting"] = true end
				pcall(function()
					player:UseCard(card_id, UseFlag.USE_NOANNOUNCER | UseFlag.USE_NOANIM)
				end)
				local ok2, d2 = pcall(function() return player:GetData() end)
				if ok2 and type(d2) == "table" then d2[item.own_key.."casting"] = nil end
			end
			if (bag.formationIndex or 1) > #(bag.formation or {}) then
				bag.formation = {}
				bag.formationIndex = 1
			end
		end
	end
end

local function queue_next_formation_card()
	if item.room_cast_done then return end
	item.room_cast_done = true
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		local bag = peek_bag(player)
		if bag and formation_active(bag) and bag.pendingCast == nil then
			local idx = bag.formationIndex or 1
			local card_id = bag.formation[idx]
			bag.formationIndex = idx + 1
			if card_id then
				bag.pendingCast = card_id
				bag.pendingFrame = Game():GetFrameCount()
			end
		end
	end
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_USE_ITEM, params = item.entity,
Function = function(_, coltyp, rng, player, useFlags, activeSlot, customVarData)
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then
		return {Discharge = false, ShowAnim = false}
	end
	Select.scrub(PANEL_ID)
	if Select.is_open(PANEL_ID, player) then
		Select.close(PANEL_ID)
		return {Discharge = false, ShowAnim = false}
	end
	if Select.get(PANEL_ID) then Select.close(PANEL_ID) end
	Select.open(PANEL_ID, player)
	return {Discharge = false, ShowAnim = false}
end,
})

if REPENTOGON and ModCallbacks.MC_PLAYER_GET_ACTIVE_MIN_USABLE_CHARGE then
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PLAYER_GET_ACTIVE_MIN_USABLE_CHARGE, params = item.entity,
	Function = function(_, _, _, _)
		return 0
	end,
	})
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PLAYER_UPDATE, params = nil,
Function = function(_, player)
	sync_charge(player)
end,
})

table.insert(item.post_ToCall, #item.post_ToCall + 1, {CallBack = ModCallbacks.MC_GET_CARD, params = nil,
Function = function(_, rng, card, playing, rune, onlyrune)
	if onlyrune then return end
	if not anyone_holds_book() then return end
	if auxi.is_tarot_card(card) or auxi.is_thoth_card(card) then
		local ret = pick_weighted_thoth(rng)
		if ret then return ret end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = 300,
Function = function(_, ent)
	if not auxi.is_tarot_card(ent.SubType) then return end
	if consistance_holder.try_check_entity(ent, item.own_key.."tarot_map") then return end
	if not anyone_holds_book() then return end
	local ret = pick_weighted_thoth(ent:GetDropRNG())
	if ret then
		local alter = false
		local room = Game():GetRoom()
		local gent = room:GetGridEntityFromPos(ent.Position)
		if gent and gent:GetType() == GridEntityType.GRID_ROCK_ALT2 and gent.State == 2 then
			if not (ent.SpawnerEntity and ent.SpawnerType == 5 and ent.SpawnerVariant == 69) then
				alter = true
			end
		end
		if alter then ent:Morph(5, 300, enums.Cards.Emperor, true, true, true)
		else ent:Morph(5, 300, ret, true, true, true) end
		ent:GetSprite():SetLastFrame()
		consistance_holder.try_hold_entity(ent, item.own_key.."tarot_map", {ignore_subtype = true})
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = item.entity,
Function = function(_, player, collid, cnt, touched)
	local bag = get_bag(player)
	if bag then bag.owned = true end
	sync_charge(player)
	local n_entity = Isaac.GetRoomEntities()
	for _, v in pairs(n_entity) do
		local ent = v:ToPickup()
		if ent and ent.Variant == 300 and auxi.is_tarot_card(ent.SubType) then
			local ret = pick_weighted_thoth(ent:GetDropRNG())
			if ret then
				ent:Morph(5, 300, ret, true, true, true)
				ent:GetSprite():SetLastFrame()
			end
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PLAYER_ADD_CARD, params = nil,
Function = function(_, player, card, slot)
	local ok, d = pcall(function() return player:GetData() end)
	if ok and type(d) == "table" and d[item.own_key.."casting"] then return end
	register_face(player, card)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_USE_CARD, params = nil,
Function = function(_, card, player, useFlags)
	if auxi.is_thoth_card(card) then
		Unlocker.unlock_achievement(save.UnlockData.Others.Thoth, "Unlock", {Achievement_page = "gfx/ui/Some achievements/" .. enums.AchievementGraphics.others.Thoth .. ".png",})
	end
	local ok, d = pcall(function() return player:GetData() end)
	if ok and type(d) == "table" and d[item.own_key.."casting"] then return end
	if useFlags & UseFlag.USE_CARBATTERY == UseFlag.USE_CARBATTERY then return end
	local bag = get_bag(player)
	if not bag or not bag.owned then return end
	if auxi.is_thoth_card(card) then
		add_revelation(player, 1)
		sync_charge(player)
		if auxi.has_have_coll(player, item.entity) and auxi.should_do_belial(player) then
			Book_of_Belial_holder.Add_dmg(player, 2, {counter = 30,})
		end
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_ITEMRECHARGE, 1, 1, false, 0, 2)
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION, params = PickupVariant.PICKUP_LIL_BATTERY,
Function = function(_, pickup, collider, low)
	local player = collider and collider:ToPlayer()
	if not player then return end
	if not auxi.has_have_coll(player, item.entity) then return end
	if other_active_needs_charge(player) then return end
	return true
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function()
	item.room_cast_done = false
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, params = nil,
Function = function()
	queue_next_formation_card()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function()
	resolve_pending()
	local seed = Game():GetSeeds()
	local player = auxi.have_player_has_collectible(item.entity)
	if player and item.is_seija(player) then
		if save.elses[item.own_key.."SeijaBuff"] == nil then
			save.elses[item.own_key.."SeijaBuff"] = seed:HasSeedEffect(SeedEffect.SEED_MYSTERY_TAROT_CARDS)
			seed:AddSeedEffect(SeedEffect.SEED_MYSTERY_TAROT_CARDS)
		end
	elseif save.elses[item.own_key.."SeijaBuff"] ~= nil then
		if save.elses[item.own_key.."SeijaBuff"] == true then seed:AddSeedEffect(SeedEffect.SEED_MYSTERY_TAROT_CARDS) else seed:RemoveSeedEffect(SeedEffect.SEED_MYSTERY_TAROT_CARDS) end
		save.elses[item.own_key.."SeijaBuff"] = nil
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE, params = nil,
Function = function(_, ent)
	if ent.Type == 3 and ent.Variant == FamiliarVariant.WISP and ent.SubType == item.entity then
		Isaac.Spawn(5, 300, 0, ent.Position, ent.Velocity, nil)
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	if not continue then
		save.elses[item.own_key.."data"] = {}
		save.elses[item.own_key.."effect"] = nil
		save.elses[item.own_key.."counter"] = nil
	end
	save.elses[item.own_key.."data"] = save.elses[item.own_key.."data"] or {}
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_SLOT_RENDER, params = "Active",
Function = function(_, player, tp, cid, slot)
	if cid ~= item.entity then return end
	local bag = get_bag(player)
	if not bag then return end
	local list = bag.formation or {}
	local idx = bag.formationIndex or 1
	if #list == 0 or idx > #list then return end
	local info = ui.GetActiveSlotRenderInfo(player, slot)
	local alpha = (info and info.alpha) or 1
	local slot_scale = (info and tonumber(info.scale)) or 1
	-- qing_cardpill_icons Card 层 Pivot=(0,0)：必须用 Offset 左上角，不能用 PlayerActiveUIPos（那是 16,16 中心锚点）。
	card_spr:SetFrame("Card", 0)
	local origin
	if info and info.offset then
		origin = ui.ActiveSlotSpriteRenderPos(player, slot, card_spr, 0)
	else
		origin = ui.PlayerActiveUIPos(player, slot, auxi.GetPlayerOrder(player), cid) - Vector(16 * slot_scale, 16 * slot_scale)
	end
	local icon_scale = 0.55 * slot_scale
	local step = 12 * slot_scale
	local drawn = 0
	for i = idx, #list do
		local card_id = list[i]
		local tpos = origin + Vector(drawn * step, 0)
		local col = Color(1, 1, 1, alpha)
		if i == idx and col.SetColorize then col:SetColorize(1.05, 0.8, 0.2, 1) end
		render_card_icon(card_id, tpos, icon_scale, col, true)
		drawn = drawn + 1
		if i < #list then
			gui.draw_ch(tpos + Vector(step * 0.55, 3 * slot_scale), ">", 1, 1, KColor(0.85, 0.75, 1, alpha), true)
		end
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_CLEAR_SAVE, params = nil,
Function = function(_, Data, Minder)
	Minder[item.own_key.."SeijaBuff"] = Data[item.own_key.."SeijaBuff"]
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_INHERIT_SAVE, params = nil,
Function = function(_, Minder, Data)
	if Minder[item.own_key.."SeijaBuff"] == false then Game():GetSeeds():RemoveSeedEffect(SeedEffect.SEED_MYSTERY_TAROT_CARDS) end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_DESCRIPT_ITEM, params = nil,
Function = function(_, player, tp, id, value)
	if player and item.is_seija(player) and auxi.has_have_coll(player, item.entity) and tp == "Card" and auxi.is_thoth_card(id) then
		return item.Seija_desc[Options.Language] or item.Seija_desc["en"]
	end
end,
})

if EID then

EID:addDescriptionModifier("qing_item_sync"..tostring(item.entity), function(desc) return true end, function(desc)
	local id = desc.ObjType
	local vr = desc.ObjVariant
	local st = desc.ObjSubType
	if id == 5 and vr == 100 and st == item.entity then
		local player = auxi.have_player_has_collectible(item.entity)
		local bag = player and get_bag(player)
		if bag and formation_active(bag) then
			local names = {}
			for i = 1, #(bag.formation or {}) do
				local mark = ""
				if i < (bag.formationIndex or 1) then mark = is_zh() and "(已发动)" or "(spent)"
				elseif i == (bag.formationIndex or 1) then mark = is_zh() and "(下一张)" or "(next)"
				end
				names[#names + 1] = card_meta(bag.formation[i]).name..mark
			end
			local info = is_zh() and ("#当前牌阵："..table.concat(names, " → ")) or ("#Current spread: "..table.concat(names, " -> "))
			EID:appendToDescription(desc, info)
		end
	end
	if id == 5 and vr == 300 then
		local player = auxi.have_player_has_collectible(item.entity)
		if player and item.is_seija(player) and auxi.is_thoth_card(st) then
			if auxi.check_all_exists(desc.Entity) then desc.Description = "QuestionMark"
			else
				desc.Description = "" desc.Name = "???" desc.Icon[1] = "pickups"
				if auxi.is_reversed_card(st) then desc.Icon[2] = 1
				else desc.Icon[2] = 0 end
				desc.Icon[7] = cdsprite2
			end
		end
	end
	return desc
end)

end

return item
