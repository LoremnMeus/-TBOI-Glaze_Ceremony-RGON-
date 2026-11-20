-- HistoryHUD native icon proxy: exclusive ownership + composable sprite modifiers.
--
-- Consumer contract:
-- 1. register_consumer once (mod lifetime).
-- 2. On each HistoryHUD PRE, collect() re-declares exclusive / modifier for THIS render only.
-- 3. Exclusive owners MUST paint via get_context / apply_to_sprite (or claim-only and
--    paint later with compose_visual). Never hide+self-draw outside this holder.
-- 4. Only claim exclusive for slots the consumer will actually redraw this cycle.
--    Invisible HistoryHUD slots need no exclusive claim.
-- 5. HideCollectibles/HideTrinkets are ID-level (RGON); holder redraws every sibling
--    slot of a hidden ID unless an exclusive owner claimed that exact slot.
--
-- Modifier merge (applied in sorted order: priority asc, consumer name, declare seq):
--   alpha_mul / scale_mul : multiply into the running visual
--   color / Colorize      : last writer wins (set priority deliberately)
--   rotation              : not composed here; pass opts.rotation on apply/render
--   custom fields         : allowed on visual.*; do not silently overwrite others' keys
-- declare.exclusive returns { claimed = {slots...}, rejected = {{slot, owner}, ...} }.
--
-- apply_to_sprite scale is absolute per call:
--   opts.base_scale (number|Vector) = pre-modifier scale for THIS draw
--   final Scale = base_scale * visual.scale_mul * (opts.scale_mul or 1)
--   Do not rely on mutating sprite.Scale across frames.
--
-- Does NOT own: temp Extra HUD append (temp_item_hud_holder), physical trinket slots.

local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
	myToCall = {},
	own_key = "HistoryHudRender_",
	consumers = {},
}

local DEFAULT_HISTORY_ALPHA = 1
local _txn = nil
local _last_visuals = {}
local _last_layout = {}
local _sprite_cache = {collectible = {}, trinket = {}}

local function hud_scale()
	return (Options.ExtraHUDStyle or 1) == 2 and 0.5 or 1
end

local function player_index_of(player)
	if not player then
		return nil
	end
	local data = player.GetData and player:GetData()
	local idx = data and data.__Index
	if idx ~= nil then
		return idx
	end
	for _, other in ipairs(auxi.GetPlayers()) do
		if GetPtrHash(other) == GetPtrHash(player) then
			local od = other:GetData()
			return od and od.__Index
		end
	end
	return nil
end

local function trinket_base(id)
	id = tonumber(id) or 0
	return id & 0x7FFF
end

local function slot_key(slot)
	return table.concat({
		tostring(slot.player_index),
		tostring(slot.kind),
		tostring(slot.id),
		tostring(slot.history_time),
		tostring(slot.occurrence),
	}, "|")
end

local function make_visual()
	return {
		color = Color(1, 1, 1, DEFAULT_HISTORY_ALPHA),
		alpha_mul = 1,
		scale_mul = 1,
		consumers = {},
	}
end

local function read_colorize(c)
	if not c then
		return 0, 0, 0, 0
	end
	if c.GetColorize then
		local t = c:GetColorize()
		if t then
			return t.R or t[1] or 0, t.G or t[2] or 0, t.B or t[3] or 0, t.A or t[4] or 0
		end
	end
	return c.RC or 0, c.GC or 0, c.BC or 0, c.AC or 0
end

local function clone_color(c, alpha_mul)
	alpha_mul = tonumber(alpha_mul) or 1
	if not c then
		return Color(1, 1, 1, alpha_mul)
	end
	local col = Color(
		c.R or 1, c.G or 1, c.B or 1, (c.A or 1) * alpha_mul,
		c.RO or 0, c.GO or 0, c.BO or 0
	)
	local rc, gc, bc, ac = read_colorize(c)
	if col.SetColorize then
		col:SetColorize(rc, gc, bc, ac)
	end
	return col
end

local function copy_visual(src)
	if not src then
		return make_visual()
	end
	local consumers = {}
	if type(src.consumers) == "table" then
		for i = 1, #src.consumers do
			consumers[i] = src.consumers[i]
		end
	end
	return {
		color = clone_color(src.color, 1),
		alpha_mul = tonumber(src.alpha_mul) or 1,
		scale_mul = tonumber(src.scale_mul) or 1,
		consumers = consumers,
	}
end

local function match_filter(slot, filter)
	if type(filter) ~= "table" then
		return false
	end
	if filter.kind and filter.kind ~= slot.kind then
		return false
	end
	if filter.player_index ~= nil and filter.player_index ~= slot.player_index then
		return false
	end
	if filter.history_slot ~= nil and filter.history_slot ~= slot.history_slot then
		return false
	end
	local fid = tonumber(filter.id)
	if fid then
		if slot.kind == "trinket" then
			if trinket_base(slot.id) ~= trinket_base(fid) then
				return false
			end
		elseif slot.id ~= fid then
			return false
		end
	end
	if filter.history_time ~= nil and filter.history_time ~= slot.history_time then
		return false
	end
	if filter.occurrence ~= nil and filter.occurrence ~= slot.occurrence then
		return false
	end
	return true
end

local function find_slots(slots, filter)
	local out = {}
	for i = 1, #slots do
		if match_filter(slots[i], filter) then
			out[#out + 1] = slots[i]
		end
	end
	return out
end

local function load_collectible_sprite(id)
	id = tonumber(id) or 0
	if id <= 0 then
		return nil
	end
	local cached = _sprite_cache.collectible[id]
	if cached then
		return cached
	end
	local s = Sprite()
	s:Load("gfx/mimics/Rooted_Demon/flying_icon.anm2", true)
	if EntityPickup and EntityPickup.SetupCollectibleGraphics then
		EntityPickup.SetupCollectibleGraphics(s, 0, id, false, 1, true)
	else
		local cfg = Isaac.GetItemConfig():GetCollectible(id)
		if cfg and cfg.GfxFileName then
			s:ReplaceSpritesheet(0, cfg.GfxFileName)
			s:LoadGraphics()
		end
	end
	s:Play("Idle", true)
	_sprite_cache.collectible[id] = s
	return s
end

local function load_trinket_sprite(id)
	local base = trinket_base(id)
	if base <= 0 then
		return nil
	end
	local cached = _sprite_cache.trinket[base]
	if cached then
		return cached
	end
	local s = Sprite()
	s:Load("gfx/mimics/Rooted_Demon/flying_icon.anm2", true)
	local cfg = Isaac.GetItemConfig():GetTrinket(base)
	if cfg and cfg.GfxFileName then
		s:ReplaceSpritesheet(0, cfg.GfxFileName)
		s:LoadGraphics()
	end
	s:Play("Idle", true)
	_sprite_cache.trinket[base] = s
	return s
end

local function resolve_base_scale(opts)
	opts = opts or {}
	local base = opts.base_scale
	if base ~= nil then
		if type(base) == "number" then
			return base, base
		end
		if type(base) == "userdata" or type(base) == "table" then
			local x = tonumber(base.X) or tonumber(base[1])
			local y = tonumber(base.Y) or tonumber(base[2]) or x
			if x then
				return x, y or x
			end
		end
	end
	-- Legacy: opts.scale as uniform absolute base (not current sprite.Scale).
	local uniform = tonumber(opts.scale) or hud_scale()
	return uniform, uniform
end

local function apply_visual_to_sprite(sprite, visual, opts)
	if not sprite or not visual then
		return
	end
	opts = opts or {}
	local alpha_mul = (tonumber(visual.alpha_mul) or 1) * (tonumber(opts.alpha_mul) or 1)
	local scale_mul = (tonumber(visual.scale_mul) or 1) * (tonumber(opts.scale_mul) or 1)
	sprite.Color = clone_color(visual.color, alpha_mul)
	local base_x, base_y = resolve_base_scale(opts)
	-- Absolute for this call: never multiply the sprite's previous Scale in place.
	sprite.Scale = Vector(base_x * scale_mul, base_y * scale_mul)
	if opts.rotation ~= nil then
		sprite.Rotation = tonumber(opts.rotation) or 0
	end
end

local function build_ctx(slot)
	local ctx = {
		player = slot.player,
		player_index = slot.player_index,
		kind = slot.kind,
		id = slot.id,
		history_time = slot.history_time,
		occurrence = slot.occurrence,
		history_slot = slot.history_slot,
		entry_index = slot.entry_index,
		visible = slot.visible,
		render_offset = slot.render_offset,
		center = slot.center,
		scale = slot.scale,
		visual = slot.visual,
		slot_key = slot.key,
	}
	function ctx:render(sprite, position, opts)
		opts = opts or {}
		apply_visual_to_sprite(sprite, self.visual, opts)
		local pos = position or self.center
		if sprite and pos then
			sprite:Render(pos, Vector.Zero, Vector.Zero)
		end
		if _txn then
			_txn.rendered[self.slot_key] = true
		end
	end
	return ctx
end

local function collect_entries(history_hud, history_slot, kind, render_pos, scale)
	local player = history_hud.GetPlayer and history_hud:GetPlayer(history_slot) or nil
	if not player and history_slot == 0 then
		player = Isaac.GetPlayer(0)
	end
	if not player then
		return {}, player, nil
	end
	local pindex = player_index_of(player)
	local ok, entries
	if kind == "collectible" then
		ok, entries = pcall(function()
			return history_hud:GetCollectibles(history_slot, nil, true)
		end)
	else
		ok, entries = pcall(function()
			return history_hud:GetTrinkets(history_slot, nil, true)
		end)
	end
	if not ok or type(entries) ~= "table" then
		return {}, player, pindex
	end

	local remaining, stems = {}, {}
	for i = 1, #entries do
		local entry = entries[i]
		local hi = entry and entry.GetHistoryItem and entry:GetHistoryItem() or nil
		local id = (hi and hi.GetItemID and hi:GetItemID())
			or (entry and entry.GetItemID and entry:GetItemID())
			or 0
		if kind == "trinket" then
			id = trinket_base(id)
		end
		local time = (hi and hi.GetTime and hi:GetTime()) or 0
		local stem = tostring(id) .. ":" .. tostring(time)
		stems[i] = {id = id, time = time, stem = stem}
		remaining[stem] = (remaining[stem] or 0) + 1
	end

	local slots = {}
	for i = 1, #entries do
		local entry = entries[i]
		local meta = stems[i]
		local occurrence = remaining[meta.stem] or 1
		remaining[meta.stem] = occurrence - 1
		local offset = entry.GetRenderOffset and entry:GetRenderOffset() or Vector.Zero
		local visible = entry.IsVisible and entry:IsVisible() or false
		local center = render_pos + offset + Vector(16, 16) * scale
		local slot = {
			player = player,
			player_index = pindex,
			kind = kind,
			id = meta.id,
			history_time = meta.time,
			occurrence = occurrence,
			history_slot = history_slot,
			entry_index = i,
			visible = visible,
			render_offset = offset,
			center = center,
			scale = scale,
			entry = entry,
		}
		slot.key = slot_key(slot)
		slot.visual = make_visual()
		slots[#slots + 1] = slot
	end
	return slots, player, pindex
end

local function begin_txn(history_hud, render_pos)
	local scale = hud_scale()
	local base = render_pos or (history_hud.GetPosition and history_hud:GetPosition()) or Vector.Zero
	local slots = {}
	local by_key = {}
	local layout = {}

	for hslot = 0, 1 do
		for _, kind in ipairs({"collectible", "trinket"}) do
			local part = collect_entries(history_hud, hslot, kind, base, scale)
			for i = 1, #part do
				local slot = part[i]
				slots[#slots + 1] = slot
				by_key[slot.key] = slot
				if slot.player_index ~= nil then
					local lay = layout[slot.player_index]
					if not lay then
						lay = {frame = Game():GetFrameCount(), positions = {}, visible = {}, rows = {}}
						layout[slot.player_index] = lay
					end
					local id_key = table.concat({slot.id, slot.history_time, slot.occurrence}, ":")
					lay.positions[id_key] = slot.center
					lay.visible[id_key] = slot.visible
					lay.rows[#lay.rows + 1] = {
						id = slot.id,
						key = id_key,
						pos = slot.center,
						visible = slot.visible,
						kind = slot.kind,
					}
				end
			end
		end
	end

	_txn = {
		history_hud = history_hud,
		render_pos = base,
		scale = scale,
		slots = slots,
		by_key = by_key,
		layout = layout,
		exclusive = {}, -- key -> {consumer, render}
		modifiers = {}, -- {filter, fn, consumer, priority}
		hide_collectibles = {},
		hide_trinkets = {},
		rendered = {},
		fallback_scheduled = {},
	}
	return _txn
end

local function make_declare(txn, consumer_name)
	local declare = {}
	local declare_seq = 0

	function declare.exclusive(slot_or_filter, opts)
		opts = opts or {}
		local targets
		if type(slot_or_filter) == "table" and slot_or_filter.key and txn.by_key[slot_or_filter.key] then
			targets = {txn.by_key[slot_or_filter.key]}
		else
			targets = find_slots(txn.slots, slot_or_filter)
		end
		local result = {claimed = {}, rejected = {}}
		for i = 1, #targets do
			local slot = targets[i]
			local existing = txn.exclusive[slot.key]
			if existing and existing.consumer ~= consumer_name then
				-- First exclusive wins; later claims rejected (deterministic).
				result.rejected[#result.rejected + 1] = {
					slot = slot,
					owner = existing.consumer,
				}
			else
				txn.exclusive[slot.key] = {
					consumer = consumer_name,
					render = opts.render,
					slot = slot,
				}
				result.claimed[#result.claimed + 1] = slot
			end
		end
		return result
	end

	function declare.modifier(slot_or_filter, modifier_fn, priority)
		if type(modifier_fn) ~= "function" then
			return
		end
		declare_seq = declare_seq + 1
		txn.modifiers[#txn.modifiers + 1] = {
			filter = slot_or_filter,
			fn = modifier_fn,
			consumer = consumer_name,
			priority = tonumber(priority) or 0,
			seq = declare_seq,
		}
	end

	return declare
end

local function ask_consumers(txn)
	local names = {}
	for name, def in pairs(item.consumers) do
		if def and type(def.collect) == "function" then
			names[#names + 1] = {name = name, priority = tonumber(def.priority) or 0}
		end
	end
	table.sort(names, function(a, b)
		if a.priority == b.priority then
			return a.name < b.name
		end
		return a.priority < b.priority
	end)

	local collect_ctx = {
		history_hud = txn.history_hud,
		render_pos = txn.render_pos,
		scale = txn.scale,
		slots = txn.slots,
		find_slots = function(filter)
			return find_slots(txn.slots, filter)
		end,
	}

	for i = 1, #names do
		local name = names[i].name
		local def = item.consumers[name]
		local ok, err = pcall(def.collect, collect_ctx, make_declare(txn, name))
		if not ok then
			print("[HistoryHudRender] consumer collect failed:", name, err)
		end
	end
end

local function compose_modifiers(txn)
	table.sort(txn.modifiers, function(a, b)
		if a.priority ~= b.priority then
			return a.priority < b.priority
		end
		if a.consumer ~= b.consumer then
			return tostring(a.consumer) < tostring(b.consumer)
		end
		return (a.seq or 0) < (b.seq or 0)
	end)
	for i = 1, #txn.modifiers do
		local mod = txn.modifiers[i]
		local targets
		if type(mod.filter) == "table" and mod.filter.key and txn.by_key[mod.filter.key] then
			targets = {txn.by_key[mod.filter.key]}
		else
			targets = find_slots(txn.slots, mod.filter)
		end
		for t = 1, #targets do
			local slot = targets[t]
			local ctx = build_ctx(slot)
			local ok, err = pcall(mod.fn, ctx, slot.visual)
			if ok then
				-- Contract: alpha_mul/scale_mul should multiply the running value;
				-- color/Colorize is last-writer-wins under the sort above.
				slot.visual.consumers[#slot.visual.consumers + 1] = mod.consumer
				slot.needs_proxy = true
			else
				print("[HistoryHudRender] modifier failed:", mod.consumer, err)
			end
		end
	end
end

local function mark_proxy_ids(txn)
	local seen_c, seen_t = {}, {}
	local hide_c, hide_t = {}, {}

	local function hide_id(kind, id)
		id = tonumber(id) or 0
		if id <= 0 then
			return
		end
		if kind == "trinket" then
			id = trinket_base(id)
			if not seen_t[id] then
				seen_t[id] = true
				hide_t[#hide_t + 1] = id
			end
		else
			if not seen_c[id] then
				seen_c[id] = true
				hide_c[#hide_c + 1] = id
			end
		end
	end

	for key, ex in pairs(txn.exclusive) do
		local slot = ex.slot
		slot.needs_proxy = true
		hide_id(slot.kind, slot.id)
	end
	for i = 1, #txn.slots do
		local slot = txn.slots[i]
		if slot.needs_proxy then
			hide_id(slot.kind, slot.id)
		end
	end

	-- Any slot whose ID is hidden must be proxied (sibling restore), even with no modifiers.
	local hide_c_set, hide_t_set = {}, {}
	for i = 1, #hide_c do hide_c_set[hide_c[i]] = true end
	for i = 1, #hide_t do hide_t_set[hide_t[i]] = true end
	for i = 1, #txn.slots do
		local slot = txn.slots[i]
		local id = slot.kind == "trinket" and trinket_base(slot.id) or slot.id
		if (slot.kind == "trinket" and hide_t_set[id]) or (slot.kind == "collectible" and hide_c_set[id]) then
			slot.needs_proxy = true
		end
	end

	txn.hide_collectibles = hide_c
	txn.hide_trinkets = hide_t
	txn.hide_c_set = hide_c_set
	txn.hide_t_set = hide_t_set
end

local function publish_last_visuals(txn)
	_last_visuals = {}
	for i = 1, #txn.slots do
		local slot = txn.slots[i]
		_last_visuals[slot.key] = copy_visual(slot.visual)
	end
	for pindex, lay in pairs(txn.layout) do
		_last_layout[pindex] = lay
	end
end

local function end_txn()
	_txn = nil
end

--- Persistent consumer registration.
-- def = { collect = function(context, declare) ... end, priority = number? }
function item.register_consumer(name, def)
	if type(name) ~= "string" or name == "" or type(def) ~= "table" or type(def.collect) ~= "function" then
		return false
	end
	item.consumers[name] = {
		collect = def.collect,
		priority = tonumber(def.priority) or 0,
	}
	return true
end

function item.unregister_consumer(name)
	item.consumers[name] = nil
end

--- Current render-transaction context for a slot. Nil outside PRE/POST pair.
function item.get_context(slot_or_key)
	if not _txn then
		return nil
	end
	local slot
	if type(slot_or_key) == "string" then
		slot = _txn.by_key[slot_or_key]
	elseif type(slot_or_key) == "table" then
		if slot_or_key.key and _txn.by_key[slot_or_key.key] then
			slot = _txn.by_key[slot_or_key.key]
		else
			local found = find_slots(_txn.slots, slot_or_key)
			slot = found[1]
		end
	end
	if not slot then
		return nil
	end
	return build_ctx(slot)
end

--- Composed visual for a history identity (txn preferred, else last PRE snapshot).
function item.compose_visual(slot_ref)
	if type(slot_ref) ~= "table" then
		return make_visual()
	end
	local key = slot_ref.key or slot_key(slot_ref)
	if _txn and _txn.by_key[key] then
		return copy_visual(_txn.by_key[key].visual)
	end
	if _last_visuals[key] then
		return copy_visual(_last_visuals[key])
	end
	-- Fuzzy: match without requiring exact key field names from callers.
	local probe = {
		player_index = slot_ref.player_index,
		kind = slot_ref.kind or "collectible",
		id = slot_ref.id,
		history_time = slot_ref.history_time or slot_ref.time,
		occurrence = slot_ref.occurrence,
	}
	key = slot_key(probe)
	if _txn and _txn.by_key[key] then
		return copy_visual(_txn.by_key[key].visual)
	end
	if _last_visuals[key] then
		return copy_visual(_last_visuals[key])
	end
	return make_visual()
end

function item.apply_to_sprite(sprite, slot_ref, opts)
	local visual = item.compose_visual(slot_ref)
	apply_visual_to_sprite(sprite, visual, opts)
	return visual
end

--- Layout snapshot for Rooted Demon anchors (player_index -> positions/visible).
function item.get_layout(player_index)
	local lay = _last_layout[player_index]
	if lay and Game():GetFrameCount() - (lay.frame or 0) <= 4 then
		return lay
	end
end

function item.slot_identity(player_index, kind, id, history_time, occurrence)
	return slot_key({
		player_index = player_index,
		kind = kind or "collectible",
		id = id,
		history_time = history_time,
		occurrence = occurrence,
	})
end

local function draw_fallback_slot(slot)
	if not slot.visible then
		return
	end
	local sprite
	if slot.kind == "trinket" then
		sprite = load_trinket_sprite(slot.id)
	else
		sprite = load_collectible_sprite(slot.id)
	end
	if not sprite then
		return
	end
	local ctx = build_ctx(slot)
	ctx:render(sprite, slot.center, {scale = slot.scale})
	if _txn then
		_txn.fallback_scheduled[slot.key] = true
	end
end

local _hide_pending = false

local function post_draw(txn)
	-- Exclusive owners with render callbacks first.
	for key, ex in pairs(txn.exclusive) do
		if type(ex.render) == "function" then
			local ctx = build_ctx(ex.slot)
			local ok, err = pcall(ex.render, ctx)
			if not ok then
				print("[HistoryHudRender] exclusive render failed:", ex.consumer, err)
			else
				txn.rendered[key] = true
			end
		else
			-- Claim-only exclusive: consumer paints elsewhere; mark as handled.
			txn.rendered[key] = true
		end
	end
	-- Fallback: every proxied visible slot not exclusively handled.
	for i = 1, #txn.slots do
		local slot = txn.slots[i]
		if slot.needs_proxy and slot.visible and not txn.rendered[slot.key] then
			draw_fallback_slot(slot)
		end
	end
end

if REPENTOGON and ModCallbacks.MC_PRE_HISTORYHUD_RENDER then
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_PRE_HISTORYHUD_RENDER,
		params = nil,
		priority = -1000, -- before item consumers; sole Qing hide authority
		Function = function(_, history_hud, render_pos)
			if _hide_pending then
				_hide_pending = false
			end
			-- New PRE always discards unfinished prior txn.
			end_txn()
			if not history_hud then
				return
			end
			local hud = Game():GetHUD()
			if not hud or not hud:IsVisible() or (Options.ExtraHUDStyle or 0) <= 0 then
				return
			end
			local txn = begin_txn(history_hud, render_pos)
			ask_consumers(txn)
			compose_modifiers(txn)
			mark_proxy_ids(txn)
			publish_last_visuals(txn)
			if #txn.hide_collectibles == 0 and #txn.hide_trinkets == 0 then
				-- Keep visuals/layout published; no hide needed.
				end_txn()
				return
			end
			_hide_pending = true
			return {
				HideCollectibles = txn.hide_collectibles,
				HideTrinkets = txn.hide_trinkets,
			}
		end,
	})
end

if REPENTOGON and ModCallbacks.MC_POST_HISTORYHUD_RENDER then
	table.insert(item.ToCall, #item.ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_HISTORYHUD_RENDER,
		params = nil,
		priority = -1000,
		Function = function(_, _history_hud, _render_pos)
			local txn = _txn
			if not _hide_pending then
				end_txn()
				return
			end
			_hide_pending = false
			if not txn then
				end_txn()
				return
			end
			-- PRE and POST each receive a new HistoryHUD wrapper. Comparing
			-- them with ~= drops the redraw after HideCollectibles has already
			-- removed the native icons. _hide_pending is the pair token.
			post_draw(txn)
			end_txn()
		end,
	})
end

return item
