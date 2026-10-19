-- Blueprint editor: inventory projection, slots, confirm, drag-drop.
-- Structural extract from Item_Blue_Print.lua. Callers keep requiring the item façade.
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local enums = require("Qing_Remaster_scripts.core.enums")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local Mouse_UI = require("Qing_Remaster_scripts.others.Mouse_UI_holder")
local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")
local CraftIdentity = require("Qing_Remaster_scripts.mimics.craft_identity")
local Imitate_item_holder = require("Qing_Remaster_scripts.callbacks.imitate_item_holder")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")

local M = {}

function M.attach(item, BP)

function BP.rec_loadout_ids(rec)
	local base_id = nil
	local mods = {}
	local mirror_id = nil
	if not rec then return base_id, mods, mirror_id end
	for _, entry in ipairs(rec.cost_items or {}) do
		local id = CraftProfile.ingredient_id(entry)
		if id and id > 0 then
			if not base_id then
				base_id = id
			else
				mods[#mods + 1] = id
			end
		end
	end
	local keys = {}
	for k, _ in pairs(rec.ingredients or {}) do
		local idx = tonumber(k) or k
		if type(idx) == "number" then keys[#keys + 1] = idx end
	end
	table.sort(keys)
	for _, k in ipairs(keys) do
		local entry = rec.ingredients[k] or rec.ingredients[tostring(k)]
		local id = CraftProfile.ingredient_id(entry)
		if id and id > 0 then mods[#mods + 1] = id end
	end
	if rec.mirror_module then
		local mid = CraftProfile.ingredient_id(rec.mirror_module)
		if mid and mid > 0 then mirror_id = mid end
	end
	return base_id, mods, mirror_id
end

--- 规范背包格 id（bag_/all_）；底座/槽位归还后的 inst_/costfill_/slotfill_ 不算
function BP.is_canonical_bag_token_id(tid)
	if type(tid) ~= "string" then return false end
	return tid:sub(1, 4) == "bag_" or tid:sub(1, 4) == "all_"
end

--- 底座/材料归还时保留的孤儿 token：认领进当前页背包格，避免「原件 + 库存补货」双显
function BP.claim_orphan_bag_token(kept, kept_map, col, is_proto, proto_uid)
	if not kept or not kept_map or not col then return nil end
	for _, tok in ipairs(kept) do
		if tok and tok.from_bag and not tok.slot and not tok.cost and not tok.mirror_slot
			and not tok.lost_ghost and not BP.is_canonical_bag_token_id(tok.id)
			and kept_map[tok.id] == tok
		then
			local match = false
			if is_proto then
				match = tok.is_prototype and tok.prototype_uid ~= nil
					and (tok.prototype_uid == proto_uid or tostring(tok.prototype_uid) == tostring(proto_uid))
			else
				match = (not tok.is_prototype) and tok.collectible == col
			end
			if match then return tok end
		end
	end
	return nil
end


local BAG_SKIP = nil
function BP.bag_skip_ids()
	if BAG_SKIP then return BAG_SKIP end
	BAG_SKIP = {
		[item.entity] = true,
		[enums.Items.Air_Flight] = true,
		[enums.Items.Air_Terror] = true,
		-- Gemini 已重新开放蓝图材料通道（探针采集期间需要可装配）。
	}
	return BAG_SKIP
end

function BP.collectible_eligible(col)
	return col and not col.Hidden
		and (col.Type == ItemType.ITEM_PASSIVE or col.Type == ItemType.ITEM_FAMILIAR or col.Type == ItemType.ITEM_ACTIVE)
end

-- ---------- 背包收集（真实持有 − 已分配给其他飞行器 − 当前槽占用）+ 空闲原型----------
-- 返回混合列表：number（真实）或 {collectible, source="prototype", prototype_uid}
function BP.collect_bag_items(player, exclude_uid, slot_reserve)
	local list = {}
	local used = item.count_allocated(player, exclude_uid)
	local reserve_real = slot_reserve and slot_reserve.real or slot_reserve or {}
	for id, n in pairs(reserve_real) do
		if type(id) == "number" or tonumber(id) then
			local nid = tonumber(id) or id
			used[nid] = (used[nid] or 0) + n
		end
	end
	local config = Isaac.GetItemConfig()
	local size = config:GetCollectibles().Size
	local skip = BP.bag_skip_ids()
	for id = 1, size do
		if not skip[id] then
			local col = config:GetCollectible(id)
			if BP.collectible_eligible(col) then
				local num = player:GetCollectibleNum(id, true) - (used[id] or 0)
				for _ = 1, num do
					table.insert(list, id)
				end
			end
		end
	end
	local reserved_proto = slot_reserve and slot_reserve.proto or {}
	for _, entry in ipairs(item.list_free_prototypes(player, exclude_uid)) do
		local uid = entry.prototype_uid
		if not reserved_proto[uid] and not reserved_proto[tostring(uid)] then
			list[#list + 1] = entry
		end
	end
	return list
end

function BP.bag_entry_collectible(entry)
	if type(entry) == "table" then return entry.collectible or entry.id end
	return entry
end

function BP.bag_entry_is_proto(entry)
	return type(entry) == "table" and entry.source == "prototype"
end

--- 全道具模式：配置表全部可显示道具（每种一份，便于审查兼容）。
function BP.collect_all_catalog_items()
	local list = {}
	local config = Isaac.GetItemConfig()
	local size = config:GetCollectibles().Size
	local skip = BP.bag_skip_ids()
	for id = 1, size do
		if not skip[id] then
			local col = config:GetCollectible(id)
			if BP.collectible_eligible(col) then
				list[#list + 1] = id
			end
		end
	end
	return list
end


function BP.slot_reserve_from_craft(craft)
	local reserve = {real = {}, proto = {}}
	if not craft then return reserve end
	local function add(tok)
		if not tok or not tok.collectible then return end
		if tok.source == "prototype" and tok.prototype_uid then
			reserve.proto[tok.prototype_uid] = true
			reserve.proto[tostring(tok.prototype_uid)] = true
		elseif not tok.mirror_slot and tok.source ~= "mirror" then
			local id = tok.collectible
			reserve.real[id] = (reserve.real[id] or 0) + 1
		end
	end
	for _, slot in ipairs(craft.slots or {}) do
		if slot.token then add(craft.token_map[slot.token]) end
	end
	for _, tid in ipairs(craft.cost_ids or {}) do
		add(craft.token_map[tid])
	end
	-- 非审计：拖出/动画中的已占用 token（未回槽也未 from_bag）也要计入，防同 id 虚增
		if not craft.all_items then
		for _, tok in ipairs(craft.tokens or {}) do
			if tok and not tok.slot and not tok.cost and not tok.mirror_slot and not tok.from_bag then
				add(tok)
			end
		end
	end
	return reserve
end


function BP.open_craft_view(panel, target_id, edit_uid)
	local info = BP.get_target_info(target_id)
	if not info then return end
	local approx_w = 160
	local ingredients, cost_items, draft_mm = nil, nil, nil
	local draft = BP.get_drafts(panel.player)[BP.draft_key(target_id, edit_uid)]
	local prefs = BP.get_audit_ui_prefs(panel.player)
	local use_all_items = false
	-- 旧三态筛选仅用于迁移进标签；正式筛选走 tag_enabled
	local use_audit_filter = prefs.audit_filter or (prefs.hide_gray == true and "impl" or "all")
	local edit_rec = edit_uid and item.find_craft(panel.player, edit_uid) or nil
	local cost_n_hint = BP.resolve_session_required_cost(panel.player, edit_uid, edit_rec, draft)
	local function rebuild_slots(n, cost_hint)
		local layout = BP.make_slot_layout(n, cost_hint or cost_n_hint, approx_w)
		local slots = {}
		for i, s in ipairs(layout) do
			slots[i] = {ox = s.ox, oy = s.oy, token = nil}
		end
		return slots
	end
	-- 含审计材料的成品：默认打开全道具目录（需 Debug 权限）
	local allow_all = BP.all_items_mode_allowed()
	local edit_has_audit = edit_rec and CraftProfile.craft_has_any_audit_rec(edit_rec)
	if allow_all and edit_has_audit then
		use_all_items = true
		use_audit_filter = edit_rec.audit_filter or use_audit_filter
	end
	if draft then
		if not edit_has_audit then
			use_all_items = allow_all and draft.all_items == true
		end
		use_audit_filter = draft.audit_filter or use_audit_filter
		ingredients, cost_items, draft_mm = BP.filter_draft_items(
			panel.player, draft.ingredients, draft.cost_items, edit_uid, use_all_items
		)
	elseif edit_rec then
		BP.migrate_rec_mirror_fields(edit_rec)
		ingredients = edit_rec.ingredients
		cost_items = edit_rec.cost_items
	end
	local mirror_module = nil
	if draft and draft.mirror_module then
		mirror_module = draft.mirror_module
	elseif edit_rec and edit_rec.mirror_module then
		mirror_module = edit_rec.mirror_module
	end
	if draft_mm and not mirror_module then mirror_module = draft_mm end
	local remembered = nil
	if draft and draft.remembered_quality ~= nil then
		remembered = CraftProfile.normalize_base_quality(draft.remembered_quality)
	elseif edit_rec then
		remembered = CraftProfile.normalize_base_quality(edit_rec.base_quality or edit_rec.remembered_quality)
	end
	if BP.get_tutorial().uses_lesson_bag(edit_rec) then
		use_all_items = false
		if not edit_uid then
			ingredients, cost_items = nil, nil
			remembered = nil
			draft = nil
			mirror_module = nil
		end
	end
	if not allow_all then
		use_all_items = false
	end
	local live_q = CraftProfile.quality_from_cost_items(cost_items)
	if live_q ~= nil then remembered = live_q end
	local hide_cost = false
	if cost_n_hint <= 0
		and panel.player
		and panel.player:GetPlayerType() == enums.Players.Spwq
		and target_id == enums.Items.Air_Flight
		and not BP.get_tutorial().uses_lesson_bag(edit_rec)
		and not (edit_rec and edit_rec.tutorial)
	then
		hide_cost = true
		remembered = BP.get_spwq_first_air_quality()
		live_q = BP.get_spwq_first_air_quality()
	end
	if hide_cost then
		cost_items = nil
	end
	local slot_n = CraftProfile.slots_for_base_quality(remembered)
	local slots = rebuild_slots(slot_n, cost_n_hint)
	local main_ratio = 1
	if draft then main_ratio = draft.main_charge_ratio or draft.chocolate_charge_ratio or draft.techx_charge_ratio or 1
	elseif edit_rec then main_ratio = edit_rec.main_charge_ratio or edit_rec.chocolate_charge_ratio or edit_rec.techx_charge_ratio or 1 end
	do
		local preview_ings = {}
		if ingredients then
			for i, entry in pairs(ingredients) do
				preview_ings[tonumber(i) or i] = entry
			end
		end
		local live_charge = CraftProfile.build_profile(preview_ings)
		main_ratio = CraftProfile.canonicalize_main_charge(live_charge, main_ratio)
	end
	local tag_src = (edit_rec and edit_rec.tag_enabled)
		or (draft and draft.tag_enabled)
		or prefs.tag_enabled
	local use_tag_enabled = CraftProfile.normalize_audit_tag_enabled(tag_src, use_audit_filter)
	prefs.tag_enabled = use_tag_enabled
	prefs.audit_filter = "all"
	prefs.hide_gray = false
	panel.delete_confirm_uid = nil
	panel.view = edit_uid and "edit" or "craft"
	panel.craft = {
		target = target_id,
		info = info,
		edit_uid = edit_uid,
		slots = slots,
		slot_count = slot_n,
		cost_ids = {},
		mirror_token_id = nil,
		mirror_slot_enabled = BP.player_has_mirror_birthright(panel.player),
		tokens = {},
		token_map = {},
		snapshot = nil,
		all_items = use_all_items,
		tutorial_bag = BP.get_tutorial().uses_lesson_bag(edit_rec),
		show_quality = false,
		quality_user_set = false,
		hide_gray = false,
		audit_filter = "all",
		tag_enabled = use_tag_enabled,
		bag_page = 0,
		_bag_dirty = true,
		_catalog = nil,
		_catalog_impl = nil,
		_catalog_missing_stat = nil,
		required_cost = cost_n_hint,
		main_charge_ratio = main_ratio,
		base_quality = live_q,
		remembered_quality = remembered,
		hide_cost = hide_cost,
	}
	if ingredients then
		local edit_fb = edit_rec and edit_rec.audit == true
		for i, entry in pairs(ingredients) do
			local idx = tonumber(i) or i
			local col = CraftProfile.ingredient_id(entry)
			local src = CraftProfile.ingredient_source(entry, edit_fb)
			if CraftProfile.is_mirror_entry(entry) then
				if not mirror_module then
					mirror_module = {id = col, source = "mirror"}
				end
			elseif slots[idx] and col and col ~= 0 then
				local is_proto = src == "prototype"
				local tid = is_proto
					and ("slotfill_"..idx.."_p"..tostring(entry.prototype_uid))
					or ("slotfill_"..idx.."_"..col)
				local tok = {
					id = tid,
					collectible = col,
					source = src,
					prototype_uid = is_proto and entry.prototype_uid or nil,
					is_prototype = is_proto,
					pos = Vector(0, 0),
					vel = Vector(0, 0),
					slot = idx,
					from_bag = false,
					sprite = BP.load_col_sprite(col),
					impl = CraftProfile.has_impl(col),
					gate_kind = CraftProfile.effect_gate_kind(col),
					visual_scale = 1,
				}
				panel.craft.tokens[#panel.craft.tokens + 1] = tok
				panel.craft.token_map[tid] = tok
				slots[idx].token = tid
			end
		end
		local snap = {}
		for k, v in pairs(ingredients) do snap[k] = v end
		panel.craft.snapshot = snap
	end
	if mirror_module and panel.craft.mirror_slot_enabled then
		local col = CraftProfile.ingredient_id(mirror_module)
		if col and col ~= 0 then
			local tid = "mirrorfill_"..tostring(col)
			local tok = {
				id = tid,
				collectible = col,
				source = "mirror",
				is_mirror = true,
				mirror_slot = true,
				mirror_copy = true,
				pos = Vector(0, 0),
				vel = Vector(0, 0),
				from_bag = false,
				sprite = BP.load_col_sprite(col),
				impl = CraftProfile.has_impl(col),
				gate_kind = CraftProfile.effect_gate_kind(col),
				visual_scale = 1,
			}
			panel.craft.tokens[#panel.craft.tokens + 1] = tok
			panel.craft.token_map[tid] = tok
			panel.craft.mirror_token_id = tid
		end
	end
	if cost_items then
		local edit_fb = edit_rec and edit_rec.audit == true
		for ci, entry in ipairs(cost_items) do
			local col = CraftProfile.ingredient_id(entry)
			local src = CraftProfile.ingredient_source(entry, edit_fb)
			if col and col ~= 0 then
				local tid = "costfill_"..ci.."_"..col
				local tok = {
					id = tid,
					collectible = col,
					source = src,
					pos = Vector(0, 0),
					vel = Vector(0, 0),
					cost = true,
					from_bag = false,
					sprite = BP.load_col_sprite(col),
					impl = CraftProfile.has_impl(col),
					gate_kind = CraftProfile.effect_gate_kind(col),
					visual_scale = BP.get_cost_token_scale(),
				}
				panel.craft.tokens[#panel.craft.tokens + 1] = tok
				panel.craft.token_map[tid] = tok
				panel.craft.cost_ids[#panel.craft.cost_ids + 1] = tid
			end
		end
	end
	-- 草稿里放在背包区的失去道具：重进时仍显示为红色幽灵
	if draft and draft.bag_ghosts and not use_all_items then
		for gi, col in ipairs(draft.bag_ghosts) do
			col = tonumber(col) or col
			if col and col ~= 0 then
				local tid = "ghostbag_"..gi.."_"..tostring(col)
				local tok = {
					id = tid,
					collectible = col,
					pos = Vector(0, 0),
					vel = Vector(0, 0),
					from_bag = true,
					lost = true,
					lost_ghost = true,
					sprite = BP.load_col_sprite(col),
					impl = CraftProfile.has_impl(col),
					gate_kind = CraftProfile.effect_gate_kind(col),
					visual_scale = 1,
				}
				panel.craft.tokens[#panel.craft.tokens + 1] = tok
				panel.craft.token_map[tid] = tok
			end
		end
	end
	BP.refresh_craft_token_lost(panel.player, panel.craft)
	BP.sync_show_quality(panel.craft)
	panel.drag = nil
	panel.form_press = nil
	panel.pad_carry = nil
	panel.focus_id = "btn_confirm"
	panel.nav_group = "body"
	panel.body_focus_mem = "btn_confirm"
end

function item.open_tutorial_craft_view(panel)
	if not panel then return end
	BP.open_craft_view(panel, enums.Items.Air_Flight, nil)
end

--- opts.clear_draft：确认成功后清草稿；opts.skip_draft：不再读写草稿
function BP.leave_craft_view(panel, opts)
	opts = opts or {}
	if panel and panel.craft and panel.player and not opts.skip_draft then
		if opts.clear_draft then
			BP.clear_craft_draft(panel.player, panel.craft.target, panel.craft.edit_uid)
		else
			BP.save_craft_draft(panel)
		end
	end
	panel.view = "list"
	panel.craft = nil
	panel.drag = nil
	panel.form_press = nil
	panel.pad_carry = nil
	panel.focus_id = "tab_"..tostring(panel.tab or 1)
	panel.nav_group = "tabs"
	panel.body_focus_mem = nil
end


function BP.rebuild_bag_tokens(panel, bag_rect, player)
	local craft = panel.craft
	if not craft then return end
	-- 面板打开期间时间冻结，背包不会在外部变化；只在翻页/放回/切目录时重建。
	if craft._bag_dirty ~= true then return end
	craft._bag_dirty = false
	local kept = {}
	local kept_map = {}
	for _, tok in ipairs(craft.tokens) do
		local dragging = panel.drag and panel.drag.token_id == tok.id
		local carrying = panel.pad_carry and panel.pad_carry.token_id == tok.id
		local busy = tok.slot or tok.cost or tok.mirror_slot or dragging or carrying or tok.anim
			or (tok.vel and tok.vel:Length() > item.inertia_stop)
			or not tok.from_bag
			or tok.lost_ghost -- 失去幽灵留在背包页，禁止被库存重建冲掉
		if busy then
			kept[#kept + 1] = tok
			kept_map[tok.id] = tok
		end
	end
	local bag_ids
	local tut_ids = BP.get_tutorial().bag_collectibles()
	if tut_ids ~= nil then
		bag_ids, craft.bag_page, craft.bag_pages, craft.bag_total = tut_ids, 0, 1, #tut_ids
	elseif craft.all_items then
		craft._catalog = craft._catalog or BP.collect_all_catalog_items()
		local src = craft._catalog
		-- 标签筛选：状态组∩类别组（见 CraftProfile.collectible_matches_audit_tags）
		local tag_enabled = CraftProfile.normalize_audit_tag_enabled(craft.tag_enabled)
		craft.tag_enabled = tag_enabled
		local tagged = {}
		for _, id in ipairs(src) do
			if CraftProfile.collectible_matches_audit_tags(id, tag_enabled, player) then
				tagged[#tagged + 1] = id
			end
		end
		src = tagged
		bag_ids, craft.bag_page, craft.bag_pages, craft.bag_total = BP.page_slice(src, craft.bag_page, item.bag_page_size)
	else
		local full = BP.collect_bag_items(player, craft.edit_uid, BP.slot_reserve_from_craft(craft))
		bag_ids, craft.bag_page, craft.bag_pages, craft.bag_total = BP.page_slice(full, craft.bag_page, item.bag_page_size)
	end
	local positions = BP.bag_layout_positions(bag_rect, #bag_ids)
	for i, entry in ipairs(bag_ids) do
		local col = BP.bag_entry_collectible(entry)
		local is_proto = BP.bag_entry_is_proto(entry)
		local proto_uid = is_proto and entry.prototype_uid or nil
		local tid
		if is_proto then
			tid = (craft.all_items and "all_" or "bag_")..tostring(craft.bag_page).."_"..i.."_p"..tostring(proto_uid)
		else
			tid = (craft.all_items and "all_" or "bag_")..tostring(craft.bag_page).."_"..i.."_"..tostring(col)
		end
		local function settle_bag_home(kept_tok, dest)
			if not kept_tok or not dest then return end
			if not (kept_tok.from_bag and not kept_tok.slot and not kept_tok.cost) then return end
			kept_tok.home = dest
			if kept_tok.anim then
				local anim_dest = kept_tok.anim.to
				if not anim_dest or (anim_dest - dest):Length() > 1 then
					BP.begin_snap_anim(kept_tok, dest)
				end
			elseif not (panel.drag and panel.drag.token_id == kept_tok.id)
				and not (panel.pad_carry and panel.pad_carry.token_id == kept_tok.id)
				and (not kept_tok.vel or kept_tok.vel:Length() < 0.2)
			then
				if (kept_tok.pos - dest):Length() > 18 then
					BP.begin_snap_anim(kept_tok, dest)
				elseif (kept_tok.pos - dest):Length() > 1 then
					kept_tok.pos = dest
				end
			end
		end
		if kept_map[tid] then
			-- 拖拽/惯性/回位中的实体要保留，但它的背包 home 仍必须跟随
			-- 本次重建的规范网格。旧逻辑直接跳过，会让从背包取出再放回的
			-- token 保留 bag_area_anchor 的“列表下方”坐标，永远不回第一空位。
			settle_bag_home(kept_map[tid], positions[i])
		else
			-- 底座/槽位归还：孤儿仍在 kept（anim/vel），库存又会列出同 id → 必须认领，禁止再刷一份
			local orphan = (not tut_ids and not craft.all_items)
				and BP.claim_orphan_bag_token(kept, kept_map, col, is_proto, proto_uid)
			if orphan then
				kept_map[orphan.id] = nil
				orphan.id = tid
				orphan.collectible = col
				if is_proto then
					orphan.source = "prototype"
				else
					orphan.source = "real"
				end
				orphan.prototype_uid = proto_uid
				orphan.is_prototype = is_proto or false
				orphan.is_mirror = false
				orphan.mirror_copy = nil
				orphan.from_bag = true
				orphan.impl = CraftProfile.has_impl(col)
				orphan.missing_stat = CraftProfile.missing_stat_delta(col)
				orphan.gate_kind = CraftProfile.effect_gate_kind(col)
				kept_map[tid] = orphan
				settle_bag_home(orphan, positions[i])
			else
				local old = craft.token_map and craft.token_map[tid]
				if old and kept_map[old.id] then old = nil end
				local tok = old or {
					id = tid,
					collectible = col,
					pos = positions[i],
					vel = Vector(0, 0),
					slot = nil,
					from_bag = true,
					sprite = BP.load_col_sprite(col),
				}
				tok.id = tid
				tok.collectible = col
				-- 放置时打标：目录=audit，背包真实=real，原型=prototype
				if is_proto then
					tok.source = "prototype"
				elseif tut_ids or craft.all_items then
					tok.source = "audit"
				else
					tok.source = "real"
				end
				tok.prototype_uid = proto_uid
				tok.is_prototype = is_proto or false
				tok.is_mirror = false
				tok.impl = CraftProfile.has_impl(col)
				tok.missing_stat = CraftProfile.missing_stat_delta(col)
				tok.gate_kind = CraftProfile.effect_gate_kind(col)
				tok.home = positions[i]
				if not old then
					tok.pos = positions[i]
				elseif not tok.anim and (not tok.vel or tok.vel:Length() < 0.2) then
					if (tok.pos - positions[i]):Length() > 18 then
						BP.begin_snap_anim(tok, positions[i])
					elseif (tok.pos - positions[i]):Length() > 1 then
						tok.pos = positions[i]
					end
				end
				kept[#kept + 1] = tok
				kept_map[tid] = tok
			end
		end
	end
	craft.tokens = kept
	craft.token_map = kept_map
	-- 失去幽灵无库存格位：排在当前页末尾显示
	local ghost_i = 0
	for _, tok in ipairs(craft.tokens) do
		if tok.lost_ghost and tok.from_bag and not tok.slot and not tok.cost then
			ghost_i = ghost_i + 1
			local idx = #bag_ids + ghost_i
			local positions_all = BP.bag_layout_positions(bag_rect, idx)
			local dest = positions_all[idx]
			tok.home = dest
			if not tok.anim and (not tok.vel or tok.vel:Length() < 0.2) then
				if (tok.pos - dest):Length() > 18 then
					BP.begin_snap_anim(tok, dest)
				else
					tok.pos = dest
				end
			end
		end
	end
	BP.refresh_craft_token_lost(player, craft)
	craft._preview_sig = nil
end

function BP.remove_from_cost(craft, tok)
	if not craft or not tok then return end
	tok.cost = nil
	local ids = craft.cost_ids or {}
	for i = #ids, 1, -1 do
		if ids[i] == tok.id then table.remove(ids, i) end
	end
end

function BP.clear_token_slot(craft, tok)
	if tok.mirror_slot then
		if craft.mirror_token_id == tok.id then craft.mirror_token_id = nil end
		tok.mirror_slot = nil
		tok.is_mirror = nil
	end
	if tok.slot then
		local slot = craft.slots[tok.slot]
		if slot and slot.token == tok.id then slot.token = nil end
		tok.slot = nil
	end
	if tok.cost then
		BP.remove_from_cost(craft, tok)
		-- 取出底座：记住品质并保留槽位，不立刻收起
		if craft then craft.base_quality = nil end
		BP.sync_show_quality(craft)
	end
end

--- 保证每个材料槽最多一个 token；以 slot.token 为准，清掉多余占用者
function BP.reconcile_slot_occupancy(craft)
	if not craft or not craft.slots then return end
	-- 先按 slot.token 建权威占用
	local owner = {}
	for i, slot in ipairs(craft.slots) do
		local tid = slot.token
		if tid then
			local tok = craft.token_map[tid]
			if tok and not tok.cost then
				owner[i] = tok
				tok.slot = i
			else
				slot.token = nil
			end
		end
	end
	-- 踢掉仍自称在槽、但未被权威占用接纳的 token
	for _, tok in ipairs(craft.tokens or {}) do
		if tok.slot and not tok.cost then
			local slot = craft.slots[tok.slot]
			if not slot or slot.token ~= tok.id then
				tok.slot = nil
				if not (item.panel and item.panel.drag and item.panel.drag.token_id == tok.id)
					and not (item.panel and item.panel.pad_carry and item.panel.pad_carry.token_id == tok.id)
					and not tok.anim then
					local dest = BP.bag_area_anchor(tok)
					tok.home = dest
					tok.from_bag = true
					if tok.lost or tok.lost_ghost then
						tok.lost_ghost = true
						tok.lost = true
					end
					BP.begin_snap_anim(tok, dest)
				end
			end
		end
	end
	-- 再写回权威占用（防止中途被改）
	for i, tok in pairs(owner) do
		local slot = craft.slots[i]
		if slot then
			slot.token = tok.id
			tok.slot = i
		end
	end
end

--- 审计全道具：放入槽位/成本后断开背包身份，背包可再刷出同款以便叠层
--- 非审计：禁止改 from_bag——否则取出后既保留孤儿 token，又按库存补货同 id
function BP.detach_bag_identity(craft, tok)
	if not craft or not tok then return end
	if not craft.all_items then return end
	local looks_bag = tok.from_bag or (type(tok.id) == "string" and tok.id:sub(1, 4) == "all_")
	if not looks_bag then return end
	local old = tok.id
	local new_id = "inst_"..tostring(tok.collectible).."_"..tostring(Isaac.GetFrameCount()).."_"..tostring(math.random(100000))
	if craft.token_map[old] == tok then craft.token_map[old] = nil end
	-- 槽位引用随 id 一起改，避免旧 id 残留导致“同槽多道具”
	if tok.slot then
		local slot = craft.slots[tok.slot]
		if slot and slot.token == old then slot.token = new_id end
	end
	if tok.cost and craft.cost_ids then
		for i, tid in ipairs(craft.cost_ids) do
			if tid == old then craft.cost_ids[i] = new_id end
		end
	end
	tok.id = new_id
	tok.from_bag = false
	if tok.source ~= "prototype" then
		tok.source = "audit"
	end
	craft.token_map[new_id] = tok
end

function BP.cost_stack_pos(craft, geom, index)
	local base = geom and geom.cost_pos or Vector(0, 0)
	local total = (geom and geom.cost_display_n) or BP.cost_display_count(craft)
	local n = math.max(1, total)
	local i = math.max(1, index or #(craft.cost_ids or {}))
	local size = (geom and geom.cost_size) or BP.get_cost_slot_size()
	local spacing = (geom and geom.cost_spacing) or BP.get_cost_slot_spacing()
	local row_gap = (geom and geom.cost_row_gap) or (item.cost_slot_row_gap or 2)
	local cols = (geom and geom.cost_cols) or BP.cost_cols_for_width(160)
	cols = math.max(1, cols)
	local row = math.floor((i - 1) / cols)
	local col = (i - 1) % cols
	local row_start = row * cols + 1
	local row_count = math.min(cols, n - row_start + 1)
	local ox = (col + 1 - (row_count + 1) * 0.5) * spacing
	local oy = row * (size + row_gap)
	return base + Vector(ox, oy)
end

function BP.assign_token_cost(craft, tok, geom)
	if not craft or not tok then return end
	if craft.hide_cost then
		if tok.home then BP.begin_snap_anim(tok, tok.home) end
		return
	end
	if BP.get_tutorial().is_locking() and not BP.get_tutorial().allows_cost_assign(tok) then
		if tok.home then BP.begin_snap_anim(tok, tok.home) end
		return
	end
	-- 原型与镜像不能支付成本槽
	if tok.source == "prototype" or tok.is_prototype then
		BP.clear_token_slot(craft, tok)
		if tok.home then BP.begin_snap_anim(tok, tok.home) end
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.55, 1.1, false, 0, 2)
		return
	end
	if tok.mirror_slot or tok.source == "mirror" then
		if tok.home then BP.begin_snap_anim(tok, tok.home) end
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.55, 1.1, false, 0, 2)
		return
	end
	BP.detach_bag_identity(craft, tok)
	BP.clear_token_slot(craft, tok)
	-- 底座槽只保留一件：旧底座滑回背包（取出不改槽数；换入才适配）
	craft.cost_ids = craft.cost_ids or {}
	for i = #craft.cost_ids, 1, -1 do
		local tid = craft.cost_ids[i]
		if tid ~= tok.id then
			local other = craft.token_map[tid]
			table.remove(craft.cost_ids, i)
			if other then
				other.cost = nil
				other.from_bag = true
				local dest = BP.bag_area_anchor(other)
				other.home = dest
				if other.lost or other.lost_ghost then
					other.lost_ghost = true
					other.lost = true
				end
				BP.begin_snap_anim(other, dest)
			end
		end
	end
	tok.cost = true
	tok.visual_scale = BP.get_cost_token_scale()
	craft.cost_ids[#craft.cost_ids + 1] = tok.id
	local dest = BP.cost_stack_pos(craft, geom, #craft.cost_ids)
	BP.begin_snap_anim(tok, dest)
	local q = CraftProfile.collectible_quality(tok.collectible)
	craft.base_quality = q
	craft.remembered_quality = q
	BP.apply_module_slots_for_base(craft, geom, {adapt = true})
	BP.sync_show_quality(craft)
	craft._bag_dirty = true
end

--- 将占用者挪到其他材料槽，或滑回背包区（不瞬移、不删掉）
function BP.relocate_displaced_token(craft, other, from_slot_index, exclude_slot)
	if not craft or not other then return end
	other.cost = nil
	BP.remove_from_cost(craft, other)
	other.slot = nil

	-- 1) 来自另一材料槽：互换回原槽
	if from_slot_index and from_slot_index ~= exclude_slot and craft.slots[from_slot_index] then
		local prev_slot = craft.slots[from_slot_index]
		local blocker_id = prev_slot.token
		if blocker_id and blocker_id ~= other.id then
			local blocker = craft.token_map[blocker_id]
			if blocker then
				prev_slot.token = nil
				blocker.slot = nil
				local bdest = BP.bag_area_anchor(blocker)
				blocker.home = bdest
				BP.begin_snap_anim(blocker, bdest)
			end
		end
		prev_slot.token = other.id
		other.slot = from_slot_index
		other.visual_scale = 1
		local dest = prev_slot._rect and Mouse_UI.rect_center(prev_slot._rect) or other.pos
		BP.begin_snap_anim(other, dest)
		return
	end

	-- 2) 来自背包/成本/空闲：优先挪到其他空材料槽
	local empty_i = BP.find_empty_ingredient_slot(craft, exclude_slot)
	if empty_i then
		local es = craft.slots[empty_i]
		es.token = other.id
		other.slot = empty_i
		other.visual_scale = 1
		local dest = es._rect and Mouse_UI.rect_center(es._rect) or other.pos
		BP.begin_snap_anim(other, dest)
		return
	end

	-- 3) 无空槽：滑入背包区域，保留实体（失去道具记为幽灵，避免重建时消失）
	local dest = BP.bag_area_anchor(other)
	other.home = dest
	other.from_bag = true
	if other.lost or other.lost_ghost then
		other.lost_ghost = true
		other.lost = true
	end
	BP.begin_snap_anim(other, dest)
end

function BP.apply_module_slots_for_base(craft, geom, opts)
	if not craft then return end
	opts = opts or {}
	if not opts.adapt then return end
	local q = craft.base_quality
	if q == nil then q = craft.remembered_quality end
	local new_n = CraftProfile.slots_for_base_quality(q)
	local old_slots = craft.slots or {}
	if new_n == #old_slots then return end
	local displaced = {}
	if new_n < #old_slots then
		for i = new_n + 1, #old_slots do
			local slot = old_slots[i]
			if slot and slot.token then
				local tok = craft.token_map[slot.token]
				slot.token = nil
				if tok then
					tok.slot = nil
					displaced[#displaced + 1] = tok
				end
			end
		end
	end
	local avail_w = 160
	if geom and geom.left then avail_w = geom.left.w - 8 end
	local layout = BP.make_slot_layout(new_n, BP.cost_display_count(craft), avail_w)
	local slots = {}
	for i = 1, new_n do
		local prev = old_slots[i]
		local L = layout[i] or {ox = 0, oy = 0}
		local slot = prev or {token = nil, ox = 0, oy = 0}
		slot._from_ox = slot.ox or 0
		slot._from_oy = slot.oy or 0
		if not prev then
			slot._from_ox = 0
			slot._from_oy = 0
			slot.ox = 0
			slot.oy = 0
		end
		slot._to_ox = L.ox
		slot._to_oy = L.oy
		slot._anim_t = 0
		slots[i] = slot
	end
	craft.slots = slots
	craft.slot_count = new_n
	for _, tok in ipairs(displaced) do
		BP.relocate_displaced_token(craft, tok, nil, nil)
	end
end

function BP.can_assign_mirror(craft, tok)
	if not craft or not tok or not tok.collectible then return false end
	if not craft.mirror_slot_enabled then return false end
	if tok.cost then return false end
	if craft.all_items or tok.source == "audit" then return false end
	if tok.source == "prototype" or tok.is_prototype then return false end
	if CraftProfile.is_ingredient_banned(tok.collectible) then return false end
	if not CraftProfile.has_impl(tok.collectible) then return false end
	return true
end

function BP.mirror_slot_center(geom)
	if geom and geom.mirror_pos then return geom.mirror_pos end
	return nil
end

function BP.dismiss_mirror_token(craft, tok)
	if not craft or not tok then return end
	if craft.mirror_token_id == tok.id then craft.mirror_token_id = nil end
	if BP.is_mirror_only_token(tok) then
		BP.remove_token_entity(craft, tok)
		return
	end
	BP.clear_token_slot(craft, tok)
	tok.source = craft.all_items and "audit" or "real"
	tok.is_mirror = nil
	if not craft.all_items then
		tok.from_bag = true
		local dest = tok.home or BP.bag_area_anchor(tok)
		tok.home = dest
		BP.begin_snap_anim(tok, dest)
	end
	craft._bag_dirty = true
end

function BP.spawn_mirror_copy(craft, col, geom, ref_tok)
	local tid = "mirror_"..tostring(col).."_"..tostring(Isaac.GetFrameCount()).."_"..tostring(math.random(10000))
	local dest = BP.mirror_slot_center(geom) or Vector(0, 0)
	local mtok = {
		id = tid,
		collectible = col,
		source = "mirror",
		is_mirror = true,
		mirror_slot = true,
		mirror_copy = true,
		from_bag = false,
		pos = dest,
		vel = Vector(0, 0),
		sprite = BP.load_col_sprite(col),
		impl = ref_tok and ref_tok.impl or CraftProfile.has_impl(col),
		missing_stat = ref_tok and ref_tok.missing_stat or CraftProfile.missing_stat_delta(col),
		gate_kind = ref_tok and ref_tok.gate_kind or CraftProfile.effect_gate_kind(col),
		visual_scale = 1,
		lit = ref_tok and ref_tok.lit,
	}
	craft.tokens[#craft.tokens + 1] = mtok
	craft.token_map[tid] = mtok
	craft.mirror_token_id = tid
	BP.begin_snap_anim(mtok, dest)
	return mtok
end

function BP.assign_mirror_token(craft, tok, geom)
	if not BP.can_assign_mirror(craft, tok) then
		if tok.home then BP.begin_snap_anim(tok, tok.home) end
		return false
	end
	if craft.mirror_token_id and craft.mirror_token_id ~= tok.id then
		local prev = craft.token_map[craft.mirror_token_id]
		if prev then BP.dismiss_mirror_token(craft, prev) end
	end
	local col = tok.collectible
	if tok.from_bag then
		BP.spawn_mirror_copy(craft, col, geom, tok)
		if tok.home then BP.begin_snap_anim(tok, tok.home) end
		craft._bag_dirty = true
		return true
	end
	if tok.mirror_copy then
		tok.mirror_slot = true
		tok.source = "mirror"
		tok.is_mirror = true
		craft.mirror_token_id = tok.id
		BP.begin_snap_anim(tok, BP.mirror_slot_center(geom) or tok.pos)
		return true
	end
	BP.clear_token_slot(craft, tok)
	tok.source = "mirror"
	tok.is_mirror = true
	tok.mirror_slot = true
	tok.slot = nil
	tok.cost = nil
	tok.from_bag = false
	tok.visual_scale = 1
	craft.mirror_token_id = tok.id
	BP.begin_snap_anim(tok, BP.mirror_slot_center(geom) or tok.pos)
	craft._bag_dirty = true
	return true
end

function BP.assign_token_slot(craft, tok, slot_index)
	local slot = craft.slots[slot_index]
	if not slot or not tok then return end
	-- inherited_player_effect / INGREDIENT_BAN：不可装入材料槽
	if tok.collectible and CraftProfile.is_ingredient_banned(tok.collectible) then
		if tok.home then BP.begin_snap_anim(tok, tok.home) end
		return
	end
	if BP.get_tutorial().is_locking() and not BP.get_tutorial().allows_slot_assign(tok) then
		if tok.home then BP.begin_snap_anim(tok, tok.home) end
		return
	end
	BP.detach_bag_identity(craft, tok)
	if tok.slot == slot_index and slot.token == tok.id then
		local dest = slot._rect and Mouse_UI.rect_center(slot._rect) or tok.pos
		BP.begin_snap_anim(tok, dest)
		return
	end

	local prev_index = tok.slot
	local other = nil
	if slot.token and slot.token ~= tok.id then
		other = craft.token_map[slot.token]
	end

	-- 先从原槽卸下当前 token（勿在写入互换结果后再 clear，否则会抹掉刚放回的占用）
	BP.clear_token_slot(craft, tok)
	if tok.source == "mirror" or tok.is_mirror then
		tok.source = craft.all_items and "audit" or "real"
		tok.is_mirror = nil
		tok.mirror_copy = nil
	end

	if other then
		-- 目标槽腾出 B，再按来源决定：互换 / 挪空槽 / 滑回背包区
		if slot.token == other.id then slot.token = nil end
		other.slot = nil
		BP.relocate_displaced_token(craft, other, prev_index, slot_index)
	end

	slot.token = tok.id
	tok.slot = slot_index
	tok.cost = nil
	tok.visual_scale = 1
	local dest = slot._rect and Mouse_UI.rect_center(slot._rect) or tok.pos
	BP.begin_snap_anim(tok, dest)
	BP.reconcile_slot_occupancy(craft)
	craft._bag_dirty = true
end

function BP.find_snap_slot(craft, tok)
	local best, best_d = nil, nil
	local limit = item.snap_dist or 34
	for i, slot in ipairs(craft.slots) do
		if slot._rect then
			local c = Mouse_UI.rect_center(slot._rect)
			local d = (tok.pos - c):Length()
			if d <= limit and (best_d == nil or d < best_d) then
				best_d = d
				best = i
			end
		end
	end
	return best, best_d
end

function BP.find_snap_cost(craft, tok, geom)
	if not geom or not geom.cost_rect then return false, nil, false end
	local r = geom.cost_rect
	local c = Mouse_UI.rect_center(r)
	local reach = math.max(item.snap_dist or 34, math.max(r.w, r.h) * 0.55)
	local d = (tok.pos - c):Length()
	local inside = Mouse_UI.point_in_rect(tok.pos, r) == true
	if inside then return true, 0, true end
	if d <= reach then return true, d, false end
	return false, d, false
end

function BP.read_mirror_module(craft)
	if not craft or not craft.mirror_token_id then return nil end
	local tok = craft.token_map[craft.mirror_token_id]
	if tok and tok.collectible then
		return {id = tok.collectible, source = "mirror"}
	end
	return nil
end

function BP.profile_ingredients(craft)
	return CraftProfile.ingredients_with_mirror(BP.read_ingredients(craft), BP.read_mirror_module(craft))
end

function BP.read_ingredients(craft)
	local ingredients = {}
	for i, slot in ipairs(craft.slots) do
		if slot.token then
			local tok = craft.token_map[slot.token]
			if tok and tok.collectible then
				local src = tok.source
				if src == "prototype" and tok.prototype_uid then
					ingredients[i] = {
						id = tok.collectible,
						source = "prototype",
						prototype_uid = tok.prototype_uid,
					}
				elseif src == "audit" then
					ingredients[i] = {
						id = tok.collectible,
						source = "audit",
					}
				else
					-- real：存 number 以兼容旧读法；来源由缺省 source 推断
					ingredients[i] = tok.collectible
				end
			end
		end
	end
	return ingredients
end

function BP.read_cost_items(craft)
	local list = {}
	for _, tid in ipairs(craft.cost_ids or {}) do
		local tok = craft.token_map[tid]
		if tok and tok.collectible then
			if tok.source == "audit" then
				list[#list + 1] = { id = tok.collectible, source = "audit" }
			else
				list[#list + 1] = tok.collectible
			end
		end
	end
	return list
end

function BP.craft_preview_name(craft, player)
	if not craft then return "" end
	local zh = BP.lang_is_zh()
	local serial = 1
	if craft.edit_uid then
		local rec = item.find_craft(player, craft.edit_uid)
		serial = (rec and tonumber(rec.serial)) or 1
	else
		serial = BP.next_serial_for_target(player, craft.target)
	end
	local src = BP.naming_ingredients(BP.read_ingredients(craft), BP.read_cost_items(craft))
	return CraftProfile.build_display_name(craft.target, serial, src, zh)
end

--- 还原草稿材料/成本：未持有的也保留（失去态标红），禁止因缺料把槽位直接空置
--- all_items 仅作「无显式 source 的旧草稿」回退：目录模式草稿的纯 number 视为 audit
function BP.filter_draft_items(player, ingredients, cost_items, exclude_uid, all_items)
	ingredients = ingredients or {}
	cost_items = cost_items or {}
	local audit_fb = all_items == true
	local ing, cost, mm = {}, {}, nil
	local keys = {}
	for i, _ in pairs(ingredients) do
		local idx = tonumber(i) or i
		if type(idx) == "number" then keys[#keys + 1] = idx end
	end
	table.sort(keys)
	for _, idx in ipairs(keys) do
		local entry = ingredients[idx] or ingredients[tostring(idx)]
		local src = CraftProfile.ingredient_source(entry, audit_fb)
		local id = CraftProfile.ingredient_id(entry)
		if src == "prototype" then
			local uid = type(entry) == "table" and entry.prototype_uid or nil
			if uid ~= nil and id and id ~= 0 then
				ing[idx] = {
					id = id,
					source = "prototype",
					prototype_uid = uid,
				}
			end
		elseif src == "audit" then
			if id and id ~= 0 then
				ing[idx] = { id = id, source = "audit" }
			end
		elseif src == "mirror" then
			if id and id ~= 0 and not mm then
				mm = {id = id, source = "mirror"}
			end
		else
			if id and id ~= 0 then
				ing[idx] = id
			end
		end
	end
	for _, entry in ipairs(cost_items) do
		local src = CraftProfile.ingredient_source(entry, audit_fb)
		local id = CraftProfile.ingredient_id(entry)
		if id and id ~= 0 then
			if src == "audit" then
				cost[#cost + 1] = { id = id, source = "audit" }
			else
				cost[#cost + 1] = id
			end
		end
	end
	return ing, cost, mm
end

function BP.read_bag_ghosts(craft)
	local list = {}
	if not craft then return list end
	for _, tok in ipairs(craft.tokens or {}) do
		if tok and tok.collectible and tok.collectible ~= 0
			and not tok.slot and not tok.cost and not tok.mirror_slot
			and (tok.lost_ghost or tok.lost)
			and not (tok.source == "prototype" or tok.is_prototype)
		then
			list[#list + 1] = tok.collectible
		end
	end
	return list
end

function BP.save_craft_draft(panel)
	if not panel or not panel.craft or not BP.player_exists_safe(panel.player) then return end
	local craft = panel.craft
	local ingredients = BP.read_ingredients(craft)
	local cost_items = BP.read_cost_items(craft)
	local mirror_module = BP.read_mirror_module(craft)
	local bag_ghosts = BP.read_bag_ghosts(craft)
	local filled = 0
	for _, _ in pairs(ingredients) do filled = filled + 1 end
	local key = BP.draft_key(craft.target, craft.edit_uid)
	local drafts = BP.get_drafts(panel.player)
	if filled <= 0 and #cost_items <= 0 and #bag_ghosts <= 0 and not mirror_module then
		drafts[key] = nil
		return
	end
	local ing_save = {}
	for i, col in pairs(ingredients) do
		ing_save[tostring(i)] = col
	end
	drafts[key] = {
		target = craft.target,
		edit_uid = craft.edit_uid,
		ingredients = ing_save,
		mirror_module = mirror_module,
		cost_items = cost_items,
		bag_ghosts = bag_ghosts,
		slot_count = craft.slot_count,
		required_cost = craft.required_cost or 0,
		base_quality = craft.base_quality,
		remembered_quality = craft.remembered_quality,
		all_items = craft.all_items == true,
		hide_gray = craft.hide_gray == true,
		audit_filter = craft.audit_filter or "all",
		main_charge_ratio = BP.canonicalize_craft_charge(craft, craft.main_charge_ratio),
	}
end

--- 按 token 来源标失去态：audit 永不失去；real/prototype 按持有/UID
function BP.refresh_craft_token_lost(player, craft)
	if not craft or not player then return end
	local used = item.count_allocated(player, craft.edit_uid)
	local have = {}
	local function remaining(id)
		id = tonumber(id) or id
		if not id or id == 0 then return 0 end
		if have[id] == nil then
			local n = player:GetCollectibleNum(id, true) - (used[id] or 0)
			if id == item.entity then n = n - 1 end
			have[id] = math.max(0, n)
		end
		return have[id]
	end
	local function take(id)
		id = tonumber(id) or id
		local n = remaining(id)
		if n > 0 then
			have[id] = n - 1
			return true
		end
		return false
	end
	for _, tok in ipairs(craft.tokens or {}) do
		if not tok or not tok.collectible then
			-- skip
		elseif tok.source == "audit" then
			tok.lost = nil
			tok.lost_ghost = nil
		elseif tok.source == "prototype" or tok.is_prototype then
			local uid = tok.prototype_uid
			local prec = uid and item.get_prototype(player, uid) or nil
			local ok = prec and prec.id == tok.collectible
			tok.lost = not ok
			tok.lost_ghost = (not ok) or nil
		elseif tok.source == "mirror" or tok.is_mirror then
			local id = tok.collectible
			local ok = BP.player_has_mirror_birthright(player) and id and (player:GetCollectibleNum(id, true) or 0) > 0
			tok.lost = not ok
			tok.lost_ghost = (not ok) or nil
		elseif tok.lost_ghost and tok.from_bag and not tok.slot and not tok.cost then
			-- 背包里的失去幽灵：不占库存，保持标红
			tok.lost = true
		elseif tok.from_bag and not tok.slot and not tok.cost and not tok.mirror_slot then
			-- 真实背包库存
			tok.lost = false
			tok.lost_ghost = nil
		else
			if take(tok.collectible) then
				tok.lost = false
				tok.lost_ghost = nil
			else
				tok.lost = true
				tok.lost_ghost = true
			end
		end
	end
end

function BP.rebind_air_flight_profile(player, uid, profile)
	local Craft_Familiar_holder = require("Qing_Remaster_scripts.mimics.Craft_Familiar_holder")
	local hit = false
	for _, fam in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, enums.Familiars.QingsAirs, -1, false, false)) do
		local p = auxi.check_spawner_player(fam)
		if p and auxi.check_for_the_same(p, player) then
			if CraftIdentity.get_uid(fam) == uid then
				CraftIdentity.set_profile(fam, profile)
				-- 背包确认后立刻按新配方释放/认领宝宝并刷新复活 MeusNil
				if Craft_Familiar_holder.sync_air_flight then
					Craft_Familiar_holder.sync_air_flight(fam, player, profile)
				end
				hit = true
			end
		end
	end
	return hit
end

--- 蓝图属性/TearFlags/胎儿次级 flags 均脱钩；imitate 用于 audit/prototype 的制造宝宝实体。
--- real 材料失去后不得补发临时宝宝（否则会冒出假玛姬等）——由 collect 只扫 audit/prototype 保证。
--- 制造复活源例外：永不进玩家 innate；跟随源用真实体/MeusNil。
--- audit/prototype 份数与玩家真实持有无关：有真道具也照常 imitate，不得因 HasCollectible 整表清零。
function BP.is_audit_simulate_item(id)
	id = tonumber(id)
	if not id or id == 0 then return false end
	if CraftProfile.CRAFT_REVIVE_ID_SET and CraftProfile.CRAFT_REVIVE_ID_SET[id] then
		return false
	end
	local extra = CraftProfile.EXTRA_IMPL[id]
	return extra ~= nil
		and CraftProfile.CRAFT_FAMILIAR_EXTRAS_KEY_SET ~= nil
		and CraftProfile.CRAFT_FAMILIAR_EXTRAS_KEY_SET[extra] == true
end

function item.collect_audit_simulate_counts(player)
	local counts = {}
	for _, rec in ipairs(item.get_craft_store(player)) do
		local fb = rec.audit == true
		local seen_slot = {}
		for slot, entry in pairs(rec.ingredients or {}) do
			local sk = tostring(slot)
			if not seen_slot[sk] then
				seen_slot[sk] = true
				-- audit / prototype 可 imitate（制造宝宝 extras）；不把 prototype 记成审计模式
				local src = CraftProfile.ingredient_source(entry, fb)
				if src == "audit" or src == "prototype" then
					if src == "prototype" then
						local uid = type(entry) == "table" and entry.prototype_uid
						local prec = uid and item.get_prototype(player, uid) or nil
						local id = CraftProfile.ingredient_id(entry)
						if not prec or prec.id ~= id then
							-- 原型 UID 丢失：不 imitate
						elseif BP.is_audit_simulate_item(id) then
							counts[id] = (counts[id] or 0) + 1
						end
					else
						local id = CraftProfile.ingredient_id(entry)
						if BP.is_audit_simulate_item(id) then
							counts[id] = (counts[id] or 0) + 1
						end
					end
				end
			end
		end
	end
	return counts
end

function BP.refresh_audit_simulates(player)
	if not player then return end
	Imitate_item_holder.Evaluate_Imitate_Items(player)
	player:AddCacheFlags(
		CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_SHOTSPEED
		| CacheFlag.CACHE_RANGE | CacheFlag.CACHE_LUCK | CacheFlag.CACHE_SPEED
		| CacheFlag.CACHE_TEARFLAG | CacheFlag.CACHE_WEAPON | CacheFlag.CACHE_FAMILIARS
	)
	player:EvaluateItems()
end
item.refresh_audit_simulates = BP.refresh_audit_simulates

--- 库存删除：首次点「删」进入确认，再点一次才真正删除
function BP.try_confirm_delete_stock(panel, craft_uid)
	if not panel or not panel.player or craft_uid == nil then return end
	if panel.delete_confirm_uid ~= craft_uid then
		panel.delete_confirm_uid = craft_uid
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_LIGHT, 0.55, 0.95, false, 0, 2)
		return
	end
	panel.delete_confirm_uid = nil
	if item.delete_craft(panel.player, craft_uid) then
		BP.refresh_audit_simulates(panel.player)
		panel.nav_graph = nil
		panel.focus_id = "tab_"..tostring(panel.tab or 2)
		panel.nav_group = "tabs"
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBSDOWN, 0.85, 1, false, 0, 2)
		pcall(function() BP.get_tutorial().on_craft_deleted(panel.player, craft_uid) end)
	else
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.7, 1, false, 0, 2)
	end
end


function BP.confirm_craft(panel)
	local craft = panel.craft
	local player = panel.player
	if not craft or not player then return end
	if BP.get_tutorial().is_locking() and not BP.get_tutorial().allow_confirm(craft) then
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.7, 1, false, 0, 2)
		return
	end
	local ingredients = BP.read_ingredients(craft)
	local cost_items = BP.read_cost_items(craft)
	local mirror_module = BP.read_mirror_module(craft)
	-- 材料槽可选：允许空配方（基础面板）。里小青首件 required_cost=0 时无任何必填槽。
	-- 整机 audit：存在任一 audit 材料；纯审计才豁免成本与配额
	local has_audit = CraftProfile.craft_has_any_audit(ingredients, cost_items, false)
	local pure_audit = CraftProfile.craft_is_pure_audit(ingredients, cost_items, false)
	-- 编辑也按本件锁定的 required_cost 校验（不再因 edit_uid 豁免）
	local need_cost = craft.required_cost or 0
	if not craft.edit_uid and need_cost <= 0 then
		need_cost = item.get_required_cost(player)
	end
	local real_cost_n = 0
	for _, entry in ipairs(cost_items) do
		if CraftProfile.is_real_entry(entry, false) then
			real_cost_n = real_cost_n + 1
		end
	end
	if not pure_audit and real_cost_n < need_cost then
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.7, 1, false, 0, 2)
		return
	end
	if not pure_audit and not BP.ingredients_fit_allocation(player, ingredients, craft.edit_uid, cost_items, mirror_module) then
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BOSS2INTRO_ERRORBUZZ, 0.7, 1, false, 0, 2)
		return
	end
	if craft.hide_cost then
		cost_items = {}
		craft.required_cost = 0
		craft.base_quality = BP.get_spwq_first_air_quality()
		craft.remembered_quality = BP.get_spwq_first_air_quality()
	end
	-- 成本道具不进入战斗档案；确认时写入含动态种子的档案快照（运行时仍会按玩家重算）
	local profile = CraftProfile.build_profile(BP.profile_ingredients(craft), {
		player = player,
		rec = craft.edit_uid and item.find_craft(player, craft.edit_uid) or craft,
		commit_state = true,
		base_quality = craft.remembered_quality or craft.base_quality,
	})
	local main_ratio = CraftProfile.canonicalize_main_charge(profile, craft.main_charge_ratio)
	CraftProfile.apply_craft_settings(profile, {
		main_charge_ratio = main_ratio,
	})
	local store = item.get_craft_store(player)
	local root = BP.ensure_save()

	if craft.edit_uid then
		local rec = item.find_craft(player, craft.edit_uid)
		if not rec then return end
		local was_broken = rec.broken == true
		rec.ingredients = ingredients
		rec.mirror_module = mirror_module
		rec.cost_items = cost_items
		rec.required_cost = craft.required_cost or BP.locked_required_cost_from_rec(rec)
		rec.base_quality = craft.remembered_quality or craft.base_quality or CraftProfile.quality_from_cost_items(cost_items)
		rec.remembered_quality = rec.base_quality
		rec.main_charge_ratio = main_ratio
		rec.experimental = craft.experimental or rec.experimental
		rec.eye_phase = craft.eye_phase or rec.eye_phase
		rec.profile = profile
		rec.audit = has_audit
		-- 手动确认修改：解除复活锁定；移出配方的复活源清 spent
		CraftProfile.craft_revive_on_confirm(rec, profile)
		if has_audit then
			rec.hide_gray = craft.hide_gray == true
			rec.audit_filter = craft.audit_filter or "all"
			BP.get_audit_ui_prefs(player).hide_gray = rec.hide_gray
			BP.get_audit_ui_prefs(player).audit_filter = rec.audit_filter
		end
		rec.serial = tonumber(rec.serial) or BP.next_serial_for_target(player, rec.target, rec.uid)
		BP.refresh_rec_display_name(rec, player)
		-- 先 integrity / imitate，再 rebind+sync，避免缺料时仍按旧 broken_missing 捕捉
		item.refresh_craft_integrity(player)
		if was_broken and rec.broken ~= true then
			CraftProfile.craft_revive_on_repaired(rec, profile)
		end
		BP.refresh_audit_simulates(player)
		BP.rebind_air_flight_profile(player, rec.uid, profile)
		pcall(function() BP.get_bandwidth().on_craft_changed(player, rec.uid) end)
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BUTTON_PRESS, 1, 1, false, 0, 2)
		BP.leave_craft_view(panel, {clear_draft = true})
		BP.checkpoint_run_save("craft_edit")
		return
	end

	root.uid_counter = (root.uid_counter or 0) + 1
	local uid = root.uid_counter
	local rec = {
		uid = uid,
		target = craft.target,
		ingredients = ingredients,
		mirror_module = mirror_module,
		cost_items = cost_items,
		required_cost = craft.required_cost or need_cost,
		base_quality = craft.remembered_quality or craft.base_quality or CraftProfile.quality_from_cost_items(cost_items),
		remembered_quality = craft.remembered_quality or craft.base_quality,
		profile = profile,
		main_charge_ratio = main_ratio,
		experimental = craft.experimental,
		eye_phase = craft.eye_phase or 0,
		audit = has_audit,
		serial = BP.next_serial_for_target(player, craft.target),
	}
	if has_audit then
		rec.hide_gray = craft.hide_gray == true
		rec.audit_filter = craft.audit_filter or "all"
		BP.get_audit_ui_prefs(player).hide_gray = rec.hide_gray
		BP.get_audit_ui_prefs(player).audit_filter = rec.audit_filter
	end
	BP.refresh_rec_display_name(rec, player)
	if BP.get_tutorial().is_active() then
		BP.get_tutorial().on_craft_confirmed(rec)
	end
	table.insert(store, rec)
	BP.clear_craft_draft(player, craft.target, nil)
	BP.checkpoint_run_save("craft_add")
	pcall(function() BP.get_bandwidth().on_craft_added(player, uid) end)
	panel.craft = nil -- 避免 close_panel 再把已确认内容存成草稿

	local gained = craft.target
	-- 不发放目标收藏品；飞行器数量由 CheckFamiliar(库存份数) 同步
	player:AddCacheFlags(CacheFlag.CACHE_FAMILIARS)
	player:EvaluateItems()
	item.refresh_craft_integrity(player)

	-- 审计材料：挂 imitate（仅 source=audit 的宝宝类）
	BP.refresh_audit_simulates(player)

	sound_tracker.PlayStackedSound(SoundEffect.SOUND_THUMBSUP, 1, 1, false, 0, 2)
	BP.close_panel()
	-- Pickup 会自动放下；LiftItem 需再播 HideItem，否则一直举着
	if gained and gained > 0 then
		player:AnimateCollectible(gained, "Pickup", "PlayerPickupSparkle")
		local shown = BP.lang_is_zh() and rec.display_name or rec.display_name_en
		if shown and shown ~= "" then
			local config = Isaac.GetItemConfig():GetCollectible(gained)
			local translated = item_displaying_holder.check_description(
				"Item",
				gained,
				auxi.check_name_data(config and config.Name or ""),
				auxi.check_name_data(config and config.Description or ""),
				player
			)
			local desc = (translated and translated.Description)
				or auxi.check_name_data(config and config.Description or "")
			-- ItemDesc：走模组公示通道，且不覆盖自定义型号名
			item_displaying_holder.check_and_description("ItemDesc", gained, shown, desc, player)
		end
	end
end

function BP.cancel_edit(panel)
	-- 退出时暂存草稿，下次进入自动填回
	BP.leave_craft_view(panel)
	sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_DARK, 0.5, 1, false, 0, 2)
end

function BP.remove_token_entity(craft, tok)
	if not craft or not tok then return end
	BP.clear_token_slot(craft, tok)
	craft.token_map[tok.id] = nil
	for i = #craft.tokens, 1, -1 do
		if craft.tokens[i] == tok or craft.tokens[i].id == tok.id then
			table.remove(craft.tokens, i)
		end
	end
end

-- ---------- 拖放 ----------
function BP.finish_drag(panel, content_right, geom)
	local drag = panel.drag
	if not drag or not panel.craft then return end
	local craft = panel.craft
	local tok = craft.token_map[drag.token_id]
	panel.drag = nil
	if not tok then return end
	craft._bag_dirty = true
	geom = geom or (panel.ui and panel.ui.craft_geom)

	local in_slot = nil
	for i, slot in ipairs(craft.slots) do
		if slot._rect and Mouse_UI.point_in_rect(tok.pos, slot._rect) then
			in_slot = i
			break
		end
	end
	local snap_i, slot_d = BP.find_snap_slot(craft, tok)
	local cost_ok, cost_d, in_cost = BP.find_snap_cost(craft, tok, geom)
	local in_mirror = false
	if geom and geom.mirror_rect and BP.can_assign_mirror(craft, tok) then
		in_mirror = Mouse_UI.point_in_rect(tok.pos, geom.mirror_rect) == true
		if not in_mirror and geom.mirror_pos then
			local d = (tok.pos - geom.mirror_pos):Length()
			if d <= (item.snap_dist or 34) then in_mirror = true end
		end
	end
	local use_cost = false
	local use_slot = nil
	local use_mirror = false
	-- 底座槽几乎贴着椭圆底部的模块槽；松手时必须先认框，再比距离，否则模块永远吸不进底座。
	if in_mirror then
		use_mirror = true
	elseif in_slot then
		use_slot = in_slot
	elseif in_cost then
		use_cost = true
	elseif cost_ok and snap_i then
		if (cost_d or 1e9) <= (slot_d or 1e9) then
			use_cost = true
		else
			use_slot = snap_i
		end
	elseif cost_ok then
		use_cost = true
	elseif snap_i then
		use_slot = snap_i
	end
	if use_mirror then
		BP.assign_mirror_token(craft, tok, geom)
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BUTTON_PRESS, 0.7, 1.05, false, 0, 2)
	elseif use_slot then
		BP.assign_token_slot(craft, tok, use_slot)
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BUTTON_PRESS, 0.7, 1.05, false, 0, 2)
	elseif use_cost then
		BP.assign_token_cost(craft, tok, geom)
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_BUTTON_PRESS, 0.65, 0.95, false, 0, 2)
	else
		BP.clear_token_slot(craft, tok)
		if BP.is_mirror_only_token(tok) then
			BP.remove_token_entity(craft, tok)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_DARK, 0.4, 1, false, 0, 2)
			return
		end
		if craft.all_items and not tok.from_bag and type(tok.id) == "string" and tok.id:sub(1, 5) == "inst_" then
			BP.remove_token_entity(craft, tok)
			sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_DARK, 0.4, 1, false, 0, 2)
			return
		end
		-- 卸到背包区：非审计失去道具改为幽灵，重进草稿仍可还原
		if not craft.all_items then
			local old_bag_home = tok.from_bag and tok.home or nil
			tok.from_bag = true
			if tok.lost or tok.lost_ghost then
				tok.lost_ghost = true
				tok.lost = true
			end
			-- 本来就来自背包的 token 先回原网格；_bag_dirty 重建会再将
			-- home 校正为当前排序下的第一空位。只有无背包身份的被挤出件
			-- 才使用列表下方的临时锚点。
			local dest = old_bag_home or BP.bag_area_anchor(tok)
			tok.home = dest
		end
		local vel = tok.vel
		if vel:Length() < 0.8 then vel = Mouse_UI.mouse_delta end
		if vel:Length() > item.inertia_max then vel = vel:Resized(item.inertia_max) end
		tok.vel = vel * 0.65
		if tok.from_bag and tok.home then
			if tok.vel:Length() < 2.5 then
				BP.begin_snap_anim(tok, tok.home)
			end
		end
		sound_tracker.PlayStackedSound(SoundEffect.SOUND_MENU_FLIP_DARK, 0.4, 1, false, 0, 2)
	end
end

end

return M
