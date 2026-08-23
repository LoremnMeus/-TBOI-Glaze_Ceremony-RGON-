local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local Unlocker = require("Qing_Remaster_scripts.core.unlock_manager")
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
	init_revelation = 3,
	register_revelation = 1,
	use_revelation = 2,
	base_formation = 3,
	max_formation = 4,
	formation_cost = 3,
	nav_repeat_initial = 22,
	nav_repeat_interval = 6,
	seen_weight = 1,
	unseen_weight = 3,
	tarot_replace_cap = 0.5,
	shuffle_fly_in = 12,
	shuffle_flip = 10,
	shuffle_fly_out = 12,
	shuffle_stagger = 3,
	open_rise_dur = 14,
	open_rise_distance = 72,
	hover_scale = 1.12,
	hud_orbit_speed = 0.012,
	hud_orbit_rx = 13,
	hud_orbit_ry = 10,
	cast_flip_dur = 10,
	cast_flip_hold = 8,
	cast_fly_dur = 14,
	cast_fly_hold = 8,
	cast_lift_min = 16,
	cast_lift_max = 42,
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
back_spr:Load("gfx/ui/EID/qing_cardpill_icons.anm2", true)
local cdsprite2 = Sprite()
cdsprite2:Load("gfx/ui/EID/qing_cardpill_icons.anm2", true)
local rev_back_spr = Sprite()
rev_back_spr:Load("gfx/ui/content/ui_cardfronts.anm2", true)
local holo_spr = Sprite()
local holo_loaded = false
local cloth_cache_frame = -1
local cloth_cache_held = false

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

-- 卡册内缩仍按 HUD 安全区写死。ImGui 只放开主动槽卡面和圣杯热区。
local LAYOUT_IMGUI_KEYS = {
	HudCardScale = true,
	HudCardOffsetX = true,
	HudCardOffsetY = true,
	CupHitOffsetX = true,
	CupHitOffsetY = true,
	CupHitW = true,
	CupHitH = true,
}

item.layout_defaults = {
	DivineSplit = 0.4,
	DotOffsetX = 0,
	DotOffsetY = -11,
	BgOffsetX = 0,
	BgOffsetY = 0,
	TabCatalogTextX = -31.2,
	TabCatalogTextY = -6.4,
	TabDivineTextX = -32.2,
	TabDivineTextY = -7.0,
	SlotCardScale = 1.0,
	SlotCardOffsetX = 1,
	SlotCardOffsetY = -8,
	HudCardScale = 0.5,
	HudCardOffsetX = 0,
	HudCardOffsetY = 0,
	PoolOffsetY = -15,
	PageLabelOffsetX = 0,
	PageLabelOffsetYCatalog = -26,
	PageLabelOffsetYDivine = -21,
	-- 圣杯图层是整条 448×96 横幅，热区单独缩小到杯身。
	CupHitOffsetX = 0,
	CupHitOffsetY = 1,
	CupHitW = 44,
	CupHitH = 66,
}

function item.get_layout()
	local debug = debug_root() or {}
	local defaults = item.layout_defaults
	local function n(key, lo, hi)
		local value = defaults[key]
		if LAYOUT_IMGUI_KEYS[key] then
			local over = tonumber(debug["BookOfThoth"..key])
			if over ~= nil then value = over end
		end
		if value == nil then value = 0 end
		if lo and value < lo then value = lo end
		if hi and value > hi then value = hi end
		return value
	end
	return {
		divine_split = n("DivineSplit", 0.2, 0.8),
		dot_x = n("DotOffsetX"),
		dot_y = n("DotOffsetY"),
		bg_x = n("BgOffsetX"),
		bg_y = n("BgOffsetY"),
		tab_catalog_text_x = n("TabCatalogTextX"),
		tab_catalog_text_y = n("TabCatalogTextY"),
		tab_divine_text_x = n("TabDivineTextX"),
		tab_divine_text_y = n("TabDivineTextY"),
		slot_card_scale = n("SlotCardScale", 0.4, 2.4),
		slot_card_x = n("SlotCardOffsetX"),
		slot_card_y = n("SlotCardOffsetY"),
		hud_card_scale = n("HudCardScale", 0.2, 1.2),
		hud_card_x = n("HudCardOffsetX"),
		hud_card_y = n("HudCardOffsetY"),
		pool_y = n("PoolOffsetY"),
		page_label_x = n("PageLabelOffsetX"),
		page_label_y_catalog = n("PageLabelOffsetYCatalog"),
		page_label_y_divine = n("PageLabelOffsetYDivine"),
		cup_hit_x = n("CupHitOffsetX"),
		cup_hit_y = n("CupHitOffsetY"),
		cup_hit_w = n("CupHitW", 16, 448),
		cup_hit_h = n("CupHitH", 16, 96),
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

local function seija_hides_thoth_cards()
	local player = auxi.have_player_has_collectible(item.entity)
	return player ~= nil and item.is_seija(player)
end

function item.is_belial(player)
	return player and auxi.should_do_belial(player) == true
end

function item.slot_count(player)
	if item.is_belial(player) then return item.max_formation or 4 end
	return item.base_formation or 3
end

local function txt(key)
	local zh = {
		title = "透特之书",
		tab_catalog = "卡册",
		tab_divine = "占卜",
		rev = "启示",
		locked = "当前解读尚未结束",
		empty = "???",
		spent = "已发动",
		used_floor = "本层已解读",
		unregistered = "尚未收录",
		hidden = "未揭示",
		cup_cost = "消耗3格启示以占卜",
		no_rev = "启示不足",
		up_face = "正位",
		rev_face = "逆位",
		pending = "尚未翻开",
	}
	local en = {
		title = "Book of Thoth",
		tab_catalog = "Codex",
		tab_divine = "Reading",
		rev = "Revelation",
		locked = "This reading is not finished",
		empty = "???",
		spent = "Spent",
		used_floor = "Read this floor",
		unregistered = "Unregistered",
		hidden = "Unrevealed",
		cup_cost = "Spend 3 Revelation to read",
		no_rev = "Not enough Revelation",
		up_face = "Upright",
		rev_face = "Reversed",
		pending = "Still face-down",
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
	bag.usedThisFloor = bag.usedThisFloor or {}
	bag.triggeredRooms = bag.triggeredRooms or {}
	bag.playedInSpread = bag.playedInSpread or {}
	bag.seijaPending = bag.seijaPending or {}
	if bag.seijaRevealed ~= true then bag.seijaRevealed = false end
	bag.revelation = math.max(0, math.min(item.max_revelation, tonumber(bag.revelation) or 0))
	local legacy_idx = math.floor(tonumber(bag.formationIndex) or 1)
	if legacy_idx > 1 and #bag.formation > 0 then
		local rest = {}
		for i = legacy_idx, #bag.formation do
			rest[#rest + 1] = bag.formation[i]
		end
		bag.formation = rest
	end
	bag.formationIndex = nil
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
			usedThisFloor = {},
			triggeredRooms = {},
			playedInSpread = {},
			seijaPending = {},
			seijaRevealed = false,
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

local function is_face_pending(bag, card_id)
	if not bag or not card_id then return false end
	local list = bag.seijaPending or {}
	for i = 1, #list do
		if list[i] == card_id then return true end
	end
	return false
end

local function queue_seija_pending(bag, card_id)
	if not bag or not card_id then return false end
	if is_face_registered(bag, card_id) or is_face_pending(bag, card_id) then return false end
	bag.seijaPending = bag.seijaPending or {}
	bag.seijaPending[#bag.seijaPending + 1] = card_id
	return true
end

local function reveal_seija_pending(bag)
	if not bag then return end
	bag.seijaPending = bag.seijaPending or {}
	for i = 1, #bag.seijaPending do
		local id = bag.seijaPending[i]
		if id then bag.registered[tostring(id)] = true end
	end
	bag.seijaPending = {}
	bag.seijaRevealed = true
end

local grant_revelation

local function register_face(player, card_id)
	local bag = get_bag(player)
	if not bag or not bag.owned then return false end
	if not auxi.is_thoth_card(card_id) then return false end
	if is_face_registered(bag, card_id) then return false end
	local recorded = false
	if item.is_seija(player) and bag.seijaRevealed ~= true then
		recorded = queue_seija_pending(bag, card_id)
	elseif not is_face_pending(bag, card_id) then
		bag.registered[tostring(card_id)] = true
		recorded = true
	end
	if recorded then
		grant_revelation(player, item.register_revelation, true)
	end
	return recorded
end

local function register_held_thoth_cards(player)
	if not player then return end
	for slot = 0, 3 do
		register_face(player, player:GetCard(slot))
	end
end

local function is_face_used_this_floor(bag, card_id)
	if not bag or not card_id then return false end
	bag.usedThisFloor = bag.usedThisFloor or {}
	return bag.usedThisFloor[tostring(card_id)] == true
end

local function mark_face_used_this_floor(bag, card_id)
	if not bag or not card_id then return end
	bag.usedThisFloor = bag.usedThisFloor or {}
	bag.usedThisFloor[tostring(card_id)] = true
end

local function is_face_selectable(bag, card_id)
	if is_face_used_this_floor(bag, card_id) then return false end
	return is_face_registered(bag, card_id) or is_face_pending(bag, card_id)
end

local function is_played_in_spread(bag, card_id)
	if not bag or not card_id then return false end
	bag.playedInSpread = bag.playedInSpread or {}
	return bag.playedInSpread[tostring(card_id)] == true
end

local function mark_played_in_spread(bag, card_id)
	if not bag or not card_id then return end
	bag.playedInSpread = bag.playedInSpread or {}
	bag.playedInSpread[tostring(card_id)] = true
end

local function unrevealed_indices(bag)
	local idx = {}
	if not bag then return idx end
	local list = bag.formation or {}
	for i = 1, #list do
		if list[i] and not is_played_in_spread(bag, list[i]) then
			idx[#idx + 1] = i
		end
	end
	return idx
end

local function formation_active(bag)
	if not bag then return false end
	return #unrevealed_indices(bag) > 0
end

-- debug 8 / DebugFlag.INFINITE_ITEM_CHARGES：原版永远满充。
-- 启示是自管格数，引擎不会自动补，必须自己认这个 flag。
local INFINITE_ITEM_CHARGES = (DebugFlag and DebugFlag.INFINITE_ITEM_CHARGES) or (1 << 7)

local function debug_infinite_revelation()
	local game = Game()
	if not game or not game.GetDebugFlags then return false end
	return (game:GetDebugFlags() & INFINITE_ITEM_CHARGES) ~= 0
end

local function stored_revelation(player)
	local bag = get_bag(player)
	if not bag then return 0 end
	return bag.revelation or 0
end

local function get_revelation(player)
	if debug_infinite_revelation() then
		return item.max_revelation
	end
	return stored_revelation(player)
end

local function set_revelation(player, value)
	local bag = get_bag(player)
	if not bag then return 0 end
	bag.revelation = math.max(0, math.min(item.max_revelation, math.floor(tonumber(value) or 0)))
	return get_revelation(player)
end

local function add_revelation(player, amount)
	return set_revelation(player, stored_revelation(player) + (amount or 1))
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

grant_revelation = function(player, amount, play_sfx)
	local before = stored_revelation(player)
	local after = add_revelation(player, amount)
	sync_charge(player)
	if play_sfx and after > before then
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_ITEMRECHARGE, 1, 1, false, 0, 2)
	end
	return after
end

local function ensure_owned(player)
	if not player or not auxi.has_have_coll(player, item.entity) then return end
	local bag = get_bag(player)
	if not bag or bag.owned == true then return end
	bag.owned = true
	set_revelation(player, item.init_revelation)
	register_held_thoth_cards(player)
	sync_charge(player)
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

-- Tab 背包走 GetIconStringByDescriptionObject：Icon 若是 table，会忽略表内容、拼成 {{CardSubtype}}。
-- 隐藏期间把 Card{id} 内联图标换成透特牌背，{{CardN}} 就不会漏真卡。
local seija_eid_icon_backup = nil
local seija_eid_icons_hidden = false

local function sync_seija_eid_card_icons()
	if not EID or not EID.InlineIcons or not EID.addIcon then return end
	local hide = seija_hides_thoth_cards()
	if hide == seija_eid_icons_hidden then return end
	if hide then
		seija_eid_icon_backup = seija_eid_icon_backup or {}
		for _, id in ipairs(list_thoth_cards()) do
			local key = "Card"..tostring(id)
			if seija_eid_icon_backup[key] == nil then
				local orig = EID.InlineIcons[key]
				seija_eid_icon_backup[key] = orig == nil and false or orig
			end
			local reversed = auxi.is_reversed_card(id)
			EID:addIcon(key, "pickups", reversed and 1 or 0, 12, 11, 0, -1, cdsprite2)
		end
		seija_eid_icons_hidden = true
	else
		if seija_eid_icon_backup then
			for key, ic in pairs(seija_eid_icon_backup) do
				EID.InlineIcons[key] = ic ~= false and ic or nil
			end
		end
		seija_eid_icons_hidden = false
	end
end

function item.debug_unlock_all_faces()
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player then
			local bag = get_bag(player)
			if bag then
				bag.owned = true
				bag.seijaPending = {}
				bag.seijaRevealed = true
				for _, card_id in ipairs(list_thoth_cards()) do
					if auxi.is_thoth_card(card_id) then
						bag.registered[tostring(card_id)] = true
					end
				end
			end
		end
	end
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

local function count_unseen_thoth()
	local unseen, total = 0, 0
	for _, card_id in ipairs(list_thoth_cards()) do
		if Card_All.get_card_appear_rate(card_id) > 0 then
			total = total + 1
			if is_face_unseen(card_id) then unseen = unseen + 1 end
		end
	end
	return unseen, total
end

local function tarot_replace_chance()
	local unseen, total = count_unseen_thoth()
	if total <= 0 or unseen <= 0 then return 0 end
	local p = unseen / total
	local cap = item.tarot_replace_cap or 0.5
	if p > cap then p = cap end
	return p
end

local function shuffle_inplace(list, rng)
	if type(list) ~= "table" or #list < 2 then return list end
	rng = auxi.rng_for_sake(rng)
	for i = #list, 2, -1 do
		local j = rng:RandomInt(i) + 1
		list[i], list[j] = list[j], list[i]
	end
	return list
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

local function clear_sprite_color(spr)
	if not spr then return end
	local col = Color(1, 1, 1, 1)
	if col.SetColorize then col:SetColorize(0, 0, 0, 0) end
	spr.Color = col
end

local function ensure_holo_spr()
	if holo_loaded then return true end
	local ok = pcall(function()
		holo_spr:Load("gfx/ui/card/thoth_holo_overlay.anm2", true)
		holo_spr:Play("Idle", true)
	end)
	holo_loaded = ok == true
	return holo_loaded
end

local function player_has_tarot_cloth()
	local frame = Game():GetFrameCount()
	if cloth_cache_frame == frame then return cloth_cache_held end
	cloth_cache_frame = frame
	cloth_cache_held = false
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if p and auxi.has_have_coll(p, CollectibleType.COLLECTIBLE_TAROT_CLOTH) then
			cloth_cache_held = true
			break
		end
	end
	return cloth_cache_held
end

-- 原版 AnimRenderFlags 没有桌布全息。旧青模组用 lootcard_fronts 叠 holo_overlay.png。
local function render_tarot_cloth_overlay(pos, scale, opts)
	if not pos or not player_has_tarot_cloth() then return end
	if not ensure_holo_spr() then return end
	opts = opts or {}
	scale = scale or 1
	local sx = opts.scale_x
	if sx == nil then sx = 1 end
	if sx < 0 then sx = -sx end
	holo_spr.Color = Color(1, 1, 1, opts.alpha or 1)
	holo_spr.Scale = Vector(scale * sx, scale)
	holo_spr.Rotation = opts.rotation or 0
	-- 16×24、轴心 (8,12) 即几何中心，pos 已是卡面中心。
	holo_spr:Render(pos, Vector(0, 0), Vector(0, 0))
	holo_spr.Scale = Vector(1, 1)
	holo_spr.Rotation = 0
	clear_sprite_color(holo_spr)
end

local function tick_holo_spr()
	if ensure_holo_spr() and holo_spr.Update then
		holo_spr:Update()
	end
end

local function current_room_key()
	local level = Game():GetLevel()
	local desc = level and level:GetCurrentRoomDesc()
	if not desc then return nil end
	return tostring(level:GetStage())..":"..tostring(level:GetStageType())..":"..tostring(desc.ListIndex)
end

local function is_uncleared_combat_room()
	local room = Game():GetRoom()
	if not room or room:IsClear() then return false end
	local tp = room:GetType()
	return tp == RoomType.ROOM_DEFAULT
		or tp == RoomType.ROOM_BOSS
		or tp == RoomType.ROOM_MINIBOSS
		or tp == RoomType.ROOM_CHALLENGE
		or tp == RoomType.ROOM_BOSSRUSH
end

local function mark_room_triggered(bag, key)
	if not bag or not key then return end
	bag.triggeredRooms = bag.triggeredRooms or {}
	bag.triggeredRooms[key] = true
end

local function room_already_triggered(bag, key)
	if not bag or not key then return true end
	bag.triggeredRooms = bag.triggeredRooms or {}
	return bag.triggeredRooms[key] == true
end

local function draft_can_confirm(player, draft)
	local n = #draft_compact(draft)
	local cap = item.slot_count(player)
	if n < 1 or n > cap then return false end
	return get_revelation(player) >= item.formation_cost
end

local function draft_has(draft, card_id)
	if type(draft) ~= "table" then return nil end
	for i = 1, item.max_formation do
		if draft[i] == card_id then return i end
	end
	return nil
end

local function apply_draft(player, draft)
	local bag = get_bag(player)
	if not bag then return -1 end
	if formation_active(bag) then return -1 end
	local copy = draft_compact(draft)
	if #copy < 1 then return 0 end
	if #copy > item.slot_count(player) then return -1 end
	if get_revelation(player) < item.formation_cost then return -1 end
	local seen = {}
	for i = 1, #copy do
		local id = copy[i]
		if not is_face_selectable(bag, id) then return -1 end
		if seen[id] then return -1 end
		seen[id] = true
	end
	if not debug_infinite_revelation() then
		set_revelation(player, stored_revelation(player) - item.formation_cost)
	end
	reveal_seija_pending(bag)
	bag.formation = copy
	bag.playedInSpread = {}
	local rng = player:GetCollectibleRNG(item.entity)
	shuffle_inplace(bag.formation, rng)
	if is_uncleared_combat_room() then
		mark_room_triggered(bag, current_room_key())
	end
	sync_charge(player)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOOK_PAGE_TURN_12, 1, 1, false, 0, 2)
	return 1
end

local HUD_OUTLINE_OFFS = {
	Vector(-1, 0), Vector(1, 0), Vector(0, -1), Vector(0, 1),
	Vector(-1, -1), Vector(1, -1), Vector(-1, 1), Vector(1, 1),
}

local TAU = math.pi * 2
local hud_orbits = {}
local hud_spin = {}
local hud_spin_frame = {}
local hud_last_pos = {}
local last_hud_scale = {}
local cast_anims = {}

local function hud_ready_outline_color(alpha)
	-- 原版可用主动：Tint 黑 + Offset 白 = 实心白剪影，再叠在卡面底下。
	local pulse = 0.62 + 0.38 * (0.5 + 0.5 * math.sin(Game():GetFrameCount() * 0.14))
	local col = Color(0, 0, 0, (alpha or 1) * pulse, 1, 1, 1)
	if col.SetColorize then col:SetColorize(0, 0, 0, 0) end
	return col
end

local function card_hud_anim(card_id)
	local cfg = Isaac.GetItemConfig():GetCard(card_id)
	if not cfg then return "ThothBack" end
	local hud = cfg.HudAnim
	if (not hud or hud == "") and cfg.GetHudAnim then
		hud = cfg:GetHudAnim()
	end
	if hud and hud ~= "" then return hud end
	return "ThothBack"
end

local function sprite_center_shift(spr, scale)
	scale = scale or 1
	local frame = spr.GetLayerFrameData and spr:GetLayerFrameData(0)
	if frame and frame.GetPivot and frame.GetWidth and frame.GetHeight then
		local pivot = frame:GetPivot()
		local w, h = frame:GetWidth(), frame:GetHeight()
		if pivot and w and h and w > 0 and h > 0 then
			return Vector((pivot.X - w * 0.5) * scale, (pivot.Y - h * 0.5) * scale)
		end
	end
	return Vector(0, 2 * scale)
end

-- pos 是卡面几何中心。正反面都走 ui_cardfronts（16x20），禁止混用 EID 9x16 图标。
local function render_card_icon(card_id, pos, scale, col, face_up, opts)
	opts = opts or {}
	scale = scale or 1
	local sx = opts.scale_x
	if sx == nil then sx = 1 end
	if sx < 0 then sx = -sx end
	col = col or Color(1, 1, 1, 1)
	local anim = "ThothBack"
	if face_up then
		anim = card_hud_anim(card_id)
	elseif opts.reverse_back then
		anim = "ThothBack r"
	end
	rev_back_spr.Color = col
	rev_back_spr.Scale = Vector(scale * sx, scale)
	rev_back_spr.Rotation = opts.rotation or 0
	local ok = pcall(function()
		rev_back_spr:SetFrame(anim, 0)
	end)
	if not ok then
		rev_back_spr:SetFrame("ThothBack", 0)
	end
	rev_back_spr:Render(pos + sprite_center_shift(rev_back_spr, scale), Vector(0, 0), Vector(0, 0))
	rev_back_spr.Scale = Vector(1, 1)
	rev_back_spr.Rotation = 0
	clear_sprite_color(rev_back_spr)
	if face_up and opts.cloth ~= false then
		render_tarot_cloth_overlay(pos, scale, {
			scale_x = sx,
			alpha = col.A or 1,
			rotation = opts.rotation or 0,
		})
	end
end

local function wrap_angle(a)
	local t = a / TAU
	return (t - math.floor(t)) * TAU
end

local function lerp_angle(a, b, t)
	local d = wrap_angle(b - a)
	if d > math.pi then d = d - TAU end
	return a + d * math.max(0, math.min(1, t))
end

local function orbit_target(i, n, spin)
	if n <= 0 then return spin or 0 end
	return (spin or 0) + (i - 1) * (TAU / n) - math.pi * 0.5
end

local function player_hold_screen_pos(player)
	if not player then return Vector(0, 0) end
	local pos = player.Position
	if player.PositionOffset then
		pos = pos + player.PositionOffset
	end
	return Isaac.WorldToScreen(pos) + Vector(0, -26)
end

local function get_cast_anim(player)
	local idx = player_index(player)
	if idx == nil then return nil, nil end
	return cast_anims[idx], idx
end

local function hud_orbit_cards(bag, anim)
	local out = {}
	if not bag then return out end
	local flying = anim and (anim.phase == "fly" or anim.phase == "arrive" or anim.phase == "lift" or anim.phase == "fire")
	for i = 1, #(bag.formation or {}) do
		local id = bag.formation[i]
		if id then
			local leave = flying and anim.card_id == id
			if not leave and not is_played_in_spread(bag, id) then
				out[#out + 1] = {id = id, index = i}
			end
		end
	end
	return out
end

local function ease_smooth_hud(t)
	if t < 0 then return 0 end
	if t > 1 then return 1 end
	return t * t * (3 - 2 * t)
end

local function fire_formation_card(player, bag, card_id)
	if not player or not bag or not card_id then return false end
	local used_ok = false
	if auxi.is_thoth_card(card_id) then
		local ok, d = pcall(function() return player:GetData() end)
		if ok and type(d) == "table" then d[item.own_key.."casting"] = true end
		local fire_ok = pcall(function()
			player:UseCard(card_id, UseFlag.USE_NOANNOUNCER | UseFlag.USE_NOANIM)
		end)
		local ok2, d2 = pcall(function() return player:GetData() end)
		if ok2 and type(d2) == "table" then d2[item.own_key.."casting"] = nil end
		used_ok = fire_ok == true
	end
	if used_ok then
		mark_played_in_spread(bag, card_id)
		mark_face_used_this_floor(bag, card_id)
		if #unrevealed_indices(bag) == 0 then
			bag.formation = {}
			bag.playedInSpread = {}
		end
	end
	bag.pendingCast = nil
	bag.pendingFrame = nil
	bag.pendingIndex = nil
	return used_ok
end

local function begin_cast_anim(player, bag, card_id, form_index)
	local idx = player_index(player)
	if idx == nil then return end
	cast_anims[idx] = {
		phase = "flip",
		t0 = Game():GetFrameCount(),
		card_id = card_id,
		form_index = form_index,
		from = nil,
		lifted = false,
	}
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.7, 1, false, 0, 2)
end

local function tick_cast_anim(player)
	local bag = peek_bag(player)
	local anim, idx = get_cast_anim(player)
	if not bag then
		if idx ~= nil then cast_anims[idx] = nil end
		return
	end
	if not anim then
		if bag.pendingCast then
			begin_cast_anim(player, bag, bag.pendingCast, bag.pendingIndex)
			anim, idx = get_cast_anim(player)
		else
			return
		end
	end
	if not anim then return end
	if Game():IsPaused() then return end
	local now = Game():GetFrameCount()
	local flip_dur = item.cast_flip_dur or 10
	local flip_hold = item.cast_flip_hold or 8
	local fly_dur = item.cast_fly_dur or 14
	local fly_hold = item.cast_fly_hold or 8
	local elapsed = now - (anim.t0 or now)
	if anim.phase == "flip" then
		if elapsed >= flip_dur then
			anim.phase = "reveal"
			anim.t0 = now
		end
		return
	end
	if anim.phase == "reveal" then
		if elapsed >= flip_hold then
			anim.phase = "fly"
			anim.t0 = now
			local last = hud_last_pos[idx]
			if last and last[anim.card_id] then
				anim.from = Vector(last[anim.card_id].X, last[anim.card_id].Y)
			end
		end
		return
	end
	if anim.phase == "fly" then
		if not anim.from then
			local last = hud_last_pos[idx]
			if last and last[anim.card_id] then
				anim.from = Vector(last[anim.card_id].X, last[anim.card_id].Y)
			end
		end
		if elapsed >= fly_dur then
			anim.phase = "arrive"
			anim.t0 = now
		end
		return
	end
	if anim.phase == "arrive" then
		if elapsed >= fly_hold then
			anim.phase = "lift"
			anim.t0 = now
			anim.lifted = false
		end
		return
	end
	if anim.phase == "lift" then
		if not anim.lifted then
			local can = false
			pcall(function()
				can = player:Exists() == true and player:IsDead() ~= true
			end)
			if can then
				pcall(function()
					player:AnimateCard(anim.card_id, "UseItem")
				end)
				anim.lifted = true
			else
				anim.phase = "fire"
				return
			end
		end
		local min_d = item.cast_lift_min or 16
		local max_d = item.cast_lift_max or 42
		local holding = false
		pcall(function() holding = player:IsHoldingItem() == true end)
		if elapsed >= max_d or (elapsed >= min_d and not holding) then
			anim.phase = "fire"
		end
		return
	end
	if anim.phase == "fire" then
		fire_formation_card(player, bag, anim.card_id)
		if idx ~= nil then cast_anims[idx] = nil end
	end
end

local function render_cast_overlay(player, alpha, hud_scale)
	local anim, idx = get_cast_anim(player)
	if not anim or (anim.phase ~= "fly" and anim.phase ~= "arrive") then return end
	local dest = player_hold_screen_pos(player)
	local from = anim.from or dest
	local fly_dur = math.max(1, item.cast_fly_dur or 14)
	local u = 1
	if anim.phase == "fly" then
		u = ease_smooth_hud((Game():GetFrameCount() - (anim.t0 or 0)) / fly_dur)
	end
	local pos = Vector(from.X + (dest.X - from.X) * u, from.Y + (dest.Y - from.Y) * u)
	local scale = (hud_scale or 1) * (1 + 0.7 * u)
	local col = Color(1, 1, 1, alpha or 1)
	render_card_icon(anim.card_id, pos, scale, col, true, {scale_x = 1})
	if idx ~= nil then
		hud_last_pos[idx] = hud_last_pos[idx] or {}
		hud_last_pos[idx][anim.card_id] = pos
	end
end

local function init_thoth_panel()
	local CARD_W, CARD_H = 16, 20
	local dim_spr = Sprite()
	dim_spr:Load("gfx/Black.anm2", true)
	dim_spr:Play("Idle", true)
	local book_spr = Sprite()
	book_spr:Load("gfx/mimics/Thoth/ThothBook.anm2", true)
	local BOOK_LAYER_MAIN = 0
	local BOOK_LAYER_P1 = 1
	local BOOK_LAYER_P2 = 2
	local BOOK_LAYER_PAGE_LEFT = 3
	local BOOK_LAYER_PAGE_RIGHT = 4
	local BOOK_LAYER_BACK = 5
	local BOOK_LAYER_FLAMES = 6
	local BOOK_LAYER_CUP = 7
	local BOOK_LAYER_CUP_FLAME = 8
	-- 与 ThothBook.anm2 Idle 一致：存 origin 相对左上角（Pos - Pivot）
	local BOOK_LAYER_FALLBACK = {
		[1] = {x = -147, y = -133, w = 128, h = 32},
		[2] = {x = 54, y = -134, w = 128, h = 32},
		[3] = {x = -238, y = 73, w = 96, h = 64},
		[4] = {x = 152, y = 68, w = 96, h = 64},
		[5] = {x = -224, y = -80, w = 448, h = 96},
		[7] = {x = -224, y = -112, w = 448, h = 96},
	}
	-- Flames：默认用第 0/1/2 帧（中/右/左）。彼列四槽用 1/2/3/4，去掉第 0 帧。
	local FLAME_SLOT_FALLBACK = {
		{pos = Vector(-110, -35), pivot = Vector(32, 32), w = 64, h = 64},
		{pos = Vector(0, -8), pivot = Vector(32, 32), w = 64, h = 64},
		{pos = Vector(110, -35), pivot = Vector(32, 32), w = 64, h = 64},
	}
	local FLAME_SLOT_FALLBACK_BELIAL = {
		{pos = Vector(-110, -35), pivot = Vector(32, 32), w = 64, h = 64},
		{pos = Vector(-40, -12), pivot = Vector(32, 32), w = 64, h = 64},
		{pos = Vector(40, -12), pivot = Vector(32, 32), w = 64, h = 64},
		{pos = Vector(110, -35), pivot = Vector(32, 32), w = 64, h = 64},
	}
	local CUP_FLAME_FALLBACK = Vector(0, -84)
	local FLAME_ANM2 = "gfx/mimics/Iliaster/granel_flame.anm2"
	local FLAME_SHEET_UP = "gfx/effects/flames/flame3.png"
	local FLAME_SHEET_REV = "gfx/effects/flames/flame4.png"
	local FLAME_GROW_FRAMES = 8
	local CUP_FLASH_FRAMES = 20
	local slot_flame_spr = {Sprite(), Sprite(), Sprite(), Sprite()}
	local slot_flame_sheet = {}
	local cup_flame_spr = Sprite()
	local cup_flame_sheet = nil
	local flame_upd_frame = -1
	for i = 1, item.max_formation do
		slot_flame_spr[i]:Load(FLAME_ANM2, true)
	end
	cup_flame_spr:Load(FLAME_ANM2, true)
	local front_spr = Sprite()
	local front_path, front_hud, front_card = nil, nil, nil
	local catalog_units = nil
	local catalog_pages = nil
	local catalog_pages_span = nil
	local ui_alpha = 1
	local ui_rise = 0
	local PAIR_GAP = 6
	local GROUP_PAD = 8
	local INNER_GAP = 8
	local BAND_GAP = 10
	local MIN_SCALE = 1.0
	local MAX_SCALE_CATALOG = 2.2
	local MAX_SCALE_DIVINE = 2.2
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

	local function pending_units(bag)
		local out = {}
		if not bag then return out end
		for i = 1, #(bag.seijaPending or {}) do
			local id = bag.seijaPending[i]
			if valid_card(id) then
				out[#out + 1] = {kind = "pending", card = id}
			end
		end
		return out
	end

	local function merge_pending_page(page, bag)
		local extra = pending_units(bag)
		if #extra == 0 then return page end
		local merged = {}
		for i = 1, #extra do merged[i] = extra[i] end
		for i = 1, #(page or {}) do
			merged[#merged + 1] = page[i]
		end
		return merged
	end

	local function content_rect(screen, opts)
		opts = opts or {}
		local left = opts.left or SAFE_LEFT
		local right = opts.right or SAFE_RIGHT
		local top = opts.top or SAFE_TOP
		local bottom = opts.bottom or SAFE_BOTTOM
		return Mouse_UI.make_rect(
			left,
			top + ui_rise,
			math.max(80, screen.X - left - right),
			math.max(60, screen.Y - top - bottom)
		)
	end

	local function margin_rect(screen, y, h)
		return Mouse_UI.make_rect(SAFE_LEFT, y + ui_rise, math.max(80, screen.X - SAFE_LEFT - SAFE_RIGHT), h)
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

	local function current_page_units(session, bag, include_pending)
		local pages = build_catalog_pages()
		local page = pages[clamp_page(session)] or pages[1]
		if include_pending then
			page = merge_pending_page(page, bag)
		end
		return page
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
			if u.kind == "pair" or u.kind == "pending" then
				coeff = coeff + 1
			else
				coeff = coeff + 3
				const = const + 2 * gap
			end
			if i < #page then
				const = const + gap
				if (u.kind == "pair" or u.kind == "pending") and (page[i + 1].kind == "pair" or page[i + 1].kind == "pending") then
				else
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
		local function add(card_id, rx, ry, seija_back)
			if not valid_card(card_id) then return end
			list[#list + 1] = {
				card_id = card_id,
				rect = Mouse_UI.make_rect(rx, ry, w, h),
				scale = w / CARD_W,
				seija_back = seija_back == true,
			}
		end
		for i, u in ipairs(page) do
			if u.kind == "pending" then
				add(u.card, x, origin_y, true)
				x = x + w
			elseif u.kind == "pair" then
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
				if (u.kind == "pair" or u.kind == "pending") and (page[i + 1].kind == "pair" or page[i + 1].kind == "pending") then
				else
					x = x + group_pad
				end
			end
		end
		return list, groups
	end

	local function fit_scale_for_bands(avail_w, avail_h, bands, max_scale, min_scale)
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
		return math.max(min_scale or MIN_SCALE, scale)
	end

	local function layout_page_bands(page, area, max_scale, min_scale)
		local cols = grid_for_area(area, max_scale)
		local bands = split_into_bands(page, cols)
		local scale = fit_scale_for_bands(area.w, area.h, bands, max_scale, min_scale)
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

	local function gray_color(alpha)
		local col = Color(0.55, 0.55, 0.55, (alpha or 1) * ui_alpha)
		if col.SetColorize then col:SetColorize(1, 1, 1, 1) end
		return col
	end

	local function gray_focus_color(alpha)
		local col = Color(0.78, 0.78, 0.82, (alpha or 1) * ui_alpha)
		if col.SetColorize then col:SetColorize(1.5, 1.5, 1.6, 1) end
		return col
	end

	local function focus_color(alpha)
		local col = Color(1, 1, 1, (alpha or 1) * ui_alpha)
		if col.SetColorize then col:SetColorize(1.65, 1.4, 0.7, 1) end
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
		scale = scale or 1
		local sx = opts.scale_x
		if sx == nil then sx = 1 end
		if sx < 0 then sx = -sx end
		local alpha = opts.alpha or 1
		local focused = opts.focused == true
		if opts.face_down == true then
			local path = "gfx/ui/content/ui_cardfronts.anm2"
			if path ~= front_path then
				front_spr:Load(path, true)
				front_path = path
			end
			-- 牌阵未揭示一律 ThothBack。Seija 待翻开的卡册背面才区分正逆。
			local anim = "ThothBack"
			if opts.reverse_back == true then anim = "ThothBack r" end
			front_spr:SetFrame(anim, 0)
			front_hud = anim
			front_card = card_id
			front_spr.Color = Color(1, 1, 1, alpha * ui_alpha)
			front_spr.Scale = Vector(scale * sx, scale)
			front_spr:Render(pos + card_center_shift(scale), Vector(0, 0), Vector(0, 0))
			front_spr.Scale = Vector(1, 1)
			clear_sprite_color(front_spr)
			return
		end
		if not prepare_front(card_id) then return end
		local registered = bag and is_face_registered(bag, card_id)
		local used_floor = bag and is_face_used_this_floor(bag, card_id)
		if used_floor then
			front_spr.Color = focused and gray_focus_color(alpha) or gray_color(alpha)
		elseif registered then
			front_spr.Color = focused and focus_color(alpha) or Color(1, 1, 1, alpha * ui_alpha)
		else
			front_spr.Color = focused and gray_focus_color(alpha) or gray_color(alpha)
		end
		front_spr.Scale = Vector(scale * sx, scale)
		front_spr:Render(pos + card_center_shift(scale), Vector(0, 0), Vector(0, 0))
		front_spr.Scale = Vector(1, 1)
		clear_sprite_color(front_spr)
		render_tarot_cloth_overlay(pos, scale, {
			scale_x = sx,
			alpha = alpha * ui_alpha,
		})
	end

	local function render_empty_slot_hint(pos, scale, focused)
		-- 未置入：半透明灰色逆位卡背，提示可放牌；确认占卜后不再画。
		local path = "gfx/ui/content/ui_cardfronts.anm2"
		if path ~= front_path then
			front_spr:Load(path, true)
			front_path = path
		end
		front_spr:SetFrame("ThothBack r", 0)
		front_hud = "ThothBack r"
		front_card = nil
		local alpha = focused and 0.5 or 0.28
		front_spr.Color = focused and gray_focus_color(alpha) or gray_color(alpha)
		front_spr.Scale = Vector(scale, scale)
		front_spr:Render(pos + card_center_shift(scale), Vector(0, 0), Vector(0, 0))
		front_spr.Scale = Vector(1, 1)
		clear_sprite_color(front_spr)
	end

	local function screen_size()
		return ui.GetScreenSize()
	end

	local function draw_dim()
		local center = ui.GetScreenCenter()
		dim_spr.Color = Color(1, 1, 1, 0.72 * ui_alpha)
		dim_spr:Render(center, Vector(0, 0), Vector(0, 0))
		dim_spr.Color = Color(1, 1, 1, 1)
	end

	local function sprite_white()
		local col = Color(1, 1, 1, ui_alpha)
		if col.SetColorize then col:SetColorize(0, 0, 0, 0) end
		return col
	end

	local function tab_layer_color(mode)
		if mode == "off" then
			local col = Color(0.42, 0.42, 0.45, 0.5 * ui_alpha)
			if col.SetColorize then col:SetColorize(0, 0, 0, 0) end
			return col
		end
		local col = Color(1, 1, 1, ui_alpha)
		if mode == "hot" then
			-- 悬停提亮：走 Colorize，不用 Tint 乘色
			if col.SetColorize then col:SetColorize(1.85, 1.55, 0.55, 1) end
		elseif mode == "on" then
			if col.SetColorize then col:SetColorize(0, 0, 0, 0) end
		end
		return col
	end

	local function ensure_book_sprite()
		if book_spr.IsLoaded and not book_spr:IsLoaded() then
			book_spr:Load("gfx/mimics/Thoth/ThothBook.anm2", true)
		end
		local playing = false
		pcall(function() playing = book_spr:IsPlaying("Idle") == true end)
		if (not playing) and book_spr.Play then
			book_spr:Play("Idle", true)
		end
		if book_spr.SetFrame then book_spr:SetFrame("Idle", 0) end
		return (not book_spr.IsLoaded) or book_spr:IsLoaded()
	end

	local function book_origin(screen, cfg)
		cfg = cfg or item.get_layout()
		local cx = (screen and screen.X or 480) * 0.5
		local cy = (screen and screen.Y or 270) * 0.5
		return Vector(cx + (cfg.bg_x or 0), cy + (cfg.bg_y or 0))
	end

	local function set_book_layer_visible(layer_id, vis)
		if not book_spr.GetLayer then return end
		local ok, layer = pcall(function() return book_spr:GetLayer(layer_id) end)
		if ok and layer and layer.SetVisible then
			layer:SetVisible(vis == true)
		end
	end

	local function set_book_layer_color(layer_id, color)
		if book_spr.GetLayer then
			local ok, layer = pcall(function() return book_spr:GetLayer(layer_id) end)
			if ok and layer and layer.SetColor then
				layer:SetColor(color)
				return
			end
		end
		book_spr.Color = color
	end

	local function layer_screen_rect(layer_id, origin)
		local fb = BOOK_LAYER_FALLBACK[layer_id]
		if book_spr.GetLayerFrameData then
			local ok, frame = pcall(function() return book_spr:GetLayerFrameData(layer_id) end)
			if ok and frame then
				local pos = (frame.GetPos and frame:GetPos()) or Vector(fb and fb.x or 0, fb and fb.y or 0)
				local pivot = (frame.GetPivot and frame:GetPivot()) or Vector(0, 0)
				local w = (frame.GetWidth and frame:GetWidth()) or (fb and fb.w) or 128
				local h = (frame.GetHeight and frame:GetHeight()) or (fb and fb.h) or 32
				local tl = origin + (pos - pivot)
				return Mouse_UI.make_rect(tl.X, tl.Y, w, h)
			end
		end
		if not fb then return nil end
		return Mouse_UI.make_rect(origin.X + fb.x, origin.Y + fb.y, fb.w, fb.h)
	end

	local function cup_layer_color(session, hot)
		local t0 = session and session.cup_flash_t0
		if t0 then
			local phase = Game():GetFrameCount() - t0
			if phase >= 0 and phase < CUP_FLASH_FRAMES then
				if math.floor(phase / 3) % 2 == 0 then
					local col = Color(1, 0.28, 0.28, ui_alpha)
					if col.SetColorize then col:SetColorize(1.65, 0.1, 0.08, 1) end
					return col
				end
				return sprite_white()
			end
		end
		if hot then
			return tab_layer_color("hot")
		end
		return sprite_white()
	end

	local function grow_scale(t0, now, frames)
		if not t0 then return 1 end
		frames = frames or FLAME_GROW_FRAMES
		local t = (now - t0) / frames
		if t >= 1 then return 1 end
		if t <= 0 then return 0 end
		return 1 - (1 - t) * (1 - t)
	end

	local function frame_pos_size(fr, fb_pos, fb_pivot, fb_w, fb_h)
		local pos = (fr and fr.GetPos and fr:GetPos()) or fb_pos
		local pivot = (fr and fr.GetPivot and fr:GetPivot()) or fb_pivot or Vector(32, 32)
		local w = (fr and fr.GetWidth and fr:GetWidth()) or fb_w or 64
		local h = (fr and fr.GetHeight and fr:GetHeight()) or fb_h or 64
		return pos, pivot, w, h
	end

	local function flame_anchor_list(origin, nslots, belial)
		nslots = math.max(1, math.min(item.max_formation, math.floor(nslots or item.base_formation or 3)))
		local frames = belial and {1, 2, 3, 4} or {0, 1, 2}
		local fallback = belial and FLAME_SLOT_FALLBACK_BELIAL or FLAME_SLOT_FALLBACK
		local need = #frames
		local raw = {}
		local function add(pos, pivot, w, h)
			if not pos then return end
			raw[#raw + 1] = {pos = pos, pivot = pivot or Vector(32, 32), w = w or 64, h = h or 64}
		end
		if book_spr.GetAnimationData then
			local ok, anim = pcall(function() return book_spr:GetAnimationData("Idle") end)
			if ok and anim and anim.GetLayer then
				local ok2, layer = pcall(function() return anim:GetLayer(BOOK_LAYER_FLAMES) end)
				if ok2 and layer and layer.GetFrame then
					for fi = 1, #frames do
						local idx = frames[fi]
						local ok3, fr = pcall(function() return layer:GetFrame(idx) end)
						if ok3 and fr then
							local pos, pivot, w, h = frame_pos_size(fr, nil, nil, 64, 64)
							if pos then add(pos, pivot, w, h) end
						end
					end
				end
			end
		end
		if #raw < need then
			raw = {}
			for i = 1, #fallback do
				local fb = fallback[i]
				add(fb.pos, fb.pivot, fb.w, fb.h)
			end
		end
		table.sort(raw, function(a, b)
			if a.pos.X == b.pos.X then return a.pos.Y < b.pos.Y end
			return a.pos.X < b.pos.X
		end)
		-- 1 张用中间，2 张用左右两边，3/4 张用全部；不要按「前 n 个从左往右」截断。
		local picked = raw
		local m = #raw
		if nslots == 1 and m >= 1 then
			local mid_x = (raw[1].pos.X + raw[m].pos.X) * 0.5
			local best, best_d = raw[1], math.abs(raw[1].pos.X - mid_x)
			for i = 2, m do
				local d = math.abs(raw[i].pos.X - mid_x)
				if d < best_d then
					best = raw[i]
					best_d = d
				end
			end
			if best_d > 8 then
				picked = {{
					pos = Vector(mid_x, best.pos.Y),
					pivot = best.pivot or Vector(32, 32),
					w = best.w or 64,
					h = best.h or 64,
				}}
			else
				picked = {best}
			end
		elseif nslots == 2 and m >= 2 then
			picked = {raw[1], raw[m]}
		elseif nslots == 3 and m == 4 then
			local p2 = raw[2].pos
			local p3 = raw[3].pos
			picked = {
				raw[1],
				{
					pos = Vector((p2.X + p3.X) * 0.5, (p2.Y + p3.Y) * 0.5),
					pivot = raw[2].pivot or Vector(32, 32),
					w = raw[2].w or 64,
					h = raw[2].h or 64,
				},
				raw[m],
			}
		end
		local out = {}
		for i = 1, math.min(nslots, #picked) do
			local it = picked[i]
			out[i] = {
				center = origin + it.pos,
				rect = Mouse_UI.make_rect((origin + (it.pos - it.pivot)).X, (origin + (it.pos - it.pivot)).Y, it.w, it.h),
			}
		end
		return out
	end

	local function cup_flame_center(origin)
		local pos = CUP_FLAME_FALLBACK
		if book_spr.GetLayerFrameData then
			local ok, fr = pcall(function() return book_spr:GetLayerFrameData(BOOK_LAYER_CUP_FLAME) end)
			if ok and fr and fr.GetPos then
				pos = fr:GetPos() or pos
			end
		end
		if book_spr.GetAnimationData then
			local ok, anim = pcall(function() return book_spr:GetAnimationData("Idle") end)
			if ok and anim and anim.GetLayer then
				local ok2, layer = pcall(function() return anim:GetLayer(BOOK_LAYER_CUP_FLAME) end)
				if ok2 and layer and layer.GetFrame then
					local ok3, fr = pcall(function() return layer:GetFrame(0) end)
					if ok3 and fr and fr.GetPos then
						pos = fr:GetPos() or pos
					end
				end
			end
		end
		return origin + pos
	end

	local function ease_smooth(t)
		if t < 0 then return 0 end
		if t > 1 then return 1 end
		return t * t * (3 - 2 * t)
	end

	local function shuffle_cup_pos(origin, i, n)
		local cup = cup_flame_center(origin)
		local mid = (n + 1) * 0.5
		return cup + Vector((i - mid) * 3, -22 - (i - 1) * 2)
	end

	local function card_shuffle_phase(elapsed, i)
		local stagger = (item.shuffle_stagger or 3) * (i - 1)
		local t = elapsed - stagger
		local fly_in = item.shuffle_fly_in or 12
		local flip = item.shuffle_flip or 10
		local fly_out = item.shuffle_fly_out or 12
		if t <= 0 then return "wait", 0, 1, false end
		if t < fly_in then return "to_cup", t / fly_in, 1, false end
		t = t - fly_in
		if t < flip then
			local u = t / flip
			return "flip", u, math.abs(1 - 2 * u), u >= 0.5
		end
		t = t - flip
		if t < fly_out then return "to_slot", t / fly_out, 1, true end
		return "done", 1, 1, true
	end

	local function flame_is_idle(spr)
		if not spr then return false end
		local ok, playing = pcall(function() return spr:IsPlaying("Idle") end)
		return ok and playing == true
	end

	local function ensure_flame_sheet(spr, cache_key, reversed)
		local sheet = reversed and FLAME_SHEET_REV or FLAME_SHEET_UP
		if cache_key ~= "cup" then
			if slot_flame_sheet[cache_key] == sheet then
				if not flame_is_idle(spr) then spr:Play("Idle", true) end
				return
			end
			slot_flame_sheet[cache_key] = sheet
		else
			if cup_flame_sheet == sheet then
				if not flame_is_idle(spr) then spr:Play("Idle", true) end
				return
			end
			cup_flame_sheet = sheet
		end
		if spr.IsLoaded and not spr:IsLoaded() then
			spr:Load(FLAME_ANM2, true)
		end
		spr:ReplaceSpritesheet(0, sheet)
		if spr.LoadGraphics then spr:LoadGraphics() end
		spr:Play("Idle", true)
	end

	local function tick_flame_sprites()
		local f = Game():GetFrameCount()
		if flame_upd_frame == f then return end
		flame_upd_frame = f
		for i = 1, item.max_formation do
			if slot_flame_spr[i] and slot_flame_spr[i].Update then slot_flame_spr[i]:Update() end
		end
		if cup_flame_spr.Update then cup_flame_spr:Update() end
	end

	local function render_dynamic_flame(spr, pos, scale)
		if not spr or not pos or not scale or scale <= 0.01 then return end
		spr.Color = Color(1, 1, 1, ui_alpha)
		spr.Scale = Vector(scale, scale)
		spr:Render(pos, Vector(0, 0), Vector(0, 0))
		spr.Scale = Vector(1, 1)
		spr.Color = Color(1, 1, 1, 1)
	end

	local function page_layer_color(available, hot)
		if not available then
			local col = Color(0.38, 0.38, 0.42, ui_alpha)
			if col.SetColorize then col:SetColorize(0, 0, 0, 0) end
			return col
		end
		if hot then
			return tab_layer_color("hot")
		end
		return sprite_white()
	end

	local function tab_mode(is_current, is_hot)
		if is_hot then return "hot" end
		if is_current then return "on" end
		return "off"
	end

	local function tab_label_color(mode)
		if mode == "hot" then
			return KColor(1, 0.92, 0.42, 1)
		elseif mode == "on" then
			return KColor(0.95, 0.93, 0.88, 1)
		end
		return KColor(0.52, 0.5, 0.46, 0.55)
	end

	local function render_book_layer(layer_id, origin, color, scale)
		scale = scale or 1
		local draw_at = origin
		if scale ~= 1 then
			local rect = layer_screen_rect(layer_id, origin)
			if rect then
				local c = Mouse_UI.rect_center(rect)
				draw_at = Vector(
					origin.X + (c.X - origin.X) * (1 - scale),
					origin.Y + (c.Y - origin.Y) * (1 - scale)
				)
			end
		end
		book_spr.Scale = Vector(scale, scale)
		set_book_layer_visible(layer_id, true)
		set_book_layer_color(layer_id, color or sprite_white())
		if book_spr.RenderLayer then
			book_spr:RenderLayer(layer_id, draw_at, Vector(0, 0), Vector(0, 0))
		end
		set_book_layer_color(layer_id, sprite_white())
		book_spr.Color = sprite_white()
		book_spr.Scale = Vector(1, 1)
		set_book_layer_visible(layer_id, false)
	end

	local function hover_mul(hot)
		if hot then return item.hover_scale or 1.12 end
		return 1
	end

	-- 禁止 Sprite:Render 一次画完：p1/p2/翻页/Back/Cup 要按状态单独着色
	local function render_thoth_book(origin, session, hovered, extras)
		extras = extras or {}
		if not ensure_book_sprite() then return end
		set_book_layer_visible(BOOK_LAYER_P1, false)
		set_book_layer_visible(BOOK_LAYER_P2, false)
		set_book_layer_visible(BOOK_LAYER_PAGE_LEFT, false)
		set_book_layer_visible(BOOK_LAYER_PAGE_RIGHT, false)
		set_book_layer_visible(BOOK_LAYER_BACK, false)
		set_book_layer_visible(BOOK_LAYER_FLAMES, false)
		set_book_layer_visible(BOOK_LAYER_CUP, false)
		set_book_layer_visible(BOOK_LAYER_CUP_FLAME, false)
		render_book_layer(BOOK_LAYER_MAIN, origin, sprite_white())
		local p1 = tab_mode(session.tab == "catalog", hovered == "tab_catalog" or session.focus_id == "tab_catalog")
		local p2 = tab_mode(session.tab == "divine", hovered == "tab_divine" or session.focus_id == "tab_divine")
		-- 上方 tab 只换色不缩放：标签是独立字体，跟不上 Sprite.Scale。
		render_book_layer(BOOK_LAYER_P1, origin, tab_layer_color(p1))
		render_book_layer(BOOK_LAYER_P2, origin, tab_layer_color(p2))
		if session.tab == "divine" then
			render_book_layer(BOOK_LAYER_BACK, origin, sprite_white())
			local flame_s = extras.cup_flame_scale or 0
			if flame_s > 0.01 then
				ensure_flame_sheet(cup_flame_spr, "cup", false)
				render_dynamic_flame(cup_flame_spr, cup_flame_center(origin), flame_s)
			end
			render_book_layer(BOOK_LAYER_CUP, origin, cup_layer_color(session, extras.cup_hot == true), hover_mul(extras.cup_hot == true))
		end
	end

	local function render_thoth_page_layers(origin, session, hovered)
		if not origin or not session then return end
		local pages_ok = page_count() > 1
		local prev_hot = pages_ok and (hovered == "btn_prev" or session.focus_id == "btn_prev")
		local next_hot = pages_ok and (hovered == "btn_next" or session.focus_id == "btn_next")
		render_book_layer(BOOK_LAYER_PAGE_LEFT, origin, page_layer_color(pages_ok, prev_hot), hover_mul(prev_hot))
		render_book_layer(BOOK_LAYER_PAGE_RIGHT, origin, page_layer_color(pages_ok, next_hot), hover_mul(next_hot))
	end

	-- DrawString 原点在字框左上，视觉中心偏上
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
		color = KColor(color.Red, color.Green, color.Blue, (color.Alpha or 1) * ui_alpha)
		if opts.align == "left" then
			font:DrawStringScaledUTF8(text, x, y, sx, sy, color, 0, false)
		else
			font:DrawStringScaledUTF8(text, x, y, sx, sy, color, box_w, true)
		end
	end

	local function draw_tab_label(rect, text, color, ox, oy)
		if not rect or not text then return end
		local font = ui_font()
		local line_h = (font.GetLineHeight and font:GetLineHeight() or 12)
		local x = rect.x + (ox or 0) + TEXT_OFFSET.X
		local y = rect.y + (oy or 0) + ((rect.h - line_h) * 0.5) + TEXT_OFFSET.Y
		color = color or KColor(1, 1, 1, 1)
		color = KColor(color.Red, color.Green, color.Blue, (color.Alpha or 1) * ui_alpha)
		font:DrawStringScaledUTF8(text, x, y, 1, 1, color, math.max(0, math.floor(rect.w)), true)
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

	local function divine_layout(screen, page, origin, nslots, belial)
		local cfg = item.get_layout()
		local area = content_rect(screen)
		origin = origin or book_origin(screen, cfg)
		nslots = math.max(1, math.min(item.max_formation, math.floor(nslots or item.base_formation or 3)))
		local anchors = flame_anchor_list(origin, nslots, belial == true)
		local slot_scale = cfg.slot_card_scale or 1
		local slot_ox = cfg.slot_card_x or 0
		local slot_oy = cfg.slot_card_y or 0
		local slots = {}
		local slot_centers = {}
		local flame_centers = {}
		local lowest = area.y
		for i = 1, nslots do
			local a = anchors[i]
			if a then
				flame_centers[i] = a.center
				slots[i] = Mouse_UI.make_rect(a.rect.x + slot_ox, a.rect.y + slot_oy, a.rect.w, a.rect.h)
				slot_centers[i] = a.center + Vector(slot_ox, slot_oy)
				lowest = math.max(lowest, a.rect.y + a.rect.h)
			else
				flame_centers[i] = Mouse_UI.rect_center(Mouse_UI.make_rect(origin.X - 32 + (i - 2) * 110, origin.Y - 40, 64, 64))
				slots[i] = Mouse_UI.make_rect(origin.X - 32 + (i - 2) * 110 + slot_ox, origin.Y - 40 + slot_oy, 64, 64)
				slot_centers[i] = Mouse_UI.rect_center(slots[i])
				lowest = math.max(lowest, origin.Y - 40 + 64)
			end
		end
		local confirm_layer = layer_screen_rect(BOOK_LAYER_CUP, origin)
		if not confirm_layer then
			confirm_layer = Mouse_UI.make_rect(origin.X - 224, origin.Y - 112, 448, 96)
		end
		local cup_c = Mouse_UI.rect_center(confirm_layer)
		local confirm = Mouse_UI.make_rect_centered(
			Vector(cup_c.X + (cfg.cup_hit_x or 0), cup_c.Y + (cfg.cup_hit_y or 0)),
			cfg.cup_hit_w or 72,
			cfg.cup_hit_h or 52
		)
		local split = cfg.divine_split or 0.4
		-- 卡池起点仍贴在槽位下方；Y 只平移列表，不改上半占卜区。
		local pool_y = math.max(lowest + 8, area.y + area.h * split)
		local pool_h = math.max(40, area.y + area.h - pool_y)
		local pool = Mouse_UI.make_rect(area.x, pool_y, area.w, pool_h)
		local lay = layout_page_bands(page, pool, MAX_SCALE_DIVINE)
		local pool_oy = cfg.pool_y or 0
		if pool_oy ~= 0 then
			for i = 1, #(lay.placements or {}) do
				local rect = lay.placements[i].rect
				if rect then rect.y = rect.y + pool_oy end
			end
			for i = 1, #(lay.groups or {}) do
				local g = lay.groups[i]
				if g then g.y = g.y + pool_oy end
			end
		end
		return {
			slot_scale = slot_scale,
			slots = slots,
			slot_centers = slot_centers,
			flame_centers = flame_centers,
			confirm = confirm,
			pool = pool,
			area = area,
			placements = lay.placements,
			groups = lay.groups,
		}
	end

	local function page_button_rects(origin, screen, tab)
		local cfg = item.get_layout()
		local page_y = (tab == "divine") and (cfg.page_label_y_divine or -21) or (cfg.page_label_y_catalog or -26)
		return {
			prev = layer_screen_rect(BOOK_LAYER_PAGE_LEFT, origin),
			next = layer_screen_rect(BOOK_LAYER_PAGE_RIGHT, origin),
			label = Mouse_UI.make_rect(
				screen.X * 0.5 - 36 + (cfg.page_label_x or 0),
				screen.Y - 24 + page_y + ui_rise,
				72,
				16
			),
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

	local function next_empty_slot(draft, nslots)
		nslots = nslots or item.base_formation or 3
		for i = 1, nslots do
			if draft[i] == nil then return i end
		end
		return nil
	end

	local function toggle_draft_card(session, card_id, bag)
		if not session or not card_id or not bag then return false end
		if formation_active(bag) then return false end
		if not is_face_selectable(bag, card_id) then return false end
		local pos = draft_has(session.draft, card_id)
		if pos then
			session.draft[pos] = nil
			return true
		end
		local cap = item.slot_count(session.player)
		local compact = draft_compact(session.draft)
		if #compact >= cap then return false end
		local slot = next_empty_slot(session.draft, cap)
		if not slot then return false end
		session.draft[slot] = card_id
		return true
	end

	local function assign_slot(session, slot, card_id, bag)
		if not session or not slot or not card_id or not bag then return false end
		if formation_active(bag) then return false end
		if not is_face_selectable(bag, card_id) then return false end
		local cap = item.slot_count(session.player)
		slot = math.floor(tonumber(slot) or 0)
		if slot < 1 or slot > cap then return false end
		local existing = draft_has(session.draft, card_id)
		if existing then session.draft[existing] = nil end
		session.draft[slot] = card_id
		return true
	end

	local function reject_cup(session)
		if not session then return end
		session.cup_flash_t0 = Game():GetFrameCount()
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.55, 1.1, false, 0, 2)
	end

	local function try_confirm(session)
		local player = session and session.player
		if not player then return end
		local bag = get_bag(player)
		if not bag or formation_active(bag) then
			reject_cup(session)
			return
		end
		local n = #draft_compact(session.draft)
		if n < 1 then
			reject_cup(session)
			return
		end
		if get_revelation(player) < item.formation_cost then
			session.cup_fail = "no_rev"
			reject_cup(session)
			return
		end
		if not draft_can_confirm(player, session.draft) then
			reject_cup(session)
			return
		end
		if apply_draft(player, session.draft) == 1 then
			session.cup_fail = nil
			local bag = get_bag(player)
			local from_ids = draft_compact(session.draft)
			local from_centers = {}
			local lay = session._divine
			for i = 1, item.max_formation do
				if session.draft[i] then
					local center
					if lay and lay.slot_centers and lay.slot_centers[i] then
						center = lay.slot_centers[i]
					elseif lay and lay.slots and lay.slots[i] then
						center = Mouse_UI.rect_center(lay.slots[i])
					end
					if center then
						from_centers[#from_centers + 1] = center
					end
				end
			end
			local to_ids = {}
			for i = 1, #(bag and bag.formation or {}) do
				to_ids[i] = bag.formation[i]
			end
			session.just_confirmed = true
			session.cup_flame_t0 = Game():GetFrameCount()
			if #from_ids > 0 and #from_centers == #from_ids then
				session.shuffle_anim = {
					t0 = Game():GetFrameCount(),
					from_ids = from_ids,
					from_centers = from_centers,
					to_ids = to_ids,
				}
			end
			session.tab = "divine"
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOOK_PAGE_TURN_12, 0.9, 0.85, false, 0, 2)
		else
			reject_cup(session)
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
				if is_face_selectable(bag, card_id) and not formation_active(bag) then
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
		open_lock = 16,
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
			session.just_confirmed = false
			session.cup_flame_t0 = nil
			session.shuffle_anim = nil
			session.slot_flame_card = {}
			session.slot_flame_t0 = {}
			session.cup_flash_t0 = nil
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
			local cap = item.slot_count(player)
			local nslots = cap
			if locked then
				nslots = math.max(1, #(bag.formation or {}))
			end
			if locked then
				session.draft = session.draft or {}
				for i = 1, nslots do
					session.draft[i] = bag.formation[i]
				end
				for i = nslots + 1, item.max_formation do
					session.draft[i] = nil
				end
			else
				session.draft = session.draft or {}
				for i = nslots + 1, item.max_formation do
					session.draft[i] = nil
				end
			end

			local cfg = item.get_layout()
			ensure_book_sprite()
			local open_t = 1
			if session.opened_frame then
				local dur = math.max(1, item.open_rise_dur or 14)
				open_t = (Game():GetFrameCount() - session.opened_frame) / dur
				if open_t < 0 then open_t = 0 elseif open_t > 1 then open_t = 1 end
			end
			local rise_ease = 1 - (1 - open_t) ^ 3
			ui_alpha = (open_t < 0.55) and (open_t / 0.55) or 1
			ui_rise = (1 - rise_ease) * (item.open_rise_distance or 72)
			draw_dim()
			local origin = book_origin(screen, cfg) + Vector(0, ui_rise)
			local tab_catalog = layer_screen_rect(BOOK_LAYER_P1, origin)
			local tab_divine = layer_screen_rect(BOOK_LAYER_P2, origin)
			if not tab_catalog then
				tab_catalog = Mouse_UI.make_rect(screen.X * 0.5 - 76, 6, 70, 18)
			end
			if not tab_divine then
				tab_divine = Mouse_UI.make_rect(screen.X * 0.5 + 6, 6, 70, 18)
			end
			Mouse_UI.begin_frame(player)

			local tabs, body = {}, {}
			Mouse_UI.register("tab_catalog", tab_catalog, {z = 20})
			Mouse_UI.register("tab_divine", tab_divine, {z = 20})
			nav_add(tabs, "tab_catalog", tab_catalog)
			nav_add(tabs, "tab_divine", tab_divine)

			local layouts = {}
			local page = current_page_units(session, bag, session.tab == "divine" or clamp_page(session) == 1)
			local pages_ok = page_count() > 1
			local pager = page_button_rects(origin, screen, session.tab)
			if pager.prev then
				Mouse_UI.register("btn_prev", pager.prev, {z = 4, enabled = pages_ok, block = pages_ok})
				if pages_ok then nav_add(body, "btn_prev", pager.prev) end
				layouts.btn_prev = {rect = pager.prev}
			end
			if pager.next then
				Mouse_UI.register("btn_next", pager.next, {z = 4, enabled = pages_ok, block = pages_ok})
				if pages_ok then nav_add(body, "btn_next", pager.next) end
				layouts.btn_next = {rect = pager.next}
			end
			layouts.page_label = {rect = pager.label}

			if session.tab == "catalog" then
				local lay = catalog_layout(screen, page)
				session._groups = lay.groups
				for _, place in ipairs(lay.placements) do
					if not (is_face_pending(bag, place.card_id) and not place.seija_back) then
						local id = "card_"..tostring(place.card_id)
						Mouse_UI.register(id, place.rect, {z = 10})
						nav_add(body, id, place.rect)
						layouts[id] = {rect = place.rect, card_id = place.card_id, scale = place.scale, seija_back = place.seija_back}
					end
				end
			else
				local lay = divine_layout(screen, page, origin, nslots, cap >= 4)
				session._groups = lay.groups
				session._divine = lay
				for i = 1, nslots do
					if lay.slots[i] then
						local id = "slot_"..tostring(i)
						Mouse_UI.register(id, lay.slots[i], {z = 18, drop_target = true, draggable = not locked})
						nav_add(body, id, lay.slots[i])
						layouts[id] = {rect = lay.slots[i], slot = i, scale = lay.slot_scale, card_id = session.draft[i]}
					end
				end
				Mouse_UI.register("btn_confirm", lay.confirm, {z = 19})
				nav_add(body, "btn_confirm", lay.confirm)
				layouts.btn_confirm = {rect = lay.confirm}
				for _, place in ipairs(lay.placements) do
					if not (is_face_pending(bag, place.card_id) and not place.seija_back) then
						local id = "pool_"..tostring(place.card_id)
						Mouse_UI.register(id, place.rect, {z = 12, draggable = not locked})
						if not session.pad_carry then
							nav_add(body, id, place.rect)
						end
						layouts[id] = {rect = place.rect, card_id = place.card_id, scale = place.scale, pool = true, seija_back = place.seija_back}
					end
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
			local function drop_drag()
				if not session.drag then return end
				if session.drag.armed_frame == Game():GetFrameCount() then return end
				if not Mouse_UI.was_released(0) then return end
				local drop = Mouse_UI.drop_target_id or Mouse_UI.get_hovered_id()
				if drop and type(drop) == "string" and drop:sub(1, 5) == "slot_" then
					assign_slot(session, tonumber(drop:sub(6)), session.drag.card_id, bag)
				end
				session.drag = nil
			end
			if session.tab == "divine" and not locked then
				drop_drag()
			end
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
				if session.tab == "divine" and not locked and not session.drag then
					for i = 1, nslots do
						local id = "slot_"..tostring(i)
						local info = layouts[id]
						if info and Mouse_UI.is_pressed(id) and session.draft[i] then
							session.drag = {
								card_id = session.draft[i],
								from_slot = i,
								grab_offset = Mouse_UI.mouse - Mouse_UI.rect_center(info.rect),
								armed_frame = Game():GetFrameCount(),
							}
							session.draft[i] = nil
							break
						end
					end
				end
				if session.tab == "divine" and not locked and not session.drag then
					for id, info in pairs(layouts) do
						if info.pool and info.card_id and Mouse_UI.is_pressed(id) then
							if is_face_selectable(bag, info.card_id) then
								session.drag = {
									card_id = info.card_id,
									grab_offset = Mouse_UI.mouse - Mouse_UI.rect_center(info.rect),
									armed_frame = Game():GetFrameCount(),
								}
								session.focus_id = id
								sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.4, 1, false, 0, 2)
							end
						end
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
				elseif not session.drag and Mouse_UI.is_pressed("btn_prev") then
					change_page(session, -1)
				elseif not session.drag and Mouse_UI.is_pressed("btn_next") then
					change_page(session, 1)
				end
			end

			if not Select.get(PANEL_ID) then return end

			tick_flame_sprites()
			local hovered_now = Mouse_UI.get_hovered_id()
			local cup_hover = session.tab == "divine" and not locked and (hovered_now == "btn_confirm" or session.focus_id == "btn_confirm")
			local cup_scale = 0
			if session.tab == "divine" then
				if session.just_confirmed and session.cup_flame_t0 then
					cup_scale = grow_scale(session.cup_flame_t0, Game():GetFrameCount())
				elseif locked then
					cup_scale = 1
				end
			end
			render_thoth_book(origin, session, hovered_now, {
				cup_hot = cup_hover,
				cup_flame_scale = cup_scale,
			})
			draw_text_in_rect(margin_rect(screen, 26, 12), txt("title").."  "..txt("rev")..": "..tostring(get_revelation(player)).."/"..tostring(item.max_revelation), KColor(0.9, 0.8, 1, 1))
			local cat_mode = tab_mode(session.tab == "catalog", hovered_now == "tab_catalog" or session.focus_id == "tab_catalog")
			local div_mode = tab_mode(session.tab == "divine", hovered_now == "tab_divine" or session.focus_id == "tab_divine")
			draw_tab_label(tab_catalog, txt("tab_catalog"), tab_label_color(cat_mode), cfg.tab_catalog_text_x, cfg.tab_catalog_text_y)
			draw_tab_label(tab_divine, txt("tab_divine"), tab_label_color(div_mode), cfg.tab_divine_text_x, cfg.tab_divine_text_y)
			draw_text_in_rect(pager.label, tostring(clamp_page(session)).." / "..tostring(page_count()), KColor(0.85, 0.8, 1, 1))

			if session.tab == "catalog" then
				for id, info in pairs(layouts) do
					if info.card_id then
						local center = Mouse_UI.rect_center(info.rect)
						local focused = session.focus_id == id
						local selectable = focused and is_face_selectable(bag, info.card_id)
						local pending = info.seija_back == true
						render_card_front(info.card_id, center, info.scale * hover_mul(selectable), bag, {
							focused = focused,
							face_down = pending,
							reverse_back = pending and auxi.is_reversed_card(info.card_id),
						})
					end
				end
			else
				local lay = session._divine
				session.slot_flame_card = session.slot_flame_card or {}
				session.slot_flame_t0 = session.slot_flame_t0 or {}
				local now = Game():GetFrameCount()
				local instant = locked and session.just_confirmed ~= true and session.shuffle_anim == nil
				local shuffling = session.shuffle_anim ~= nil
				for i = 1, nslots do
					local rect = lay.slots[i]
					if rect then
					local center = (lay.slot_centers and lay.slot_centers[i]) or Mouse_UI.rect_center(rect)
					local flame_at = (lay.flame_centers and lay.flame_centers[i]) or center
					local hot = session.focus_id == ("slot_"..tostring(i))
					local cid = session.draft[i]
					local reveal_rev = cid and auxi.is_reversed_card(cid) == true
					if locked and cid and not is_played_in_spread(bag, cid) then
						reveal_rev = false
					end
					if session.slot_flame_card[i] ~= cid then
						session.slot_flame_card[i] = cid
						if cid then
							session.slot_flame_t0[i] = instant and (now - FLAME_GROW_FRAMES) or now
							ensure_flame_sheet(slot_flame_spr[i], i, reveal_rev)
						else
							session.slot_flame_t0[i] = nil
						end
					elseif cid then
						ensure_flame_sheet(slot_flame_spr[i], i, reveal_rev)
					end
					local slot_sc = lay.slot_scale * hover_mul(hot and not locked)
					if cid then
						render_dynamic_flame(slot_flame_spr[i], flame_at, grow_scale(session.slot_flame_t0[i], now))
						if not shuffling then
							local pending = is_face_pending(bag, cid)
							render_card_front(cid, center, slot_sc, bag, {
								focused = hot,
								face_down = pending or (locked and not is_played_in_spread(bag, cid)),
								reverse_back = pending and auxi.is_reversed_card(cid),
							})
						end
					elseif not locked and not shuffling then
						render_empty_slot_hint(center, slot_sc, hot)
					end
					end
				end
				if shuffling then
					local anim = session.shuffle_anim
					local elapsed = now - (anim.t0 or now)
					local n = #(anim.from_ids or {})
					local all_done = n > 0
					local seija_hide = item.is_seija(player)
					for i = 1, n do
						local phase, u, sx, face_down = card_shuffle_phase(elapsed, i)
						if phase ~= "done" then all_done = false end
						if seija_hide then face_down = true end
						local card_id = anim.from_ids[i]
						local from = anim.from_centers[i]
						local dest = from
						for j = 1, #(anim.to_ids or {}) do
							if anim.to_ids[j] == card_id then
								dest = (lay.slot_centers and lay.slot_centers[j]) or from
								break
							end
						end
						local cup = shuffle_cup_pos(origin, i, n)
						local pos = from
						if phase == "to_cup" then
							pos = from + (cup - from) * ease_smooth(u)
						elseif phase == "flip" or phase == "wait" then
							if phase == "flip" then pos = cup end
						elseif phase == "to_slot" or phase == "done" then
							pos = cup + (dest - cup) * ease_smooth(u)
						end
						render_card_front(card_id, pos, lay.slot_scale, bag, {
							face_down = face_down,
							scale_x = sx,
							reverse_back = face_down and seija_hide and auxi.is_reversed_card(card_id),
						})
					end
					if all_done or n == 0 then
						session.shuffle_anim = nil
					end
				end
				for id, info in pairs(layouts) do
					if info.pool and info.card_id then
						local focused = session.focus_id == id or session.pad_carry == info.card_id
						if not (session.drag and session.drag.card_id == info.card_id) then
							local selectable = focused and not locked and is_face_selectable(bag, info.card_id)
							local pending = info.seija_back == true
							render_card_front(info.card_id, Mouse_UI.rect_center(info.rect), info.scale * hover_mul(selectable), bag, {
								focused = focused,
								face_down = pending,
								reverse_back = pending and auxi.is_reversed_card(info.card_id),
							})
						end
					end
				end
				if session.drag then
					local pos = Mouse_UI.mouse - (session.drag.grab_offset or Vector(0, 0))
					local pending = is_face_pending(bag, session.drag.card_id)
					render_card_front(session.drag.card_id, pos, lay.slot_scale * hover_mul(true), bag, {
						alpha = 0.95,
						focused = true,
						face_down = pending,
						reverse_back = pending and auxi.is_reversed_card(session.drag.card_id),
					})
				elseif session.pad_carry then
					local pending = is_face_pending(bag, session.pad_carry)
					render_card_front(session.pad_carry, Mouse_UI.rect_center(lay.slots[1]) + Vector(0, -28), 1.4, bag, {
						alpha = 0.7,
						face_down = pending,
						reverse_back = pending and auxi.is_reversed_card(session.pad_carry),
					})
				end
			end

			render_thoth_page_layers(origin, session, hovered_now)

			local status
			if cup_hover then
				status = txt("cup_cost")
			elseif session.cup_fail == "no_rev" then
				status = txt("no_rev")
			else
				local focus_info = layouts[session.focus_id]
				if focus_info and focus_info.card_id then
					if locked and not is_played_in_spread(bag, focus_info.card_id) and session.draft and draft_has(session.draft, focus_info.card_id) then
						status = txt("hidden")
					elseif is_face_used_this_floor(bag, focus_info.card_id) then
						status = card_meta(focus_info.card_id).name.."  "..txt("used_floor")
					elseif is_face_pending(bag, focus_info.card_id) then
						status = (auxi.is_reversed_card(focus_info.card_id) and txt("rev_face") or txt("up_face")).."  "..txt("pending")
					elseif is_face_registered(bag, focus_info.card_id) then
						status = card_meta(focus_info.card_id).name
					else
						status = txt("unregistered")
					end
				end
			end
			if status then
				draw_text_in_rect(margin_rect(screen, 38, 12), status, KColor(0.95, 0.9, 0.75, 1))
			end
		end,
	})
end
init_thoth_panel()

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
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		if player then
			tick_cast_anim(player)
		end
	end
end

local function queue_next_formation_card()
	if not is_uncleared_combat_room() then return end
	local key = current_room_key()
	if not key then return end
	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Game():GetPlayer(i)
		local bag = peek_bag(player)
		local _, idx = get_cast_anim(player)
		if idx ~= nil and cast_anims[idx] then
			-- 正在播翻牌/飞牌，不重复排队
		elseif bag and formation_active(bag) and bag.pendingCast == nil then
			if not room_already_triggered(bag, key) then
				mark_room_triggered(bag, key)
				local rest = unrevealed_indices(bag)
				if #rest > 0 then
					local rng = player:GetCollectibleRNG(item.entity)
					rng = auxi.rng_for_sake(rng)
					local pick = rest[rng:RandomInt(#rest) + 1]
					local card_id = bag.formation[pick]
					if card_id then
						bag.pendingCast = card_id
						bag.pendingIndex = pick
						bag.pendingFrame = nil
					end
				end
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
	ensure_owned(player)
	sync_charge(player)
end,
})

-- 持有本书时在卡池抽取（MC_GET_CARD）改抽：透特牌偏向未登记牌面；普通塔罗按未登记比例替换，上限 1/2。
-- 后回调的 card 仍是池子原始结果（Card_All 的返回不会写回参数）；这里最后返回则覆盖。
-- 明确 Spawn / 玩家放下的牌不走卡池，因此不会被改抽。
table.insert(item.post_ToCall, #item.post_ToCall + 1, {CallBack = ModCallbacks.MC_GET_CARD, params = nil,
Function = function(_, rng, card, _, _, onlyrune)
	if onlyrune then return end
	if not anyone_holds_book() then return end
	if auxi.is_thoth_card(card) then
		local ret = pick_weighted_thoth(rng)
		if ret then return ret end
		return
	end
	if auxi.is_tarot_card(card) then
		local p = tarot_replace_chance()
		if p <= 0 then return end
		rng = auxi.rng_for_sake(rng)
		if rng:RandomInt(1000) < math.floor(p * 1000 + 0.5) then
			local ret = pick_weighted_thoth(rng)
			if ret then return ret end
		end
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = item.entity,
Function = function(_, player, collid, cnt, touched)
	ensure_owned(player)
	register_held_thoth_cards(player)
	sync_charge(player)
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
		grant_revelation(player, item.use_revelation, true)
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
	queue_next_formation_card()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_LEVEL, params = nil,
Function = function()
	-- NEW_LEVEL 总在 NEW_ROOM 之后：若本层起始房已推进过牌阵，清表后要立刻写回当前房，避免离开再进时重复发动。
	local key = current_room_key()
	local keep_current = is_uncleared_combat_room()
	local root = data_root()
	for _, bag in pairs(root) do
		if type(bag) == "table" then
			bag.usedThisFloor = {}
			bag.triggeredRooms = {}
			if keep_current then
				mark_room_triggered(bag, key)
			end
		end
	end
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function()
	tick_holo_spr()
	resolve_pending()
	local seed = Game():GetSeeds()
	local holder = auxi.have_player_has_collectible(item.entity)
	if holder and item.is_seija(holder) then
		if save.elses[item.own_key.."SeijaBuff"] == nil then
			save.elses[item.own_key.."SeijaBuff"] = seed:HasSeedEffect(SeedEffect.SEED_MYSTERY_TAROT_CARDS)
			seed:AddSeedEffect(SeedEffect.SEED_MYSTERY_TAROT_CARDS)
		end
	elseif save.elses[item.own_key.."SeijaBuff"] ~= nil then
		if save.elses[item.own_key.."SeijaBuff"] == true then
			seed:AddSeedEffect(SeedEffect.SEED_MYSTERY_TAROT_CARDS)
		else
			seed:RemoveSeedEffect(SeedEffect.SEED_MYSTERY_TAROT_CARDS)
		end
		save.elses[item.own_key.."SeijaBuff"] = nil
	end
	sync_seija_eid_card_icons()
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Isaac.GetPlayer(i)
		if p and not item.is_seija(p) then
			local bag = peek_bag(p)
			if bag and bag.seijaPending and #bag.seijaPending > 0 then
				reveal_seija_pending(bag)
			end
		end
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
	hud_orbits = {}
	hud_spin = {}
	hud_spin_frame = {}
	hud_last_pos = {}
	last_hud_scale = {}
	cast_anims = {}
	if not continue then
		save.elses[item.own_key.."data"] = {}
		save.elses[item.own_key.."effect"] = nil
		save.elses[item.own_key.."counter"] = nil
	end
	save.elses[item.own_key.."data"] = save.elses[item.own_key.."data"] or {}
end,
})

if ModCallbacks.MC_PRE_PLAYERHUD_RENDER_ACTIVE_ITEM then
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_PRE_PLAYERHUD_RENDER_ACTIVE_ITEM, params = item.entity,
	Function = function(_, player, slot)
		local bag = player and get_bag(player)
		if not bag then return {HideOutline = true} end
		if formation_active(bag) then
			-- 有牌阵时白边画在卡面上，藏掉书图标自己的描边。
			return {HideOutline = true}
		end
		if get_revelation(player) < item.formation_cost then
			return {HideOutline = true}
		end
	end,
	})
end

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_SLOT_RENDER, params = "Active",
Function = function(_, player, tp, cid, slot)
	if cid ~= item.entity then return end
	local bag = get_bag(player)
	if not bag then return end
	if #(bag.formation or {}) == 0 then return end
	local info = ui.GetActiveSlotRenderInfo(player, slot)
	local alpha = (info and info.alpha) or 1
	local slot_scale = (info and tonumber(info.scale)) or 1
	local center = ui.PlayerActiveUIPos(player, slot, auxi.GetPlayerOrder(player), cid)
	local lay = item.get_layout()
	center = center + Vector(lay.hud_card_x or 0, lay.hud_card_y or 0)
	-- HudCardScale=0.5：16px 卡面正好是 32px 主动槽的一半
	local hud = lay.hud_card_scale or 0.5
	local icon_scale = hud * 2 * slot_scale
	local anim, idx = get_cast_anim(player)
	local cards = hud_orbit_cards(bag, anim)
	if #cards == 0 then return end
	if idx == nil then return end
	local frame = Game():GetFrameCount()
	if hud_spin_frame[idx] ~= frame then
		hud_spin[idx] = (hud_spin[idx] or 0) + (item.hud_orbit_speed or 0.012)
		hud_spin_frame[idx] = frame
	end
	local spin = hud_spin[idx]
	last_hud_scale[idx] = icon_scale
	local st = hud_orbits[idx] or {}
	local rx = (item.hud_orbit_rx or 13) * slot_scale
	local ry = (item.hud_orbit_ry or 10) * slot_scale
	local n = #cards
	local draw_list = {}
	local keep = {}
	for i = 1, n do
		local rec = cards[i]
		local target = orbit_target(i, n, spin)
		local cur = st[rec.id]
		if cur == nil then cur = target end
		cur = lerp_angle(cur, target, 0.12)
		keep[rec.id] = cur
		local pos = center + Vector(math.cos(cur) * rx, math.sin(cur) * ry)
		local face_up = false
		local opts
		if anim and anim.card_id == rec.id then
			if anim.phase == "flip" then
				local u = (Game():GetFrameCount() - (anim.t0 or 0)) / math.max(1, item.cast_flip_dur or 10)
				if u < 0 then u = 0 elseif u > 1 then u = 1 end
				face_up = u >= 0.5
				opts = {scale_x = math.max(0.05, math.abs(1 - 2 * u))}
			elseif anim.phase == "reveal" then
				face_up = true
			end
		end
		draw_list[#draw_list + 1] = {
			id = rec.id,
			pos = pos,
			face_up = face_up,
			opts = opts,
			y = pos.Y,
		}
		hud_last_pos[idx] = hud_last_pos[idx] or {}
		hud_last_pos[idx][rec.id] = pos
	end
	hud_orbits[idx] = keep
	table.sort(draw_list, function(a, b) return a.y < b.y end)
	local outline = hud_ready_outline_color(alpha)
	local col = Color(1, 1, 1, alpha)
	for i = 1, #draw_list do
		local it = draw_list[i]
		for d = 1, #HUD_OUTLINE_OFFS do
			local outline_opts = it.opts or {}
			render_card_icon(it.id, it.pos + HUD_OUTLINE_OFFS[d], icon_scale, outline, it.face_up, {
				scale_x = outline_opts.scale_x,
				rotation = outline_opts.rotation,
				cloth = false,
			})
		end
	end
	for i = 1, #draw_list do
		local it = draw_list[i]
		render_card_icon(it.id, it.pos, icon_scale, col, it.face_up, it.opts)
	end
end,
})

do
	local hud_render_cb = (REPENTOGON and ModCallbacks.MC_POST_HUD_RENDER) or ModCallbacks.MC_POST_RENDER
	table.insert(item.ToCall, #item.ToCall + 1, {CallBack = hud_render_cb, params = nil,
	Function = function()
		for i = 0, Game():GetNumPlayers() - 1 do
			local player = Game():GetPlayer(i)
			if player and auxi.has_have_coll(player, item.entity) then
				local lay = item.get_layout()
				local idx = player_index(player)
				local scale = (idx ~= nil and last_hud_scale[idx]) or ((lay.hud_card_scale or 0.5) * 2)
				render_cast_overlay(player, 1, scale)
			end
		end
	end,
	})
end

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

EID:addDescriptionModifier("qing_thoth_eid", function(desc) return true end, function(desc)
	local id = desc.ObjType
	local vr = desc.ObjVariant
	local st = desc.ObjSubType
	if id == 5 and vr == 100 and st == item.entity then
		local player = auxi.have_player_has_collectible(item.entity)
		local bag = player and get_bag(player)
		if bag and formation_active(bag) then
			local names = {}
			for i = 1, #(bag.formation or {}) do
				local cid = bag.formation[i]
				if is_played_in_spread(bag, cid) then
					names[#names + 1] = card_meta(cid).name
				else
					names[#names + 1] = is_zh() and "未揭示" or "?"
				end
			end
			local info = is_zh() and ("#当前牌阵："..table.concat(names, " / ")) or ("#Current spread: "..table.concat(names, " / "))
			EID:appendToDescription(desc, info)
		end
	end
	if id == 5 and vr == 300 and auxi.is_thoth_card(st) and seija_hides_thoth_cards() then
		local sd = item.Seija_desc[Options.Language] or item.Seija_desc["en"]
		desc.Name = sd.Name
		desc.Description = sd.Description
		desc.Transformation = nil
		local reversed = auxi.is_reversed_card(st)
		-- Tab：字符串 Icon 会被原样返回。地面标题：printDescription 需要 table。
		if EID.InsideItemReminder then
			desc.Icon = reversed and "{{ThothCard2}}" or "{{ThothCard}}"
		else
			local ic = EID.InlineIcons and (reversed and EID.InlineIcons.ThothCard2 or EID.InlineIcons.ThothCard)
			if ic then
				desc.Icon = ic
			else
				desc.Icon = {"pickups", reversed and 1 or 0, 12, 11, 0, -1, cdsprite2}
			end
		end
	end
	return desc
end)

end

return item
