-- Read-only HUD target snapshot for Ketu / Rahu.
-- Reuses spectralsword hud_nodes anchors + ui heart/resource/active positions,
-- HistoryHUD collectibles/smelted trinkets, and PRE_PLAYERHUD_TRINKET_RENDER cache.
-- Does NOT call try_extract / try_inject.
local ui = require("Qing_Remaster_scripts.auxiliary.ui")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local enums = require("Qing_Remaster_scripts.core.enums")
local hud_nodes = require("Qing_Remaster_scripts.items.spectralsword.hud_nodes")

local M = {}

M.minimap_offset = Vector(-8, 8)
-- Found-HUD stat/deal column nudge. Calibrated 2026-11-08 (probe): (0, 8).
M.stat_column_offset = Vector(0, 8)
-- Physical trinket slot arc half-width (px). Calibrated 2026-11-08 (probe): 16.
M.trinket_own_radius = 16

local HEART_SLOT = 12 -- ui.HUD_SLOT_BOX.heart
local HEART_HALF = Vector(HEART_SLOT * 0.5, HEART_SLOT * 0.5)
local STAT_HALF = Vector(28, 7)
local RESOURCE_HALF = Vector(28, 8)
local DEAL_HALF = Vector(28, 7)
local ACTIVE_HALF = Vector(16, 16)
local ITEM_HALF = Vector(14, 14)
local TRINKET_HALF = Vector(14, 14)
local DEFAULT_RADIUS_FRAC = 0.045 -- matches orbit.node_radius_frac (Voronoi ∩ radius)
-- History row pitch fill: each GRID row owns half-step; empty rows stay blank.
local HISTORY_ROW_FILL = 1.0
-- Fallback row pitch when layout Y cannot be measured (32px icon @ scale 1).
local HISTORY_ROW_PITCH_FALLBACK = 32
-- Y-quantization epsilon for grouping Extra HUD cells into the same visual row.
local HISTORY_ROW_Y_EPS = 2
-- Resource row own_radius fallback when coin/bomb/key Y cannot be measured (= half of 12px step).
local RESOURCE_OWN_RADIUS_DEFAULT = 6
-- Stat / deal row half-height (matches hud_nodes row spacing 12).
local STAT_OWN_RADIUS_DEFAULT = 6
local DEAL_OWN_RADIUS_DEFAULT = 6
-- Active baseline when coins missing; leftover gap still claimed via claim_leftover.
local ACTIVE_MIN_RADIUS = 72

local STAT_IDS = {"speed", "tears", "damage", "range", "shotspeed", "luck"}
local RESOURCE_IDS = {"coins", "bombs", "keys"}
local DEAL_IDS = {"devil", "angel", "planetarium"}
local ACTIVE_SLOTS = {
	ActiveSlot.SLOT_PRIMARY,
	ActiveSlot.SLOT_SECONDARY,
	ActiveSlot.SLOT_POCKET,
}

-- [player_index][slot] = { anchor, scale, trinket_id, frame }
local _trinket_hud = {}
local TRINKET_CACHE_TTL = 4

local function screen_size()
	return ui.GetScreenSize()
end

--- Extra HUD icon scale (same rule as rooted_demon/visual.lua).
--- Style 2 = mini Extra HUD → 0.5; otherwise 1. Not Options HUD zoom.
local function hud_scale()
	return (Options.ExtraHUDStyle or 1) == 2 and 0.5 or 1
end

local function hud_visible(ctx)
	return ctx and ctx.hud_visible == true
end

local function push_target(out, row)
	if not row or not row.anchor then
		return
	end
	out[#out + 1] = row
end

local function get_player_order(player)
	local ok, auxi = pcall(require, "Qing_Remaster_scripts.auxiliary.functions")
	if ok and auxi and auxi.GetPlayerOrder then
		return auxi.GetPlayerOrder(player) or 1
	end
	return 1
end

local function player_is_second(player)
	if not player then
		return false
	end
	if ui.GetPlayerHUDTwinRole then
		local role = ui.GetPlayerHUDTwinRole(player)
		if role == "other" or role == "esau" then
			return true
		end
	end
	return get_player_order(player) == 2
end

local function player_index_key(player)
	local idx = player and player.GetData and player:GetData().__Index
	if idx == nil then
		return nil
	end
	return tostring(idx)
end

local function history_slot_for(player)
	return player_is_second(player) and 1 or 0
end

--- Visible heart HUD slot count (red containers + bone + soul halves + broken).
local function heart_slot_count(player)
	if not player then
		return 1
	end
	local red = math.ceil((player:GetMaxHearts() or 0) / 2)
	local bone = (player.GetBoneHearts and player:GetBoneHearts()) or 0
	local soul = math.ceil((player:GetSoulHearts() or 0) / 2)
	local broken = (player.GetBrokenHearts and player:GetBrokenHearts()) or 0
	local n = red + bone + soul + broken
	if n < 1 then
		n = 1
	end
	-- Vanilla HUD packs at most 12 per "page" visually; keep a sane cap for markers.
	if n > 24 then
		n = 24
	end
	return n
end

local function heart_tune()
	if ui.GetHudIconTuneOffset then
		return ui.GetHudIconTuneOffset("heart")
	end
	return Vector(0, 2)
end

--- One target per heart slot (CENTER + heart tune). own_radius = half slot so
--- adjacent hearts meet at midlines; not one blob at heart0↔heart5 mid (3rd right edge).
local function push_heart_targets(out, player)
	local p_order = player_is_second(player) and 2 or 1
	local n = heart_slot_count(player)
	local tune = heart_tune()
	local own_r = HEART_SLOT * 0.5
	for i = 0, n - 1 do
		local center = ui.UIHeartPos(i, p_order, nil, {anchor = ui.HUD_ANCHOR and ui.HUD_ANCHOR.CENTER})
		if center then
			push_target(out, {
				id = "heart:" .. tostring(i),
				group = "hearts",
				visible = true,
				anchor = center + tune,
				half = HEART_HALF,
				own_radius = own_r,
				owner_player = player,
				heart_index = i,
				heart_count = n,
			})
		end
	end
end

local _minimap_normal_size = nil

local function minimap_region()
	if not Minimap or not Minimap.GetDisplayedSize then
		return nil
	end
	local state = Minimap.GetState and Minimap.GetState() or 0
	local size = Minimap.GetDisplayedSize()
	if state == 0 and size then
		_minimap_normal_size = Vector(size.X, size.Y)
	end
	local use = _minimap_normal_size or size
	if not use then
		return nil
	end
	local shake = Vector(0, 0)
	if Minimap.GetShakeOffset then
		local ok, v = pcall(function()
			return Minimap.GetShakeOffset()
		end)
		if ok and v then
			shake = v
		end
	end
	local ss = screen_size()
	local off = M.minimap_offset
	local top_right = Vector(ss.X + off.X, off.Y) + shake
	local anchor = top_right + Vector(-use.X * 0.5, use.Y * 0.5)
	return {
		id = "minimap",
		group = "minimap",
		visible = true,
		anchor = anchor,
		half = Vector(use.X * 0.5, use.Y * 0.5),
		owner_player = nil,
		minimap_state = state,
		minimap_size = Vector(use.X, use.Y),
	}
end

-- Ketu / Rahu / zodiac: no History orbit nodes (amplify/extract would twitch).
local ORBIT_FORBIDDEN_COLLECTIBLE = {
	[CollectibleType.COLLECTIBLE_ARIES] = true,
	[CollectibleType.COLLECTIBLE_TAURUS] = true,
	[CollectibleType.COLLECTIBLE_GEMINI] = true,
	[CollectibleType.COLLECTIBLE_CANCER] = true,
	[CollectibleType.COLLECTIBLE_LEO] = true,
	[CollectibleType.COLLECTIBLE_VIRGO] = true,
	[CollectibleType.COLLECTIBLE_LIBRA] = true,
	[CollectibleType.COLLECTIBLE_SCORPIO] = true,
	[CollectibleType.COLLECTIBLE_SAGITTARIUS] = true,
	[CollectibleType.COLLECTIBLE_CAPRICORN] = true,
	[CollectibleType.COLLECTIBLE_AQUARIUS] = true,
	[CollectibleType.COLLECTIBLE_PISCES] = true,
}

function M.is_orbit_forbidden_collectible(id)
	id = tonumber(id) or 0
	if id <= 0 then
		return true
	end
	local ketu = enums.Items and enums.Items.Ketu
	local rahu = enums.Items and enums.Items.Rahu
	if (ketu and id == ketu) or (rahu and id == rahu) then
		return true
	end
	return ORBIT_FORBIDDEN_COLLECTIBLE[id] == true
end

local function is_passive_collectible(id)
	id = tonumber(id) or 0
	if id <= 0 then
		return false
	end
	if M.is_orbit_forbidden_collectible(id) then
		return false
	end
	local cfg = Isaac.GetItemConfig():GetCollectible(id)
	if not cfg then
		return false
	end
	if cfg.Type == ItemType.ITEM_ACTIVE then
		return false
	end
	if cfg.HasTags and cfg:HasTags(ItemConfig.TAG_QUEST) then
		return false
	end
	return true
end

--- Cache trinket HUD centers from MC_PRE_PLAYERHUD_TRINKET_RENDER.
--- Position is top-left of 32×32; center = position + (16,16)*scale.
function M.note_trinket_render(player, slot, position, scale, trinket_id)
	local key = player_index_key(player)
	if not key or type(slot) ~= "number" or not position then
		return
	end
	local sc = tonumber(scale) or 1
	local tid = tonumber(trinket_id)
	if (not tid or tid <= 0) and player.GetTrinket then
		tid = player:GetTrinket(slot) or 0
	end
	_trinket_hud[key] = _trinket_hud[key] or {}
	_trinket_hud[key][slot] = {
		anchor = Vector(position.X + 16 * sc, position.Y + 16 * sc),
		scale = sc,
		trinket_id = tid or 0,
		frame = Game():GetFrameCount(),
	}
end

local function push_active_targets(out, player)
	if not player then
		return
	end
	local order = get_player_order(player)
	for i = 1, #ACTIVE_SLOTS do
		local slot = ACTIVE_SLOTS[i]
		local cid = player:GetActiveItem(slot)
		if cid and cid > 0 then
			local anchor = ui.PlayerActiveUIPos(player, slot, order, cid)
			if anchor then
				push_target(out, {
					id = "active:" .. tostring(slot),
					group = "active",
					visible = true,
					anchor = anchor,
					half = ACTIVE_HALF,
					-- Coins keep resource-row length; leftover active↔coins gap → active.
					own_radius = ACTIVE_MIN_RADIUS,
					claim_leftover = true,
					owner_player = player,
					slot = slot,
					item_id = cid,
				})
			end
		end
	end
end

--- Extra HUD History model (corrected):
--- - Layout is a row grid (IncludeNotVisible=true for full offsets).
--- - Each visual ROW owns one orbit interval of ~row_pitch (empty row = blank).
--- - Only the edge-most visible item on that row monopolizes the interval
---   (P1 right HUD → max X; twin/other → min X). Sibling items on the same
---   row do NOT split or share the row arc.
local function history_row_key(y)
	return math.floor((tonumber(y) or 0) / HISTORY_ROW_Y_EPS + 0.5)
end

local function history_prefer_max_x(player)
	-- Right-side Extra HUD: orbit hugs the right edge → rightmost icon.
	-- Left/twin "other" HUD: orbit on the left → leftmost icon.
	return not player_is_second(player)
end

local function measure_row_pitch(ys)
	table.sort(ys)
	local gaps = {}
	for i = 2, #ys do
		local d = ys[i] - ys[i - 1]
		if d > HISTORY_ROW_Y_EPS then
			gaps[#gaps + 1] = d
		end
	end
	if #gaps == 0 then
		return HISTORY_ROW_PITCH_FALLBACK * hud_scale()
	end
	table.sort(gaps)
	return gaps[math.max(1, math.floor((#gaps + 1) / 2))]
end

--- Parse HistoryHUD entries → one target per occupied grid row (edge item only).
local function push_history_edge_rows(out, player, entries, opts)
	opts = opts or {}
	local base = opts.base
	local scale = opts.scale or 1
	local prefer_max = history_prefer_max_x(player)
	local id_prefix = opts.id_prefix or "collectible"
	local group = opts.group or "collectible"
	local half = opts.half or ITEM_HALF
	local accept_id = opts.accept_id -- function(id) -> bool

	local remaining = {}
	local stems = {}
	for i = 1, #entries do
		local entry = entries[i]
		local history_item = entry and entry.GetHistoryItem and entry:GetHistoryItem() or nil
		local id = (history_item and history_item.GetItemID and history_item:GetItemID())
			or (entry and entry.GetItemID and entry:GetItemID())
			or 0
		local time = (history_item and history_item.GetTime and history_item:GetTime()) or 0
		local stem = tostring(id) .. ":" .. tostring(time)
		stems[i] = stem
		remaining[stem] = (remaining[stem] or 0) + 1
	end

	-- bucket[row_key] = { y, edge_candidate or nil, any_layout=true }
	local buckets = {}
	local y_list = {}
	local y_seen = {}

	for i = 1, #entries do
		local entry = entries[i]
		local offset = entry and entry.GetRenderOffset and entry:GetRenderOffset() or nil
		if offset and offset.X == offset.X and offset.Y == offset.Y then
			local rk = history_row_key(offset.Y)
			local bucket = buckets[rk]
			if not bucket then
				bucket = {y = offset.Y, edge = nil}
				buckets[rk] = bucket
			end
			if not y_seen[rk] then
				y_seen[rk] = true
				y_list[#y_list + 1] = offset.Y
			end

			local history_item = entry.GetHistoryItem and entry:GetHistoryItem() or nil
			local id = (history_item and history_item.GetItemID and history_item:GetItemID())
				or (entry.GetItemID and entry:GetItemID())
				or 0
			local stem = stems[i]
			local occurrence = remaining[stem] or 1
			remaining[stem] = occurrence - 1

			local visible = entry.IsVisible and entry:IsVisible()
			local ok_id = accept_id and accept_id(id) or (id > 0)
			if visible and ok_id then
				local anchor = base + offset + Vector(16, 16) * scale
				local cand = {
					id = id_prefix .. ":" .. stem .. ":" .. tostring(occurrence),
					group = group,
					visible = true,
					anchor = anchor,
					half = half,
					owner_player = player,
					item_id = id,
					history_time = (history_item and history_item.GetTime and history_item:GetTime()) or 0,
					history_occurrence = occurrence,
					history_row = rk,
				}
				if group == "smelted_trinket" then
					cand.trinket_id = id
				end
				local prev = bucket.edge
				if not prev then
					bucket.edge = cand
				elseif prefer_max then
					if cand.anchor.X > prev.anchor.X then
						bucket.edge = cand
					end
				else
					if cand.anchor.X < prev.anchor.X then
						bucket.edge = cand
					end
				end
			end
		else
			local stem = stems[i]
			if stem and remaining[stem] then
				remaining[stem] = remaining[stem] - 1
			end
		end
	end

	local pitch = measure_row_pitch(y_list)
	local own_r = math.max(3, pitch * 0.5 * HISTORY_ROW_FILL)

	-- Emit only occupied rows (edge item). Empty grid rows → no target → blank arc.
	local occupied = {}
	for _, bucket in pairs(buckets) do
		if bucket.edge then
			bucket.edge.own_radius = own_r
			occupied[#occupied + 1] = bucket.edge
		end
	end
	table.sort(occupied, function(a, b)
		return a.anchor.Y < b.anchor.Y
	end)
	for i = 1, #occupied do
		push_target(out, occupied[i])
	end
end

local function push_history_targets(out, player)
	if not REPENTOGON or not player then
		return
	end
	if (Options.ExtraHUDStyle or 0) <= 0 then
		return
	end
	local hud = Game():GetHUD()
	if not hud or not hud.IsVisible or not hud:IsVisible() then
		return
	end
	if not hud.GetHistoryHUD then
		return
	end
	local history_hud = hud:GetHistoryHUD()
	if not history_hud then
		return
	end
	local base = history_hud:GetPosition()
	if not base then
		return
	end
	local hslot = history_slot_for(player)
	local scale = hud_scale()

	if history_hud.GetCollectibles then
		local ok, entries = pcall(function()
			return history_hud:GetCollectibles(hslot, nil, true)
		end)
		if ok and type(entries) == "table" then
			push_history_edge_rows(out, player, entries, {
				base = base,
				scale = scale,
				id_prefix = "collectible",
				group = "collectible",
				half = ITEM_HALF,
				accept_id = is_passive_collectible,
			})
		end
	end

	if history_hud.GetTrinkets then
		local ok, entries = pcall(function()
			return history_hud:GetTrinkets(hslot, nil, true)
		end)
		if ok and type(entries) == "table" then
			push_history_edge_rows(out, player, entries, {
				base = base,
				scale = scale,
				id_prefix = "smelted",
				group = "smelted_trinket",
				half = TRINKET_HALF,
				accept_id = function(id)
					return (tonumber(id) or 0) > 0
				end,
			})
		end
	end
end

local function push_physical_trinket_targets(out, player)
	local key = player_index_key(player)
	if not key then
		return
	end
	local bag = _trinket_hud[key]
	if not bag then
		return
	end
	local now = Game():GetFrameCount()
	for slot = 0, 1 do
		local row = bag[slot]
		if row and row.anchor and (now - (row.frame or 0)) <= TRINKET_CACHE_TTL then
			local tid = tonumber(row.trinket_id) or 0
			if tid <= 0 and player.GetTrinket then
				tid = player:GetTrinket(slot) or 0
			end
			if tid > 0 then
				push_target(out, {
					id = "trinket_slot:" .. tostring(slot),
					group = "trinket",
					visible = true,
					anchor = Vector(row.anchor.X, row.anchor.Y),
					half = TRINKET_HALF,
					own_radius = M.trinket_own_radius,
					owner_player = player,
					slot = slot,
					trinket_id = tid,
					item_id = tid,
				})
			end
		end
	end
end

--- Resources share one row length; active claims leftover above coins; deals capped.
local function refine_orbit_radii(out)
	local by_id = {}
	for i = 1, #out do
		local t = out[i]
		if t and t.id then
			by_id[t.id] = t
		end
	end
	local coins = by_id.coins
	local bombs = by_id.bombs
	local keys = by_id.keys
	local res_r = RESOURCE_OWN_RADIUS_DEFAULT
	local function y_half(a, b)
		if a and a.anchor and b and b.anchor then
			return math.abs(a.anchor.Y - b.anchor.Y) * 0.5
		end
		return nil
	end
	local h1 = y_half(coins, bombs)
	local h2 = y_half(bombs, keys)
	if h1 and h2 then
		res_r = math.min(h1, h2)
	elseif h1 then
		res_r = h1
	elseif h2 then
		res_r = h2
	end
	res_r = math.max(3, res_r)

	for i = 1, #out do
		local t = out[i]
		if not t then
			-- skip
		elseif t.group == "resource" then
			-- Coins == bombs == keys length; do NOT mid-split with active.
			t.own_radius = res_r
		elseif t.group == "active" and t.anchor then
			-- Keep a floor; claim_leftover eats the unused active↔coins middle.
			t.own_radius = math.max(ACTIVE_MIN_RADIUS, res_r)
			t.claim_leftover = true
		elseif t.group == "trinket" then
			t.own_radius = math.max(1, tonumber(M.trinket_own_radius) or 5)
		elseif t.group == "stat" then
			t.own_radius = STAT_OWN_RADIUS_DEFAULT
		elseif t.group == "deal" then
			-- Planetarium matches devil/angel; do not half-eat the big gap below.
			t.own_radius = DEAL_OWN_RADIUS_DEFAULT
		end
	end
end

--- Snapshot currently visible HUD targets for one player (or P1 layout).
function M.snapshot(player)
	local out = {}
	local ctx = hud_nodes.get_hud_context(player)
	if not hud_visible(ctx) then
		return out, ctx
	end

	push_heart_targets(out, player)

	-- Resource ICON slots (琉璃炸弹 UIBombPos / ui.UI*Pos TOP_LEFT), NOT 妖刀
	-- resource_value_offset which targets current/max number text (+8,-7).
	local res_state = auxi.is_double_player() and 2 or 1
	for _, id in ipairs(RESOURCE_IDS) do
		if hud_nodes.is_node_navigable(id, ctx) then
			local kind = (id == "coins" and "coin") or (id == "bombs" and "bomb") or "key"
			-- TOP_LEFT = glaze bomb Render; equals CENTER+(8,8)+HUD_ICON_TUNE(-8,-8).
			local anchor = ui.UI_Pos(kind, res_state)
			if anchor then
				push_target(out, {
					id = id,
					group = "resource",
					visible = true,
					anchor = anchor,
					half = RESOURCE_HALF,
					own_radius = RESOURCE_OWN_RADIUS_DEFAULT,
					owner_player = player,
				})
			end
		end
	end

	if ctx.found_hud then
		local col_off = M.stat_column_offset or Vector(0, 0)
		for _, id in ipairs(STAT_IDS) do
			if hud_nodes.is_node_navigable(id, ctx) then
				local anchor = hud_nodes.get_stat_display_anchor(id, {
					player = player,
					include_shake = true,
				})
				if anchor then
					push_target(out, {
						id = id,
						group = "stat",
						visible = true,
						anchor = anchor + col_off,
						half = STAT_HALF,
						own_radius = STAT_OWN_RADIUS_DEFAULT,
						owner_player = player,
					})
				end
			end
		end
		for _, id in ipairs(DEAL_IDS) do
			if hud_nodes.is_node_navigable(id, ctx) then
				local idx = hud_nodes.get_deal_row_index(id)
				local anchor = hud_nodes.get_deal_hud_anchor(idx, player)
				if anchor then
					push_target(out, {
						id = id,
						group = "deal",
						visible = true,
						anchor = anchor + col_off,
						half = DEAL_HALF,
						own_radius = DEAL_OWN_RADIUS_DEFAULT,
						owner_player = player,
					})
				end
			end
		end
	end

	local map = minimap_region()
	if map then
		push_target(out, map)
	end

	push_active_targets(out, player)
	push_history_targets(out, player)
	push_physical_trinket_targets(out, player)
	refine_orbit_radii(out)

	return out, ctx
end

function M.default_radius_frac()
	return DEFAULT_RADIUS_FRAC
end

function M.set_minimap_offset(x, y)
	M.minimap_offset = Vector(tonumber(x) or M.minimap_offset.X, tonumber(y) or M.minimap_offset.Y)
end

function M.set_stat_column_offset(x, y)
	M.stat_column_offset = Vector(
		tonumber(x) or (M.stat_column_offset and M.stat_column_offset.X) or 0,
		tonumber(y) or (M.stat_column_offset and M.stat_column_offset.Y) or 0
	)
end

function M.set_trinket_own_radius(v)
	M.trinket_own_radius = math.max(1, tonumber(v) or M.trinket_own_radius or 5)
end

return M
