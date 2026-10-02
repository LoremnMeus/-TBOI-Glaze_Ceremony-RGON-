local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")
local record_holder = require("Qing_Remaster_scripts.others.Record_holder")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder")
local pedestal_encounter = require("Qing_Remaster_scripts.others.Pedestal_Encounter_holder")
local morph_txn = require("Qing_Remaster_scripts.others.Pickup_Morph_Transaction_holder")

local item = {
	ToCall = {},
	myToCall = {},
	pre_myToCall = {},
	entity = enums.Items.Perhaps_Chosen,
	own_key = "Item_Perhaps_Chosen_",
	debug_audit = {
		-- triggered_* 兼容旧名：现表示「收到 normal Encounter 并排队/挂接」
		new_host_hits = 0,
		fresh_hits = 0,
		not_fresh_blocks = 0,
		same_generation_blocks = 0,
		restore_blocks = 0,
		encounter_targets_queued = 0,
		encounter_targets_resolved = 0,
		encounter_targets_lost = 0,
		last_generation_id = nil,
		last_target_generation_id = nil,
		last_attached_generation_id = nil,
		morph_txn_opened = 0,
		morph_txn_pickup_confirmed = 0,
		morph_txn_external_finalized = 0,
		morph_txn_consumed_finalized = 0,
		morph_txn_lost = 0,
		morph_pre_captured = 0,
		morph_post_paired = 0,
		morph_pair_mismatch = 0,
		morph_state_switch_ignored = 0,
		last_morph_token = nil,
		last_morph_post_generation = nil,
		last_morph_result = nil,
		last_morph_kind = nil,
		morph_rebind_ok = false,
		morph_restore_called = 0,
		morph_restore_cycle_before = nil,
		morph_restore_cycle_after = nil,
		last_pre_token = nil,
		last_pre_old_generation = nil,
		last_post_generation = nil,
		-- Morph PRE raw binding diagnostics（不参与 gameplay）
		pre_raw_seen = 0,
		pre_raw_missing = 0,
		pre_raw_carrier = false,
		pre_raw_token = nil,
		pre_raw_state = nil,
		pre_raw_abandoned = nil,
		pre_raw_record_id = nil,
		pre_refresh_would_succeed = nil,
	},
	-- DEBUG-ONLY：Carrier Morph 事务级 trace（Summary 数据源；不改 gameplay）
	debug_morph_trace = {
		next_case_id = 0,
		cases = {},
		order = {},
	},
	_pending_encounter_hosts = {},
	-- generation_id → true：Encounter 一次性 birth 判决已完成（非 Carrier identity）
	_natural_birth_seen = {},
	-- pending_token → MATERIALIZED payload（业务快照；不是 entity identity）
	_carrier_payload_by_token = {},
	-- pending_token → morph txn（跨 callback 顺序，非跨房存档）
	_carrier_morph_txns = {},
	-- pending_token → frame（pickup-before-morph 短命证据，frame_delta<=1）
	_carrier_recent_pickups = {},
	pre_ToCall = {},
}

-- DEBUG-ONLY：Morph case presentation / binding 观察窗（冻结 diagnosis 用）。
-- 不是 gameplay settle；external Morph 只做一次 restore。
local MORPH_CASE_OBSERVE_FRAMES = 8

-- 本道具有独立 Seija 增幅，排除 Reverie 默认反转。
auxi.add_to_seija(item.entity)

local STATE_KEY = item.own_key
local HOLD_PARAMS = {
	ignore_subtype = true,
	consistance = true,
	zero_subtype_is_transient = true,
}
local MORPH_POLICY = {zero_subtype_is_transient = true}

local function debug_root()
	local root = save.ModConfigSettings
	local options = root and root.QingRemasterOptions
	return options and options.Debug
end

function item.force_seija()
	local debug = debug_root()
	return debug and debug.PerhapsChosenForceSeija == true
end

--- Q0：走 Seija 增幅判定；不要求当前持有本道具（Pending 兑现时也可能未持有）。
function item.is_seija_active()
	if item.force_seija() then return true end
	return auxi.should_do_Seija_all(true) == true
end

--- Pending queue：QUEUED tokens。MATERIALIZED 不在 queue 中。
local function state()
	local st = save.elses[STATE_KEY]
	if type(st) ~= "table" then
		st = {queue = {}, next_token = 0}
		save.elses[STATE_KEY] = st
	end
	if type(st.queue) ~= "table" then
		st.queue = {}
	end
	-- 兼容旧档：pending=true → 一条队列
	if st.pending == true and #st.queue == 0 then
		local before = #st.queue
		st.queue[1] = {
			token = 1,
			has_price = st.pending_is_shop == true,
			price = st.pending_price,
			was_shop_item = st.pending_is_shop == true,
		}
		st.next_token = 1
		if debug_queue_mutation then
			debug_queue_mutation("P_QUEUE_PUSH", "legacy_migration", {
				token = 1,
				count_before = before,
				tokens_before = {},
			})
		end
	end
	st.pending = nil
	st.pending_price = nil
	st.pending_is_shop = nil
	if type(st.next_token) ~= "number" then
		st.next_token = #st.queue
	end
	return st
end

local function pending_queue()
	return state().queue
end

local function pending_count()
	return #pending_queue()
end

--- queue 仅表示尚未实体化的 entry（QUEUED）。
local function has_queued_pending()
	return pending_count() > 0
end

-- Forward: queue mutation 会在 debug_note 定义后挂接 instrumentation。
local clear_pending
local push_queue_entry
local arm_pending_from_pickup
local remove_token_from_queue
local debug_note
local debug_queue_mutation
local debug_queue_fields
local debug_pending_tokens_copy
-- quote helpers 定义较后；natural / migrate / spawn 需同文件 local 闭包
local apply_resolved_entry_quote
local sync_carrier_quote_from_holder
local final_sync_materialized_quotes

local function alloc_token()
	local st = state()
	st.next_token = (st.next_token or 0) + 1
	return st.next_token
end

--- Queue/carrier 报价：quote_state 与 has_price 分离。
--- 旧 pending_is_shop / is_shop 只迁移为 has_price；was_shop_item 未知则保持 nil（不编造）。
local QUOTE_UNRESOLVED = "unresolved"
local QUOTE_RESOLVED = "resolved"

local function normalize_queue_entry(entry)
	if not entry then return nil end
	local has_price = entry.has_price
	if has_price == nil and entry.is_shop ~= nil then
		has_price = entry.is_shop == true
	end
	local quote_state = entry.quote_state
	if quote_state ~= QUOTE_UNRESOLVED and quote_state ~= QUOTE_RESOLVED then
		if has_price ~= nil or entry.price ~= nil then
			quote_state = QUOTE_RESOLVED
		else
			quote_state = QUOTE_UNRESOLVED
		end
	end
	local was_shop = entry.was_shop_item
	if was_shop ~= nil then
		was_shop = was_shop == true
	end
	return {
		token = entry.token,
		quote_state = quote_state,
		has_price = has_price == true,
		price = entry.price,
		was_shop_item = was_shop,
	}
end

local function carrier_quote_state(data)
	if not data then return QUOTE_UNRESOLVED end
	if data.pending_quote_state == QUOTE_RESOLVED or data.pending_quote_state == QUOTE_UNRESOLVED then
		return data.pending_quote_state
	end
	if data.pending_has_price ~= nil or data.pending_is_shop ~= nil or data.pending_price ~= nil then
		return QUOTE_RESOLVED
	end
	return QUOTE_UNRESOLVED
end

local function carrier_has_price(data)
	if not data then return false end
	if carrier_quote_state(data) ~= QUOTE_RESOLVED then return false end
	if data.pending_has_price ~= nil then return data.pending_has_price == true end
	if data.pending_is_shop ~= nil then return data.pending_is_shop == true end
	return false
end

local function carrier_was_shop_item(data)
	if not data then return nil end
	if data.pending_was_shop_item ~= nil then
		return data.pending_was_shop_item == true
	end
	return nil
end

local function entry_from_carrier_price(data)
	if not data then return nil end
	local qstate = carrier_quote_state(data)
	local has = nil
	if qstate == QUOTE_RESOLVED then
		has = carrier_has_price(data)
	end
	return {
		token = data.pending_token,
		quote_state = qstate,
		has_price = has == true,
		price = data.pending_price,
		was_shop_item = carrier_was_shop_item(data),
	}
end

--- 仅分配 token；报价 UNRESOLVED，禁止在 birth 瞬间把 live Price 当真相。
local function make_pending_entry(_pickup)
	return {
		token = alloc_token(),
		quote_state = QUOTE_UNRESOLVED,
		has_price = nil,
		price = nil,
		was_shop_item = nil,
	}
end

local function ensure_data(ent)
	if not ent then return nil end
	local d = ent:GetData()
	d._Data = d._Data or {}
	d._Data[item.own_key] = d._Data[item.own_key] or {}
	return d._Data[item.own_key]
end

local function read_data(ent)
	if not ent then return nil end
	local d = ent:GetData()
	if not d._Data then return nil end
	return d._Data[item.own_key]
end

--- Morph 路径禁止用 GetPtrHash 穿越 Morph。Carrier 业务身份 = pending_token。
local function game_frame()
	local f = 0
	pcall(function()
		f = Game():GetFrameCount()
	end)
	return f
end

local MAX_DEBUG_EVENTS = 512

--- DEBUG-ONLY：只读 pending token 列表副本（不暴露 queue 表）。
debug_pending_tokens_copy = function()
	local q = pending_queue()
	local tokens = {}
	for i = 1, #q do
		tokens[i] = q[i] and q[i].token
	end
	return tokens
end

--- DEBUG-ONLY：廉价 queue/scalar 快照。禁止在此扫房 / Consistance refresh。
debug_queue_fields = function()
	return {
		pending_count = pending_count(),
		pending_tokens = debug_pending_tokens_copy(),
		attach_transactions_this_room = item._attach_transactions_this_room or 0,
		attach_scheduled = item._attach_scheduled == true,
		target_queue_len = #(item._pending_encounter_hosts or {}),
	}
end

debug_note = function(kind, payload)
	item._debug_events = item._debug_events or {}
	local row = type(payload) == "table" and payload or {}
	row.kind = kind
	row.frame = game_frame()
	-- 只合并廉价 queue 字段；不得自动 count_active_carriers / 全房扫描
	local qf = debug_queue_fields()
	for k, v in pairs(qf) do
		if row[k] == nil then
			row[k] = v
		end
	end
	item._debug_events[#item._debug_events + 1] = row
	while #item._debug_events > MAX_DEBUG_EVENTS do
		table.remove(item._debug_events, 1)
	end
end

debug_queue_mutation = function(kind, reason, opts)
	opts = opts or {}
	local before = tonumber(opts.count_before)
	if before == nil then before = pending_count() end
	local before_tokens = opts.tokens_before or debug_pending_tokens_copy()
	local after = pending_count()
	debug_note(kind, {
		reason = reason or "unspecified",
		token = opts.token,
		tokens = opts.tokens,
		count_before = before,
		count_after = after,
		tokens_before = before_tokens,
		tokens_after = debug_pending_tokens_copy(),
		generation_id = opts.generation_id,
	})
end

clear_pending = function(reason)
	local before = pending_count()
	local before_tokens = debug_pending_tokens_copy()
	local st = state()
	st.queue = {}
	st.next_token = 0
	if before > 0 or reason then
		debug_queue_mutation("P_QUEUE_CLEAR", reason or "unspecified", {
			count_before = before,
			tokens_before = before_tokens,
		})
	end
end

push_queue_entry = function(entry, reason)
	if not entry then return end
	local before = pending_count()
	local before_tokens = debug_pending_tokens_copy()
	local q = pending_queue()
	local norm = normalize_queue_entry(entry)
	if not norm then return end
	q[#q + 1] = norm
	debug_queue_mutation("P_QUEUE_PUSH", reason or "unspecified", {
		token = entry.token,
		count_before = before,
		tokens_before = before_tokens,
	})
end

--- DEPRECATED：自然放弃不得 alloc 新 token。保留空壳防外部误调用。
arm_pending_from_pickup = function(_pickup)
	debug_note("P_ARM_PENDING_DEPRECATED", { note = "use ensure+requeue same token" })
end

local function get_bound_record_id(ent)
	if not ent then return nil end
	local d = ent:GetData()
	local names = d and d._Consistance_holder_names
	local id = names and names[item.own_key]
	if id == nil then return nil end
	return tostring(id)
end

local function copy_carrier_snapshot(src)
	if not src then return nil end
	local legacy_resolved = (src.pending_has_price ~= nil) or (src.pending_is_shop ~= nil) or (src.pending_price ~= nil)
	return {
		identity = src.identity and {
			init_seed = src.identity.init_seed,
			type = src.identity.type,
			variant = src.identity.variant,
		} or nil,
		record_id = src.record_id and tostring(src.record_id) or nil,
		pending_token = src.pending_token,
		pending_quote_state = src.pending_quote_state
			or (legacy_resolved and QUOTE_RESOLVED or QUOTE_UNRESOLVED),
		pending_has_price = (src.pending_has_price == true)
			or (src.pending_has_price == nil and src.pending_is_shop == true)
			or nil,
		pending_price = src.pending_price,
		pending_was_shop_item = (src.pending_was_shop_item ~= nil) and (src.pending_was_shop_item == true) or nil,
		pending_entry_state = src.pending_entry_state or "materialized",
		abandoned_carrier = src.abandoned_carrier == true,
		options_index = src.options_index,
		perhaps_cycle_injected = src.perhaps_cycle_injected == true,
		reserved_lock = src.reserved_lock,
	}
end

local function build_carrier_snapshot(pickup, record_id)
	local data = read_data(pickup)
	if not data or data.is_carrier ~= true then return nil end
	if record_id == nil then
		record_id = get_bound_record_id(pickup)
	end
	local qstate = carrier_quote_state(data)
	return {
		identity = {
			init_seed = pickup.InitSeed,
			type = pickup.Type,
			variant = pickup.Variant,
		},
		record_id = record_id and tostring(record_id) or nil,
		pending_token = data.pending_token,
		pending_quote_state = qstate,
		pending_has_price = (qstate == QUOTE_RESOLVED) and carrier_has_price(data) or nil,
		pending_price = data.pending_price,
		pending_was_shop_item = carrier_was_shop_item(data),
		pending_entry_state = data.pending_entry_state or "materialized",
		abandoned_carrier = data.abandoned_carrier == true,
		options_index = pickup.OptionsPickupIndex,
		perhaps_cycle_injected = data.perhaps_cycle_injected == true,
		reserved_lock = data.reserved_lock,
	}
end

--- PRE Morph：只读 live business binding；禁止 refresh / rematch / rehold。
local function read_live_materialized_carrier(pickup)
	if not pickup then return nil end
	local data = read_data(pickup)
	if not data then return nil end
	if data.is_carrier ~= true then return nil end
	if data.pending_token == nil then return nil end
	if (data.pending_entry_state or "materialized") ~= "materialized" then return nil end
	if data.abandoned_carrier == true then return nil end
	return data
end

--- PRE Morph snapshot：等同 build_carrier_snapshot，但命名强调无 Consistance mutation。
local function build_live_carrier_snapshot(pickup)
	return build_carrier_snapshot(pickup, get_bound_record_id(pickup))
end

--- 仅当 lifecycle probe 已加载且启用时，做 DEBUG-ONLY refresh 对照（不参与 capture 结果）。
local function pre_capture_refresh_compare_allowed()
	local mod = package.loaded["Qing_Remaster_scripts.others.perhaps_chosen_lifecycle_probe"]
	if type(mod) ~= "table" or not mod.get_config then return false end
	local cfg = mod.get_config()
	return cfg and cfg.enabled == true
end

local MAX_MORPH_CASES = 32

local function ensure_morph_trace()
	item.debug_morph_trace = item.debug_morph_trace or {
		next_case_id = 0,
		cases = {},
		order = {},
	}
	local tr = item.debug_morph_trace
	tr.cases = tr.cases or {}
	tr.order = tr.order or {}
	return tr
end

local function morph_trace_clear()
	item.debug_morph_trace = {
		next_case_id = 0,
		cases = {},
		order = {},
	}
end

local function morph_trace_get(case_id)
	if case_id == nil then return nil end
	local tr = ensure_morph_trace()
	return tr.cases[case_id]
end

local function morph_trace_prune(tr)
	while #tr.order > MAX_MORPH_CASES do
		local old_id = table.remove(tr.order, 1)
		tr.cases[old_id] = nil
	end
end

local function presentation_contains_perhaps(subtype, cycle)
	if subtype == item.entity then return true end
	if type(cycle) ~= "table" then return false end
	for _, id in ipairs(cycle) do
		if id == item.entity then return true end
	end
	return false
end

local function morph_case_set_diagnosis(case, diag)
	if case then
		case.diagnosis = diag
	end
end

local function morph_case_refresh_final(case)
	if not case then return end
	local obs = case.observations
	local last = (type(obs) == "table" and #obs > 0) and obs[#obs] or nil
	if last then
		-- 有 observation 时 final 只能来自最后一帧；禁止再 fallback 到 POST transient
		case.final = {
			generation_id = last.generation_id,
			token = case.token,
			subtype = last.subtype,
			cycle = last.cycle or {},
			contains_perhaps = last.contains_perhaps == true
				or presentation_contains_perhaps(last.subtype, last.cycle),
			is_carrier = last.is_carrier,
			entry_state = last.state,
			found = last.found,
			raw_token = last.raw_token,
			from = "last_observation",
		}
		return
	end
	local rest = case.restore or {}
	local post = case.post or {}
	local cycle = rest.cycle_after or post.cycle or {}
	local subtype = post.subtype
	case.final = {
		generation_id = post.generation_id,
		token = case.token,
		subtype = subtype,
		cycle = cycle,
		contains_perhaps = presentation_contains_perhaps(subtype, cycle),
		is_carrier = nil,
		entry_state = nil,
		from = "post_or_restore_fallback",
	}
end

local function cycle_has_perhaps(cycle)
	if type(cycle) ~= "table" then return false end
	for _, id in ipairs(cycle) do
		if id == item.entity then return true end
	end
	return false
end

--- DEBUG-ONLY：STATE_SWITCH / SAME_LIFETIME 观察窗结束后的 presentation 诊断。
local function morph_case_finalize_state_switch_diagnosis(case)
	if not case then return end
	morph_case_refresh_final(case)
	local post = case.post or {}
	local post_has = post.contains_perhaps == true
	local obs = case.observations or {}
	local saw_found = false
	local any_has = false
	local identity_lost = false
	for _, o in ipairs(obs) do
		if o.found == true then
			saw_found = true
			if case.token ~= nil then
				if o.raw_token == nil then
					-- G 在但无 Carrier binding
					identity_lost = true
				elseif o.raw_token ~= case.token then
					identity_lost = true
				end
			end
			if o.contains_perhaps == true then
				any_has = true
			end
		end
	end
	local final_has = case.final and case.final.contains_perhaps == true
	if identity_lost then
		morph_case_set_diagnosis(case, "STATE_SWITCH_CARRIER_IDENTITY_LOST")
	elseif #obs > 0 and not saw_found then
		morph_case_set_diagnosis(case, "STATE_SWITCH_TARGET_LOST")
	elseif not post_has and any_has and final_has then
		morph_case_set_diagnosis(case, "STATE_SWITCH_TRANSIENT_THEN_STABLE")
	elseif post_has and final_has then
		morph_case_set_diagnosis(case, "STATE_SWITCH_STABLE")
	elseif not final_has then
		morph_case_set_diagnosis(case, "STATE_SWITCH_PRESENTATION_LOST")
	else
		morph_case_set_diagnosis(case, "STATE_SWITCH_STABLE")
	end
	case.phase = "state_switch_complete"
end

local function morph_case_finalize_diagnosis(case)
	if not case then return end
	if case.kind == "state_switch"
		or case.phase == "state_switch_observing"
		or case.phase == "state_switch_complete"
	then
		morph_case_finalize_state_switch_diagnosis(case)
		return
	end
	morph_case_refresh_final(case)
	if case.phase == "pre_captured" then
		morph_case_set_diagnosis(case, "PRE_CAPTURED_NO_POST")
		return
	end
	local txn = case.transaction or {}
	if txn.lost then
		morph_case_set_diagnosis(case, "SUPERSEDE_TXN_LOST")
		return
	end
	if txn.rebind and txn.rebind.ok == false then
		morph_case_set_diagnosis(case, "REBIND_FAILED")
		return
	end
	local rest = case.restore or {}
	if rest.called and rest.result == "restore_add_failed" then
		morph_case_set_diagnosis(case, "RESTORE_ADD_FAILED")
		return
	end
	local after_has = cycle_has_perhaps(rest.cycle_after)
	local final_has = case.final and case.final.contains_perhaps == true
	if after_has and not final_has then
		morph_case_set_diagnosis(case, "RESTORE_THEN_CYCLE_LOST")
		return
	end
	if final_has then
		morph_case_set_diagnosis(case, "RESTORE_STABLE")
		return
	end
	if rest.called then
		morph_case_set_diagnosis(case, "RESTORE_MISSING_PERHAPS")
		return
	end
	morph_case_set_diagnosis(case, "EXTERNAL_COMPLETE")
end

local function morph_trace_new_case(token, pre_fields)
	local tr = ensure_morph_trace()
	tr.next_case_id = (tonumber(tr.next_case_id) or 0) + 1
	local id = tr.next_case_id
	local case = {
		case_id = id,
		token = token,
		phase = "pre_captured",
		diagnosis = nil,
		kind = "carrier_morph",
		pre = pre_fields,
		post = nil,
		transaction = {
			opened = false,
			finalized = false,
			lost = false,
			rebind = nil,
		},
		restore = {},
		observations = {},
		observe = nil,
		final = nil,
	}
	tr.cases[id] = case
	tr.order[#tr.order + 1] = id
	morph_trace_prune(tr)
	return case
end


--- 仅同步业务 payload_by_token；不建 ptr Morph bridge。
local function update_runtime_snapshot(pickup, record_id)
	local snapshot = build_carrier_snapshot(pickup, record_id)
	if not snapshot then return end
	local token = snapshot.pending_token
	if token == nil then return end
	item._carrier_payload_by_token = item._carrier_payload_by_token or {}
	item._carrier_payload_by_token[token] = copy_carrier_snapshot(snapshot)
end

local function forget_carrier_runtime(pickup)
	local data = pickup and read_data(pickup)
	local token = data and data.pending_token
	if token ~= nil and item._carrier_payload_by_token then
		item._carrier_payload_by_token[token] = nil
	end
end

local function clear_carrier_runtime()
	item._carrier_payload_by_token = {}
end

local function clear_carrier_morph_runtime()
	item._carrier_morph_txns = {}
	item._carrier_recent_pickups = {}
	clear_carrier_runtime()
end

local function prune_stale_recent_pickups()
	local recent = item._carrier_recent_pickups
	if not recent then return end
	local frame = game_frame()
	for token, f in pairs(recent) do
		if type(f) ~= "number" or (frame - f) > 1 then
			recent[token] = nil
		end
	end
end

local function clear_pc_binding_slots(pickup)
	if not pickup then return end
	local d = pickup:GetData()
	d._Data = d._Data or {}
	d._Consistance_holder_names = d._Consistance_holder_names or {}
	d._Data[item.own_key] = nil
	d._Consistance_holder_names[item.own_key] = nil
end

--- Live Carrier data 或已知 token 的 payload。禁止 post-morph 用 ptr 恢复旧 token。
local function runtime_snapshot_for(pickup)
	local data = read_data(pickup)
	if data and data.is_carrier == true then
		return build_carrier_snapshot(pickup)
	end
	local token = data and data.pending_token
	if token ~= nil and item._carrier_payload_by_token then
		return copy_carrier_snapshot(item._carrier_payload_by_token[token])
	end
	return nil
end

local function hold_flags(ent, flags)
	local data = ensure_data(ent)
	if not data then return nil end
	if flags then
		for k, v in pairs(flags) do
			data[k] = v
		end
	end
	local record_id = consistance_holder.try_hold_entity(ent, item.own_key, HOLD_PARAMS)
	if data.is_carrier == true then
		update_runtime_snapshot(ent, record_id)
	end
	return data
end

local function refresh_flags(ent)
	if not ent then return nil end
	if consistance_holder.try_check_entity(ent, item.own_key, false, HOLD_PARAMS) then
		return read_data(ent)
	end
	return read_data(ent)
end

--- 异常兜底：Consistance 读不到但 runtime 仍有 materialized 快照时，按当前 InitSeed 新建 record。
local function fallback_rehold_from_runtime(pickup)
	local snapshot = runtime_snapshot_for(pickup)
	if not snapshot then return nil end
	if snapshot.abandoned_carrier == true then return nil end
	if (snapshot.pending_entry_state or "materialized") ~= "materialized" then return nil end
	print("[PerhapsChosen] carrier_consistance_fallback_rebind")
	if snapshot.identity then
		pcall(function()
			consistance_holder.supersede_family(snapshot.identity)
		end)
	else
		pcall(function()
			consistance_holder.supersede_entity(pickup)
		end)
	end
	clear_pc_binding_slots(pickup)
	local d = pickup:GetData()
	d._Data = d._Data or {}
	d._Data[item.own_key] = {
		is_carrier = true,
		pending_token = snapshot.pending_token,
		pending_quote_state = snapshot.pending_quote_state
			or ((((snapshot.pending_has_price ~= nil) or (snapshot.pending_is_shop ~= nil) or (snapshot.pending_price ~= nil)) and QUOTE_RESOLVED) or QUOTE_UNRESOLVED),
		pending_has_price = (snapshot.pending_has_price == true) or (snapshot.pending_has_price == nil and snapshot.pending_is_shop == true) or nil,
		pending_price = snapshot.pending_price,
		pending_was_shop_item = (snapshot.pending_was_shop_item ~= nil) and (snapshot.pending_was_shop_item == true) or nil,
		pending_entry_state = snapshot.pending_entry_state or "materialized",
		perhaps_cycle_injected = snapshot.perhaps_cycle_injected == true,
		abandoned_carrier = nil,
		rejected_origin = nil,
	}
	local new_id = consistance_holder.try_hold_entity(pickup, item.own_key, HOLD_PARAMS)
	update_runtime_snapshot(pickup, new_id)
	return read_data(pickup)
end

--- Pending entry 生命周期（唯一词汇）：
--- QUEUED(in queue) → MATERIALIZED(on Carrier, q-1) → CONSUMED | REQUEUED(q+1 once)

local function entry_from_data(data)
	if not data then return nil end
	return entry_from_carrier_price(data)
end

local function apply_carrier_hold(carrier, extra)
	local data = refresh_flags(carrier) or ensure_data(carrier)
	if not data then return nil end
	local flags = {
		is_carrier = true,
		abandoned_carrier = data.abandoned_carrier,
		rejected_origin = nil,
		pending_token = data.pending_token,
		pending_quote_state = carrier_quote_state(data),
		pending_has_price = data.pending_has_price,
		pending_price = data.pending_price,
		pending_was_shop_item = carrier_was_shop_item(data),
		pending_entry_state = data.pending_entry_state or "materialized",
		perhaps_cycle_injected = data.perhaps_cycle_injected == true,
		reserved_lock = data.reserved_lock,
		reserved_cycle_paused = data.reserved_cycle_paused == true,
		reserved_cycle_snapshot = data.reserved_cycle_snapshot,
		reserved_frozen_subtype = data.reserved_frozen_subtype,
	}
	if extra then
		for k, v in pairs(extra) do
			flags[k] = v
		end
	end
	return hold_flags(carrier, flags)
end

local function entry_from_carrier(carrier)
	return entry_from_data(refresh_flags(carrier))
end

--- Authoritative MATERIALIZED choice：只看业务绑定，不看 SubType/cycle。
local function get_materialized_choice(pickup)
	if not pickup then return nil end
	local data = refresh_flags(pickup) or read_data(pickup)
	if not data then return nil end
	if data.is_carrier ~= true then return nil end
	if data.pending_token == nil then return nil end
	local st = data.pending_entry_state or "materialized"
	if st ~= "materialized" then return nil end
	return data
end

--- MATERIALIZED → QUEUED（同一 token，仅一次）。使用保存的原始 price/shop，不读当前 Price。
--- Entity 上的 pending_entry_state 在此之后表示 token 已入队；实体本身即将被清理。
local function notify_reserved_judgment_invalidate(pickup)
	local modname = "Qing_Remaster_scripts.items.Item_Reserved_Judgment"
	local rj = package.loaded[modname]
	if not rj then
		local ok, loaded = pcall(require, modname)
		if ok then rj = loaded end
	end
	if rj and rj.InvalidateSourcePickup then
		rj.InvalidateSourcePickup(pickup)
	end
end

local function requeue_carrier_entry(carrier)
	local data = get_materialized_choice(carrier)
	if not data then return false end
	local token = data.pending_token
	if data.reserved_lock ~= nil then return false end
	do
		local q = pending_queue()
		for _, e in ipairs(q) do
			if e.token == token then return true end
		end
	end
	notify_reserved_judgment_invalidate(carrier)
	push_queue_entry(entry_from_data(data), "requeue_carrier")
	apply_carrier_hold(carrier, {
		pending_entry_state = "queued",
		abandoned_carrier = true,
	})
	return true
end

--- Dead-wrapper / snapshot path：同一 T 入队一次；复用 normalize_queue_entry，禁止 alloc。
local function requeue_token_from_snapshot(token, snapshot, reason)
	if token == nil then return false end
	local snap = snapshot and copy_carrier_snapshot(snapshot) or nil
	if not snap and item._carrier_payload_by_token then
		snap = copy_carrier_snapshot(item._carrier_payload_by_token[token])
	end
	do
		local q = pending_queue()
		for _, e in ipairs(q) do
			if e.token == token then return true end
		end
	end
	if not snap then return false end
	if snap.abandoned_carrier == true then return false end
	if snap.reserved_lock ~= nil then return false end
	if (snap.pending_entry_state or "materialized") == "consumed" then return false end
	push_queue_entry({
		token = token,
		quote_state = snap.pending_quote_state
			or ((((snap.pending_has_price ~= nil) or (snap.pending_price ~= nil)) and QUOTE_RESOLVED) or QUOTE_UNRESOLVED),
		has_price = (snap.pending_has_price == true),
		price = snap.pending_price,
		was_shop_item = (snap.pending_was_shop_item ~= nil) and (snap.pending_was_shop_item == true) or nil,
	}, reason or "requeue_token_snapshot")
	if item._carrier_payload_by_token then
		item._carrier_payload_by_token[token] = nil
	end
	return true
end

remove_token_from_queue = function(token, reason)
	if token == nil then return end
	local before = pending_count()
	local before_tokens = debug_pending_tokens_copy()
	local q = pending_queue()
	local removed = false
	for i = #q, 1, -1 do
		if q[i].token == token then
			table.remove(q, i)
			removed = true
		end
	end
	if removed then
		debug_queue_mutation("P_QUEUE_REMOVE", reason or "unspecified", {
			token = token,
			count_before = before,
			tokens_before = before_tokens,
		})
	end
end

--- 正式选择 Carrier：CONSUMED，不改 queue（生成时已 q-1）。
local function consume_carrier_entry(carrier)
	local data = get_materialized_choice(carrier)
	if not data then
		data = refresh_flags(carrier)
		if not data or data.is_carrier ~= true then return false end
	end
	if data.pending_entry_state == "consumed" then return true end
	local queue_before = debug_pending_tokens_copy()
	local token = data.pending_token
	notify_reserved_judgment_invalidate(carrier)
	remove_token_from_queue(data.pending_token, "consume_terminal")
	apply_carrier_hold(carrier, {
		pending_entry_state = "consumed",
		abandoned_carrier = nil,
		reserved_lock = nil,
		reserved_cycle_paused = nil,
		reserved_cycle_snapshot = nil,
		reserved_frozen_subtype = nil,
	})
	forget_carrier_runtime(carrier)
	return true
end

--- 无实体时按 token 标记 CONSUMED（主动交换 / Morph txn finalize）。
local function consume_token_terminal(token)
	if token == nil then return false end
	local queue_before = debug_pending_tokens_copy()
	remove_token_from_queue(token, "consume_terminal")
	if item._carrier_payload_by_token then
		item._carrier_payload_by_token[token] = nil
	end
	if item._carrier_morph_txns then
		item._carrier_morph_txns[token] = nil
	end
	if item._carrier_recent_pickups then
		item._carrier_recent_pickups[token] = nil
	end
	return true
end

--- 同组「别的选项被选」导致本底座被引擎移除。
--- MATERIALIZED token → QUEUED（同一 token；禁止 arm 新 token）。
local materialize_natural_perhaps_if_needed
local function note_option_group_reject(pickup)
	local data = get_materialized_choice(pickup)
	if not data then
		data = fallback_rehold_from_runtime(pickup)
		if data and data.is_carrier == true and data.pending_token ~= nil
			and (data.pending_entry_state or "materialized") == "materialized" then
			-- recovered binding
		else
			-- 仅尚未绑定 token 时才允许 natural discovery
			materialize_natural_perhaps_if_needed(pickup)
			data = get_materialized_choice(pickup)
		end
	end
	if get_materialized_choice(pickup) then
		requeue_carrier_entry(pickup)
	end
end

--- Record_holder：仅在 Option_Index_holder 显式 sibling-reject 证据下兑现。
--- 权威证据 = was_rejected_by_selection（不依赖死实体 GetData）。
local function watch_for_option_reject(pickup)
	if not pickup then return end
	if pedestal_encounter.is_death_certificate_display(pickup) then
		return
	end
	update_runtime_snapshot(pickup)
	local watch_snap = copy_carrier_snapshot(build_carrier_snapshot(pickup) or runtime_snapshot_for(pickup))
	local watch_token = watch_snap and watch_snap.pending_token or nil
	record_holder.try_hold(pickup, {
		key = item.own_key.."opt",
		Function = function(tp, et)
			if tp ~= "Remove" then return end
			local data = get_materialized_choice(et) or read_data(et)
			local token = (data and data.pending_token) or watch_token
			local rejected = option_index_holder.was_rejected_by_selection(et)
			local pickup_confirmed = token ~= nil
				and item._carrier_recent_pickups
				and item._carrier_recent_pickups[token] ~= nil
			if pickup_confirmed then
				return
			end
			if not rejected then
				return
			end
			if get_materialized_choice(et) then
				requeue_carrier_entry(et)
			else
				requeue_token_from_snapshot(token, watch_snap, "option_sibling_reject")
			end
		end,
	})
end

--- Legacy field: is_carrier == true means this pedestal currently materializes a Perhaps token.
--- Natural and rematerialized Perhaps use the same state (see ai_context/items/perhaps_chosen.md).
local function is_carrier(ent)
	local data = refresh_flags(ent)
	return data and data.is_carrier == true
end

local function is_active_carrier(ent)
	return get_materialized_choice(ent) ~= nil
end

local function count_active_carriers()
	local n = 0
	local list = auxi.getothers(nil, EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)
	for _, ent in ipairs(list) do
		if is_active_carrier(ent) then
			n = n + 1
		end
	end
	return n
end

local function has_unresolved_choice()
	return has_queued_pending() or count_active_carriers() > 0
end

--- Visual/cycle presentation only：当前显示或 cycle 中含「似有所选」。
--- 禁止用作 natural token 分配、Carrier identity、consume/requeue/Morph ownership。
local function pedestal_involves_perhaps_chosen(pickup)
	if not pickup then return false end
	if pickup.SubType == item.entity then return true end
	if not pickup.GetCollectibleCycle then return false end
	local ok, cycle = pcall(function()
		return pickup:GetCollectibleCycle()
	end)
	if not ok or type(cycle) ~= "table" then return false end
	for _, id in ipairs(cycle) do
		if id == item.entity then return true end
	end
	return false
end

--- 开放 Morph txn 已认领的 post generation：禁止 natural 再 alloc。
local function post_generation_owned_by_open_morph_txn(pickup)
	local txns = item._carrier_morph_txns
	if not txns or not pickup then return false end
	local gen = unique_holder.resolve_generation(pickup)
	local gid = gen and gen.id
	if gid == nil then return false end
	for _, txn in pairs(txns) do
		if txn and txn.finalized ~= true and txn.post_generation_id == gid then
			return true
		end
	end
	return false
end

--- PRE 已捕获、txn 尚未打开：同帧 Morph 目标 pedestal 禁止 natural alloc。
local function pending_pre_morph_targets_pickup(pickup)
	return morph_txn.has_open_pre_targeting(pickup)
end

--- 仅发现「尚无 token 的自然 Perhaps」并 MATERIALIZE。
--- INIT：仅主 SubType == Perhaps + fresh → 立刻 alloc（cycle 未就绪不得 negative-lock）。
--- Encounter：稳定 one-shot opportunity；SubType 或 cycle 含 Perhaps → 一次 birth 判决并锁 seen。
--- cycle alone 不足以 alloc；必须同时是新机会。
materialize_natural_perhaps_if_needed = function(pickup, opts)
	opts = opts or {}
	if not pickup or not pickup:Exists() then return nil end
	if item._spawning_carrier then return nil end
	if pedestal_encounter.is_death_certificate_display(pickup) then return nil end

	local existing = get_materialized_choice(pickup)
	if existing then
		watch_for_option_reject(pickup)
		return existing
	end

	local data = refresh_flags(pickup) or read_data(pickup)
	-- 已有 token 绑定（含 queued/consumed）：禁止再当 natural 发现并 alloc
	if data and data.pending_token ~= nil then
		return nil
	end
	if data and data.is_carrier == true then
		return nil
	end
	if data and data.pending_entry_state == "consumed" then
		return nil
	end

	-- Morph 事务窗口：PRE 已捕获或 post generation 已认领 → 只允许同 T rebind
	if pending_pre_morph_targets_pickup(pickup) then
		return nil
	end
	if post_generation_owned_by_open_morph_txn(pickup) then
		return nil
	end

	local gen = unique_holder.resolve_generation(pickup)
	local gid = gen and gen.id or nil
	item._natural_birth_seen = item._natural_birth_seen or {}
	local from_encounter = opts.from_encounter == true

	if from_encounter then
		-- Encounter：该 generation 的一次性稳定 birth 判决
		if gid ~= nil and item._natural_birth_seen[gid] == true then
			return nil
		end
		local content_ok = pickup.SubType == item.entity
			or pedestal_involves_perhaps_chosen(pickup)
		if gid ~= nil then
			item._natural_birth_seen[gid] = true
		end
		if not content_ok then
			return nil
		end
	else
		-- INIT / 非 Encounter：只认确定性主 SubType；不因 cycle 未就绪写 seen
		if pickup.SubType ~= item.entity then
			return nil
		end
		local fresh = false
		if gid ~= nil then
			pcall(function()
				fresh = unique_holder.is_fresh_generation(pickup) == true
			end)
		end
		if not fresh then
			return nil
		end
		if gid ~= nil and item._natural_birth_seen[gid] == true then
			return nil
		end
		if gid ~= nil then
			item._natural_birth_seen[gid] = true
		end
	end

	local entry = make_pending_entry(pickup)
	hold_flags(pickup, {
		is_carrier = true,
		abandoned_carrier = nil,
		rejected_origin = nil,
		pending_token = entry.token,
		pending_quote_state = QUOTE_UNRESOLVED,
		pending_has_price = nil,
		pending_price = nil,
		pending_was_shop_item = nil,
		pending_entry_state = "materialized",
	})
	apply_carrier_hold(pickup, {
		abandoned_carrier = nil,
		pending_token = entry.token,
		pending_quote_state = QUOTE_UNRESOLVED,
		pending_has_price = nil,
		pending_price = nil,
		pending_was_shop_item = nil,
		pending_entry_state = "materialized",
	})
	watch_for_option_reject(pickup)
	debug_note("P_TOKEN_CREATED", {
		token = entry.token,
		subtype = pickup.SubType,
		from_encounter = from_encounter,
		generation_id = gid,
		quote_state = QUOTE_UNRESOLVED,
	})
	debug_note("P_NATURAL_MATERIALIZE", {
		token = entry.token,
		subtype = pickup.SubType,
		from_encounter = from_encounter,
		generation_id = gid,
	})
	sync_carrier_quote_from_holder(pickup)
	return get_materialized_choice(pickup)
end

local function carrier_contains_perhaps(pickup)
	return pedestal_involves_perhaps_chosen(pickup)
end

--- 只补缺失的「似有所选」，绝不 RemoveCollectibleCycle / 清轮换。
--- 普通 visual ensure：稳定 Carrier 上去重，可因 contains 短路。
local function ensure_carrier_contains_perhaps(pickup)
	if not pickup or not pickup:Exists() then return end
	if not is_active_carrier(pickup) then return end
	if pickup.SubType == 0 then return end
	if carrier_contains_perhaps(pickup) then return end
	if not pickup.AddCollectibleCycle then return end
	local ok = pcall(function()
		pickup:AddCollectibleCycle(item.entity)
	end)
	if not ok then return end
	pickup:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
	apply_carrier_hold(pickup, {
		perhaps_cycle_injected = true,
	})
end

local function debug_cycle_ids_local(pickup)
	if not pickup or not pickup.GetCollectibleCycle then return {} end
	local ok, cycle = pcall(function()
		return pickup:GetCollectibleCycle()
	end)
	if not ok or type(cycle) ~= "table" then return {} end
	local out = {}
	for i, id in ipairs(cycle) do
		out[i] = id
	end
	return out
end

--- External Morph 权威恢复：只保证 G2 选择里存在 Perhaps；禁止清空/重建整个 cycle。
--- 只做一次 best-effort Add；不再做 gameplay N-frame repeated settle。
--- DEBUG：arm Morph case observe 窗，等 stable 后再 freeze diagnosis。
local function inject_perhaps_choice_member(pickup)
	if not pickup or not pickup:Exists() then return false end
	if pickup.SubType == item.entity then return true end
	if carrier_contains_perhaps(pickup) then return true end
	if not pickup.AddCollectibleCycle then return false end
	local ok = pcall(function()
		pickup:AddCollectibleCycle(item.entity)
	end)
	if not ok then return false end
	pickup:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
	apply_carrier_hold(pickup, {
		perhaps_cycle_injected = true,
	})
	return pickup.SubType == item.entity or carrier_contains_perhaps(pickup)
end

local function arm_morph_case_observe(case, token, generation_id)
	if not case then return end
	case.observe = {
		active = true,
		frames_left = MORPH_CASE_OBSERVE_FRAMES,
		frames_total = MORPH_CASE_OBSERVE_FRAMES,
		generation_id = generation_id,
		post_generation_id = generation_id,
		token = token or case.token,
		started_frame = game_frame(),
	}
	if case.kind == "state_switch" or case.phase == "state_switch_observing" then
		morph_case_set_diagnosis(case, "STATE_SWITCH_OBSERVING")
	else
		case.phase = "external_observing"
		morph_case_set_diagnosis(case, "EXTERNAL_OBSERVING")
	end
end

local function restore_perhaps_after_external_morph(pickup, _snapshot, token, case_id)
	if not pickup or not pickup:Exists() then return false end
	local data = get_materialized_choice(pickup)
	if not data or data.pending_token ~= token then
		local case = morph_trace_get(case_id)
		if case then
			case.restore = {
				called = true,
				frame = game_frame(),
				cycle_before = {},
				cycle_after = {},
				result = "restore_binding_missing",
			}
			morph_case_finalize_diagnosis(case)
		end
		return false
	end
	local a = item.debug_audit
	local before = debug_cycle_ids_local(pickup)
	if a then
		a.morph_restore_called = (tonumber(a.morph_restore_called) or 0) + 1
		a.morph_restore_cycle_before = before
		a.morph_rebind_ok = true
	end

	-- 禁止 RemoveCollectibleCycle / 全量 rebuild：Perhaps 不是 cycle editor
	local injected = inject_perhaps_choice_member(pickup)
	local after = debug_cycle_ids_local(pickup)
	local result = injected and "restore_ok" or "restore_add_failed"
	if a then
		a.morph_restore_cycle_after = after
		a.last_morph_result = result
	end
	local case = morph_trace_get(case_id)
	if case then
		local gen = unique_holder.resolve_generation(pickup)
		case.restore = {
			called = true,
			frame = game_frame(),
			cycle_before = before,
			cycle_after = after,
			result = result,
			contains_before = cycle_has_perhaps(before),
			contains_after = cycle_has_perhaps(after) or pickup.SubType == item.entity,
		}
		-- diagnosis 等观察窗 freeze；不在 POST 当帧定案
		arm_morph_case_observe(case, token, gen and gen.id or nil)
	end
	return true
end

--- 跨帧允许：按 pending_token 找 materialized Carrier（禁止 ptr）。
local function find_carrier_by_token(token)
	if token == nil then return nil end
	local list = auxi.getothers(nil, EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)
	for _, ent in ipairs(list) do
		local pickup = ent:ToPickup()
		if pickup then
			local data = get_materialized_choice(pickup)
			if data and data.pending_token == token then
				return pickup
			end
		end
	end
	return nil
end

local function ensure_carrier_contains_perhaps_by_token(token)
	local pickup = find_carrier_by_token(token)
	if pickup then
		ensure_carrier_contains_perhaps(pickup)
	end
	return pickup
end

local function find_collectible_by_generation_id(generation_id)
	if generation_id == nil then return nil end
	local list = auxi.getothers(nil, EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)
	for _, ent in ipairs(list) do
		local pickup = ent:ToPickup()
		if pickup then
			local gen = unique_holder.resolve_generation(pickup)
			if gen and gen.id == generation_id then
				return pickup
			end
		end
	end
	return nil
end

--- 仅移除本 owner 注入的 Perhaps，保留其它 cycle 项与顺序。
local function remove_owner_injected_perhaps_cycle(pickup)
	if not pickup or not pickup:Exists() then return false end
	local data = refresh_flags(pickup) or read_data(pickup)
	if not (data and data.perhaps_cycle_injected == true) then
		return false
	end
	if not pickup.GetCollectibleCycle or not pickup.RemoveCollectibleCycle then
		return false
	end
	local ok, cycle = pcall(function()
		return pickup:GetCollectibleCycle()
	end)
	if not ok or type(cycle) ~= "table" then return false end
	local keep = {}
	local had_perhaps = false
	for _, id in ipairs(cycle) do
		if id == item.entity then
			had_perhaps = true
		else
			keep[#keep + 1] = id
		end
	end
	local subtype_is_perhaps = pickup.SubType == item.entity
	if not had_perhaps and not subtype_is_perhaps then
		apply_carrier_hold(pickup, { perhaps_cycle_injected = false })
		return false
	end
	pcall(function()
		pickup:RemoveCollectibleCycle()
	end)
	if subtype_is_perhaps then
		-- SubType 本身是 Perhaps：清 cycle 即可；不重加 Perhaps
		for _, id in ipairs(keep) do
			pcall(function()
				pickup:AddCollectibleCycle(id)
			end)
		end
	else
		for _, id in ipairs(keep) do
			pcall(function()
				pickup:AddCollectibleCycle(id)
			end)
		end
	end
	apply_carrier_hold(pickup, { perhaps_cycle_injected = false })
	return true
end

--- External Morph（D6 等无成功拾取）：同 token 保留 MATERIALIZED，重建 payload。
local function migrate_carrier_after_external_morph(pickup, snapshot, token, case_id)
	if not pickup or not pickup:Exists() then return false end
	if pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then return false end
	if not snapshot then return false end
	if token == nil then return false end
	if snapshot.abandoned_carrier == true then return false end
	if (snapshot.pending_entry_state or "materialized") ~= "materialized" then return false end

	pcall(function()
		record_holder.release_entity(pickup, item.own_key .. "opt")
	end)

	if snapshot.identity then
		pcall(function()
			consistance_holder.supersede_family(snapshot.identity)
		end)
	else
		pcall(function()
			consistance_holder.supersede_entity(pickup)
		end)
	end

	clear_pc_binding_slots(pickup)
	local d = pickup:GetData()
	d._Data = d._Data or {}
	d._Data[item.own_key] = {
		is_carrier = true,
		pending_token = token,
		pending_quote_state = snapshot.pending_quote_state
			or (((snapshot.pending_has_price ~= nil) or (snapshot.pending_is_shop ~= nil) or (snapshot.pending_price ~= nil)) and QUOTE_RESOLVED or QUOTE_UNRESOLVED),
		pending_has_price = (snapshot.pending_has_price == true) or (snapshot.pending_has_price == nil and snapshot.pending_is_shop == true) or nil,
		pending_price = snapshot.pending_price,
		pending_was_shop_item = (snapshot.pending_was_shop_item ~= nil) and (snapshot.pending_was_shop_item == true) or nil,
		pending_entry_state = "materialized",
		-- old generation presentation；new generation 由 restore 重建
		perhaps_cycle_injected = nil,
		abandoned_carrier = nil,
		rejected_origin = nil,
	}

	local new_record_id = consistance_holder.try_hold_entity(pickup, item.own_key, HOLD_PARAMS)

	local snap_state = snapshot.pending_quote_state
		or (((snapshot.pending_has_price ~= nil) or (snapshot.pending_is_shop ~= nil) or (snapshot.pending_price ~= nil)) and QUOTE_RESOLVED or QUOTE_UNRESOLVED)
	local snap_has = (snapshot.pending_has_price == true) or (snapshot.pending_has_price == nil and snapshot.pending_is_shop == true)
	if snap_state == QUOTE_RESOLVED then
		apply_resolved_entry_quote(pickup, {
			quote_state = QUOTE_RESOLVED,
			has_price = snap_has == true,
			price = snapshot.pending_price,
			was_shop_item = (snapshot.pending_was_shop_item ~= nil) and (snapshot.pending_was_shop_item == true) or nil,
		})
	end

	pickup:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
	watch_for_option_reject(pickup)
	update_runtime_snapshot(pickup, new_record_id)
	local case = morph_trace_get(case_id)
	if case then
		case.transaction = case.transaction or {}
		case.transaction.rebind = {
			ok = new_record_id ~= nil,
			frame = game_frame(),
			token = token,
			generation_id = (unique_holder.resolve_generation(pickup) or {}).id,
			record_id = new_record_id and tostring(new_record_id) or nil,
		}
		if new_record_id == nil then
			case.transaction.rebind.ok = false
			case.transaction.rebind.reason = "try_hold_failed"
		end
	end
	restore_perhaps_after_external_morph(pickup, snapshot, token, case_id)
	return true
end

local function release_perhaps_owner_on_pickup(pickup)
	if not pickup then return end
	pcall(function()
		record_holder.release_entity(pickup, item.own_key .. "opt")
	end)
	remove_owner_injected_perhaps_cycle(pickup)
	local data = refresh_flags(pickup) or read_data(pickup)
	if data and data.is_carrier == true then
		clear_pc_binding_slots(pickup)
		pcall(function()
			consistance_holder.try_remove_entity(pickup, item.own_key)
		end)
	end
	forget_carrier_runtime(pickup)
end

local function finalize_consumed_swap(txn)
	local a = item.debug_audit
	local token = txn.token

	local post = find_collectible_by_generation_id(txn.post_generation_id)
	local leftover = find_carrier_by_token(token)

	consume_token_terminal(token)

	if post then
		release_perhaps_owner_on_pickup(post)
	end
	if leftover then
		local leftover_gen = unique_holder.resolve_generation(leftover)
		local leftover_gid = leftover_gen and leftover_gen.id or nil
		local same_post = post and leftover_gid ~= nil and leftover_gid == txn.post_generation_id
		if not same_post then
			release_perhaps_owner_on_pickup(leftover)
		end
	end

	if a then
		a.morph_txn_consumed_finalized = (tonumber(a.morph_txn_consumed_finalized) or 0) + 1
		a.last_morph_token = token
		a.last_morph_post_generation = txn.post_generation_id
		a.last_morph_result = "consumed"
	end
end

local function finalize_external_morph(txn)
	local a = item.debug_audit
	local token = txn.token
	local snapshot = txn.snapshot
	local case_id = txn.case_id
	local case = morph_trace_get(case_id)
	local post = find_collectible_by_generation_id(txn.post_generation_id)
	if not post then
		if snapshot and (snapshot.pending_entry_state or "materialized") == "materialized" then
			push_queue_entry({
				token = token,
				quote_state = snapshot.pending_quote_state
					or ((((snapshot.pending_has_price ~= nil) or (snapshot.pending_is_shop ~= nil) or (snapshot.pending_price ~= nil)) and QUOTE_RESOLVED) or QUOTE_UNRESOLVED),
				has_price = (snapshot.pending_has_price == true) or (snapshot.pending_has_price == nil and snapshot.pending_is_shop == true),
				price = snapshot.pending_price,
				was_shop_item = (snapshot.pending_was_shop_item ~= nil) and (snapshot.pending_was_shop_item == true) or nil,
			}, "requeue_carrier")
		end
		if a then
			a.morph_txn_lost = (tonumber(a.morph_txn_lost) or 0) + 1
			a.last_morph_token = token
			a.last_morph_post_generation = txn.post_generation_id
			a.last_morph_result = "lost_requeued"
		end
		if case then
			case.transaction = case.transaction or {}
			case.transaction.lost = true
			case.transaction.finalized = true
			case.phase = "external_txn_lost"
			morph_case_set_diagnosis(case, "SUPERSEDE_TXN_LOST")
		end
		if item._carrier_morph_txns then
			item._carrier_morph_txns[token] = nil
		end
		return
	end

	migrate_carrier_after_external_morph(post, snapshot, token, case_id)

	if a then
		a.morph_txn_external_finalized = (tonumber(a.morph_txn_external_finalized) or 0) + 1
		a.last_morph_token = token
		a.last_morph_post_generation = txn.post_generation_id
		if a.last_morph_result ~= "restore_ok" and a.last_morph_result ~= "restore_add_failed" then
			a.last_morph_result = "external_materialized"
		end
	end
	case = morph_trace_get(case_id)
	if case then
		case.transaction = case.transaction or {}
		case.transaction.finalized = true
		case.transaction.opened = true
		case.phase = "external_finalized"
		if case.observe and case.observe.active then
			-- probe will fill observations; provisional diagnosis until observe ends
			morph_case_set_diagnosis(case, "EXTERNAL_OBSERVING")
		else
			morph_case_finalize_diagnosis(case)
		end
	end
	if item._carrier_morph_txns then
		item._carrier_morph_txns[token] = nil
	end
end

local function finalize_carrier_morph_txn(txn)
	if not txn or txn.finalized then return end
	txn.finalized = true
	if txn.pickup_confirmed then
		finalize_consumed_swap(txn)
	else
		finalize_external_morph(txn)
	end
end

local function strip_live_carrier_claim(pickup)
	if not pickup then return end
	pcall(function()
		record_holder.release_entity(pickup, item.own_key .. "opt")
	end)
	clear_pc_binding_slots(pickup)
	pcall(function()
		consistance_holder.try_remove_entity(pickup, item.own_key)
	end)
end

--- POST 配对成功后开长期 txn。禁止从 post entity / ptr 恢复旧 token。
local function open_carrier_morph_txn_from_pre(pickup, pre_txn, post_generation_id)
	local snapshot = pre_txn and pre_txn.snapshot
	local token = pre_txn and pre_txn.token
	if token == nil or not snapshot then return nil end
	local frame = game_frame()
	item._carrier_morph_txns = item._carrier_morph_txns or {}
	item._carrier_recent_pickups = item._carrier_recent_pickups or {}

	local pickup_confirmed = false
	local recent_frame = item._carrier_recent_pickups[token]
	if type(recent_frame) == "number" and (frame - recent_frame) <= 1 then
		pickup_confirmed = true
	end

	local existing = item._carrier_morph_txns[token]
	if existing and existing.finalized ~= true then
		existing.post_generation_id = post_generation_id or existing.post_generation_id
		existing.old_generation_id = pre_txn.old_generation_id or existing.old_generation_id
		existing.case_id = existing.case_id or pre_txn.case_id
		if pickup_confirmed then
			existing.pickup_confirmed = true
		end
		strip_live_carrier_claim(pickup)
		return existing
	end

	local txn = {
		token = token,
		case_id = pre_txn.case_id,
		snapshot = copy_carrier_snapshot(snapshot),
		old_generation_id = pre_txn.old_generation_id,
		opened_frame = frame,
		post_generation_id = post_generation_id,
		pickup_confirmed = pickup_confirmed,
		finalized = false,
	}
	item._carrier_morph_txns[token] = txn
	strip_live_carrier_claim(pickup)

	local case = morph_trace_get(pre_txn.case_id)
	if case then
		case.phase = "external_txn_open"
		case.transaction = case.transaction or {}
		case.transaction.opened = true
		case.transaction.post_generation_id = post_generation_id
		case.transaction.old_generation_id = pre_txn.old_generation_id
	end

	local a = item.debug_audit
	if a then
		a.morph_txn_opened = (tonumber(a.morph_txn_opened) or 0) + 1
		a.last_morph_token = token
		a.last_morph_post_generation = post_generation_id
		a.last_post_generation = post_generation_id
		a.last_morph_result = "opened"
		if pickup_confirmed then
			a.morph_txn_pickup_confirmed = (tonumber(a.morph_txn_pickup_confirmed) or 0) + 1
		end
	end
	return txn
end

--- PRE capture payload for Pickup_Morph_Transaction_holder（只读 live binding；不改实体）。
local function capture_carrier_morph_snapshot(pickup)
	if not pickup then return nil end

	local a = item.debug_audit
	local raw = read_data(pickup)
	if a then
		a.pre_raw_seen = (tonumber(a.pre_raw_seen) or 0) + 1
		a.pre_raw_carrier = raw and raw.is_carrier == true
		a.pre_raw_token = raw and raw.pending_token or nil
		a.pre_raw_state = raw and raw.pending_entry_state or nil
		a.pre_raw_abandoned = raw and raw.abandoned_carrier == true or false
		a.pre_raw_record_id = get_bound_record_id(pickup)
		a.pre_refresh_would_succeed = nil
	end

	local data = read_live_materialized_carrier(pickup)
	if not data then
		if a then
			a.pre_raw_missing = (tonumber(a.pre_raw_missing) or 0) + 1
			a.last_morph_result = "pre_raw_binding_missing"
			if pre_capture_refresh_compare_allowed() then
				a.pre_refresh_would_succeed = get_materialized_choice(pickup) ~= nil
			end
		end
		debug_note("pre_non_carrier", {
			subtype = pickup.SubType,
			raw_carrier = raw and raw.is_carrier == true,
			raw_token = raw and raw.pending_token or nil,
			raw_state = raw and raw.pending_entry_state or nil,
			record_id = get_bound_record_id(pickup),
		})
		return nil
	end

	local snapshot = build_live_carrier_snapshot(pickup)
	if not snapshot then
		if a then
			a.pre_raw_missing = (tonumber(a.pre_raw_missing) or 0) + 1
			a.last_morph_result = "pre_raw_snapshot_missing"
		end
		return nil
	end
	update_runtime_snapshot(pickup)

	local gen = unique_holder.resolve_generation(pickup)
	local cycle = debug_cycle_ids_local(pickup)
	local case = morph_trace_new_case(data.pending_token, {
		frame = game_frame(),
		generation_id = gen and gen.id or nil,
		init_seed = pickup.InitSeed,
		subtype = pickup.SubType,
		cycle = cycle,
		record_id = get_bound_record_id(pickup),
		raw_carrier = true,
		raw_token = data.pending_token,
		raw_state = data.pending_entry_state or "materialized",
		raw_abandoned = false,
		state = data.pending_entry_state or "materialized",
		contains_perhaps = presentation_contains_perhaps(pickup.SubType, cycle),
	})

	local pre = {
		token = data.pending_token,
		case_id = case.case_id,
		snapshot = copy_carrier_snapshot(snapshot),
		old_generation_id = gen and gen.id or nil,
	}

	if a then
		a.morph_pre_captured = (tonumber(a.morph_pre_captured) or 0) + 1
		a.last_pre_token = pre.token
		a.last_pre_old_generation = pre.old_generation_id
		a.last_morph_token = pre.token
		a.last_morph_result = "pre_captured"
	end
	return pre
end

local function handle_carrier_morph_txn(txn)
	if not txn or not txn.target then
		return
	end
	local p = txn.target
	local pre = txn.source_snapshot
	if not pre then
		return
	end
	local a = item.debug_audit
	if txn.target_mismatch and a then
		a.morph_pair_mismatch = (tonumber(a.morph_pair_mismatch) or 0) + 1
		a.last_morph_result = "pair_target_mismatch"
	elseif a then
		a.morph_post_paired = (tonumber(a.morph_post_paired) or 0) + 1
	end

	local kind = txn.kind
	if a then
		a.last_morph_kind = kind
	end

	local case = morph_trace_get(pre.case_id)
	local post_cycle = debug_cycle_ids_local(p)
	local gen_now = unique_holder.resolve_generation(p)
	local post_fields = {
		frame = game_frame(),
		generation_id = gen_now and gen_now.id or nil,
		subtype = p.SubType,
		cycle = post_cycle,
		morph_kind = kind,
		contains_perhaps = presentation_contains_perhaps(p.SubType, post_cycle),
	}
	if case then
		case.post = post_fields
	end

	if kind == "STATE_SWITCH" or kind == "SAME_LIFETIME" then
		if a then
			a.morph_state_switch_ignored = (tonumber(a.morph_state_switch_ignored) or 0) + 1
			a.last_morph_token = pre.token
			a.last_morph_result = "state_switch_ignored"
		end
		if case then
			local gid = post_fields.generation_id
				or (case.pre and case.pre.generation_id)
				or nil
			case.phase = "state_switch_observing"
			case.kind = "state_switch"
			arm_morph_case_observe(case, case.token, gid)
		end
		local data = get_materialized_choice(p)
		if data then
			ensure_carrier_contains_perhaps(p)
		end
		return
	end

	if kind ~= "SUPERSEDE" then
		if a then
			a.last_morph_result = "morph_kind_" .. tostring(kind)
		end
		if case then
			case.phase = "morph_kind_" .. tostring(kind)
			morph_case_set_diagnosis(case, "POST_PAIR_NON_SUPERSEDE")
		end
		return
	end

	local post_generation_id = gen_now and gen_now.id or nil
	if a then
		a.last_post_generation = post_generation_id
	end
	if case then
		case.phase = "external_txn_open"
	end
	open_carrier_morph_txn_from_pre(p, pre, post_generation_id)
end

local function resolve_carrier_token_from_pickup_event(ent)
	if not ent then return nil, nil, nil end
	local data = get_materialized_choice(ent)
	if data then
		return data.pending_token, data, "carrier_data"
	end
	-- 拾取瞬间可能仍挂着 is_carrier 但 refresh 尚未完整：读 raw binding
	data = refresh_flags(ent) or read_data(ent)
	if data and data.is_carrier == true and data.pending_token ~= nil then
		return data.pending_token, data, "carrier_data"
	end
	-- 已进入 Morph txn：用 post_generation_id 关联，禁止 ptr
	local gen = unique_holder.resolve_generation(ent)
	local gid = gen and gen.id or nil
	if gid ~= nil and item._carrier_morph_txns then
		for token, txn in pairs(item._carrier_morph_txns) do
			if txn and txn.finalized ~= true and txn.post_generation_id == gid then
				return token, txn.snapshot, "morph_txn"
			end
		end
	end
	return nil, nil, nil
end

local function mark_carrier_pickup_confirmed(token)
	if token == nil then return end
	local frame = game_frame()
	item._carrier_recent_pickups = item._carrier_recent_pickups or {}
	item._carrier_recent_pickups[token] = frame
	item._carrier_morph_txns = item._carrier_morph_txns or {}
	local txn = item._carrier_morph_txns[token]
	if txn and txn.finalized ~= true then
		txn.pickup_confirmed = true
		local a = item.debug_audit
		if a then
			a.morph_txn_pickup_confirmed = (tonumber(a.morph_txn_pickup_confirmed) or 0) + 1
			a.last_morph_token = token
			a.last_morph_result = "pickup_confirmed"
		end
	end
end

local function tick_carrier_morph_txns()
	prune_stale_recent_pickups()
	local txns = item._carrier_morph_txns
	if not txns then return end
	local frame = game_frame()
	local pending = {}
	for token, txn in pairs(txns) do
		if txn and txn.finalized ~= true and type(txn.opened_frame) == "number" then
			local ready = false
			if txn.pickup_confirmed then
				ready = frame > txn.opened_frame
			else
				ready = frame > (txn.opened_frame + 1)
			end
			if ready then
				pending[#pending + 1] = txn
			end
		end
	end
	for _, txn in ipairs(pending) do
		finalize_carrier_morph_txn(txn)
	end
end

--- 无 Morph txn 的直接拾取：等过 opened frame 再 CONSUMED（覆盖 pickup-before-morph）。
local function tick_plain_carrier_consumes()
	local recent = item._carrier_recent_pickups
	if not recent then return end
	local frame = game_frame()
	local tokens = {}
	for token, f in pairs(recent) do
		if type(f) == "number" and frame > f then
			tokens[#tokens + 1] = token
		end
	end
	for _, token in ipairs(tokens) do
		local txn = item._carrier_morph_txns and item._carrier_morph_txns[token]
		if txn and txn.finalized ~= true then
			-- Morph 路径：由 finalize 统一 CONSUMED
		else
			local carrier = find_carrier_by_token(token)
			if carrier then
				consume_carrier_entry(carrier)
			else
				consume_token_terminal(token)
			end
			recent[token] = nil
		end
	end
end

--- DEBUG-ONLY：host 资格 reason（正式判定仍只返回 bool）。
--- Self-host / 已有 MATERIALIZED Perhaps 允许作为 QUEUED token 的 host（见 frozen design）。
local function debug_host_eligibility(pickup)
	if not pickup or not pickup:Exists() then return false, "missing" end
	if pickup.Type ~= EntityType.ENTITY_PICKUP then return false, "not_collectible" end
	if pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then return false, "not_collectible" end
	if pickup.SubType == 0 then return false, "subtype_zero" end
	if pedestal_encounter.is_death_certificate_display(pickup) then return false, "death_certificate_display" end
	if pickup.IsShopItem and pickup:IsShopItem() then return false, "shop" end
	if (pickup.Price or 0) ~= 0 then return false, "priced" end
	local spawner = pickup.SpawnerEntity
	if spawner and spawner.Type == EntityType.ENTITY_SLOT then return false, "slot_spawned" end
	return true, "ok"
end

local function is_perhaps_host_eligible(pickup)
	local ok = debug_host_eligibility(pickup)
	return ok == true
end

--- attach 计数仅 debug；不参与 eligibility。
local function note_attach_transaction(reason)
	item._attach_transactions_this_room = (item._attach_transactions_this_room or 0) + 1
	debug_note("P_ATTACH_TX", {
		reason = reason or "unspecified",
		count = item._attach_transactions_this_room,
	})
end

local function clear_encounter_targets(reason)
	local q = item._pending_encounter_hosts or {}
	local n = #q
	if n > 0 then
		debug_note("P_TARGET_QUEUE_CLEAR", {
			reason = reason or "unspecified",
			cleared = n,
		})
	end
	item._pending_encounter_hosts = {}
end

local function find_pickup_for_target(target)
	if not target or target.generation_id == nil then
		return nil
	end
	local want = tonumber(target.generation_id)
	-- Pedestal gameplay identity = generation_id（禁止用可能已 Morph/替换的旧 ptr 认领）
	for _, e in ipairs(Isaac.FindByType(5, 100, -1, false, false)) do
		local p = e:ToPickup()
		if p and (p.SubType or 0) > 0 then
			local gen = unique_holder.resolve_generation(p)
			if gen and tonumber(gen.id) == want then
				return p
			end
		end
	end
	return nil
end

--- 从 target pedestal 扩展当前 sibling 选择组（Perhaps 业务 grouping，非 Encounter identity）。
local function build_group_from_target(pickup)
	if not pickup then return nil, nil end
	local idx = tonumber(pickup.OptionsPickupIndex) or 0
	if idx <= 0 then
		idx = option_index_holder.find_a_new_index()
		pickup.OptionsPickupIndex = idx
	end
	local group = {}
	local seen = {}
	local list = auxi.getothers(nil, EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)
	for _, ent in ipairs(list) do
		local p = ent:ToPickup()
		if p and (p.SubType or 0) > 0 and (tonumber(p.OptionsPickupIndex) or 0) == idx then
			local ptr = GetPtrHash(p)
			if not seen[ptr] then
				seen[ptr] = true
				group[#group + 1] = p
			end
		end
	end
	local tptr = GetPtrHash(pickup)
	if not seen[tptr] then
		group[#group + 1] = pickup
	end
	return group, idx
end

--- 将已 RESOLVED 的 queue/snapshot 报价应用到 carrier：有价则 lock_price，免费不碰 Price。
apply_resolved_entry_quote = function(carrier, entry)
	if not carrier or not entry then return end
	local qstate = entry.quote_state
	if qstate ~= QUOTE_RESOLVED and qstate ~= QUOTE_UNRESOLVED then
		if entry.has_price ~= nil or entry.price ~= nil then
			qstate = QUOTE_RESOLVED
		else
			qstate = QUOTE_UNRESOLVED
		end
	end
	local has_price = entry.has_price
	if has_price == nil and entry.is_shop ~= nil then
		has_price = entry.is_shop == true
	end
	apply_carrier_hold(carrier, {
		pending_quote_state = qstate,
		pending_has_price = (qstate == QUOTE_RESOLVED) and (has_price == true) or nil,
		pending_price = entry.price,
		pending_was_shop_item = entry.was_shop_item,
	})
	if qstate == QUOTE_RESOLVED and has_price == true and type(entry.price) == "number" then
		price_holder.lock_price(carrier, entry.price, {
			was_shop_item = entry.was_shop_item == true,
		})
		debug_note("P_PRICE_LOCKED", {
			token = entry.token,
			price = entry.price,
		})
	end
end

local function persist_quote_into_carrier(pickup, quote, reason)
	if not pickup or not quote or quote.resolved ~= true then return false end
	local data = get_materialized_choice(pickup) or read_data(pickup)
	local before_state = data and carrier_quote_state(data) or QUOTE_UNRESOLVED
	local before_price = data and data.pending_price
	local before_has = data and data.pending_has_price
	apply_carrier_hold(pickup, {
		pending_quote_state = QUOTE_RESOLVED,
		pending_has_price = quote.has_price == true,
		pending_price = quote.has_price and quote.price or nil,
		pending_was_shop_item = quote.is_shop_item,
	})
	if before_state ~= QUOTE_RESOLVED then
		debug_note("P_QUOTE_RESOLVED", {
			token = data and data.pending_token,
			price = quote.has_price and quote.price or nil,
			has_price = quote.has_price == true,
			reason = reason or "capture",
		})
	elseif before_has ~= (quote.has_price == true) or before_price ~= quote.price then
		debug_note("P_QUOTE_CHANGED", {
			token = data and data.pending_token,
			price = quote.has_price and quote.price or nil,
			has_price = quote.has_price == true,
			reason = reason or "sync",
		})
	end
	return true
end

--- MATERIALIZED：UNRESOLVED 时 capture；已 RESOLVED 时跟随 price_holder 有效报价变化（不写 Price）。
sync_carrier_quote_from_holder = function(pickup, opts)
	opts = opts or {}
	if not pickup then return false end
	local data = get_materialized_choice(pickup)
	if not data then return false end
	local quote = price_holder.get_quote(pickup)
	local qstate = carrier_quote_state(data)

	if qstate == QUOTE_UNRESOLVED then
		local captured, ok = price_holder.capture_quote(pickup)
		if not (ok and captured and captured.resolved) then
			return false
		end
		quote = captured
	elseif opts.final == true then
		local captured, ok = price_holder.capture_quote(pickup)
		if ok and captured and captured.resolved then
			quote = captured
		elseif not (quote and quote.resolved) then
			return false
		end
	else
		if not (quote and quote.resolved) then
			return false
		end
		if price_holder.is_locked(pickup) then
			return persist_quote_into_carrier(pickup, quote, "locked_sync")
		end
		-- 同房折扣：仅当业务 snapshot 与 holder 有效报价不一致时再 capture
		local same = (data.pending_has_price == true) == (quote.has_price == true)
			and data.pending_price == quote.price
		if not same then
			local captured, ok = price_holder.capture_quote(pickup)
			if ok and captured and captured.resolved then
				quote = captured
			end
		else
			return true
		end
	end
	if not quote or quote.resolved ~= true then
		return false
	end
	return persist_quote_into_carrier(pickup, quote, opts.final and "final_sync" or "update_sync")
end

final_sync_materialized_quotes = function()
	local list = auxi.getothers(nil, EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)
	for _, ent in ipairs(list) do
		local pickup = ent:ToPickup()
		if pickup and get_materialized_choice(pickup) then
			sync_carrier_quote_from_holder(pickup, {final = true})
			local data = get_materialized_choice(pickup)
			debug_note("P_QUOTE_FINAL_SYNC", {
				token = data and data.pending_token,
				quote_state = data and carrier_quote_state(data),
				has_price = data and data.pending_has_price,
				price = data and data.pending_price,
			})
		end
	end
end

local function resolve_context_pool()
	local room = Game():GetRoom()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local pool = Game():GetItemPool():GetPoolForRoom(room:GetType(), desc.SpawnSeed)
	if pool == nil or pool < 0 then
		pool = ItemPoolType.POOL_TREASURE
	end
	return pool
end

local function roll_seija_bonus_id(rng)
	local pool = resolve_context_pool()
	local id = auxi.get_item_from_pool(pool, true, rng)
	if id == item.entity then
		rng:Next()
		id = auxi.get_item_from_pool(pool, true, rng)
	end
	if not id or id <= 0 or id == item.entity then
		return nil
	end
	return id
end

--- Seija：Carrier 初次生成时额外提供一次当前房道具池候选（可消耗 ItemPool）。
local function apply_seija_bonus(carrier)
	if not carrier or not carrier:Exists() then return end
	if not item.is_seija_active() then return end
	if not carrier.AddCollectibleCycle then return end
	local rng = RNG()
	local seed = carrier.InitSeed or carrier.DropSeed or Game():GetSeeds():GetStartSeed()
	if seed == 0 then seed = 1 end
	rng:SetSeed(seed, 35)
	rng = auxi.rng_for_sake(rng)
	local bonus_id = roll_seija_bonus_id(rng)
	if not bonus_id then return end
	pcall(function()
		carrier:AddCollectibleCycle(bonus_id)
	end)
	carrier:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
end

local function spawn_one_carrier(group, option_index, entry, spawn_index)
	if not group or #group == 0 or not entry then return nil end
	local room = Game():GetRoom()
	local anchor = group[1]
	local offset = Vector(40 * spawn_index, 0)
	local pos = room:FindFreePickupSpawnPosition(anchor.Position + offset, 10, true)
	item._spawning_carrier = true
	local carrier
	pedestal_encounter.with_suppressed_encounter(item.own_key, function()
		local spawned = Isaac.Spawn(
			EntityType.ENTITY_PICKUP,
			PickupVariant.PICKUP_COLLECTIBLE,
			item.entity,
			pos,
			Vector.Zero,
			nil
		)
		carrier = spawned and spawned:ToPickup()
		if carrier then
			pedestal_encounter.mark_suppressed(carrier, item.own_key)
		end
	end)
	item._spawning_carrier = nil
	if not carrier then return nil end

	local index = option_index
	if not index or index == 0 then
		index = option_index_holder.find_a_new_index()
		for _, host in ipairs(group) do
			host.OptionsPickupIndex = index
		end
		option_index = index
	end
	carrier.OptionsPickupIndex = index
	carrier:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
	hold_flags(carrier, {
		is_carrier = true,
		abandoned_carrier = nil,
		rejected_origin = nil,
		pending_token = entry.token,
		pending_quote_state = entry.quote_state or QUOTE_RESOLVED,
		pending_has_price = entry.has_price == true,
		pending_price = entry.price,
		pending_was_shop_item = entry.was_shop_item,
		pending_entry_state = "materialized",
	})
	apply_seija_bonus(carrier)
	carrier:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
	apply_carrier_hold(carrier, {
		abandoned_carrier = nil,
		pending_token = entry.token,
		pending_quote_state = entry.quote_state or QUOTE_RESOLVED,
		pending_has_price = entry.has_price == true,
		pending_price = entry.price,
		pending_was_shop_item = entry.was_shop_item,
		pending_entry_state = "materialized",
	})
	apply_resolved_entry_quote(carrier, entry)
	watch_for_option_reject(carrier)
	debug_note("P_MATERIALIZE", {
		token = entry.token,
		quote_state = entry.quote_state or QUOTE_RESOLVED,
		has_price = entry.has_price == true,
		price = entry.price,
	})
	Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, carrier.Position, Vector.Zero, nil)
	return carrier, option_index
end

--- 绑定到指定 Encounter target：只挂该 pedestal / 其当前选择组；失败不得改挂别处。
local function try_attach_for_target(target)
	if not target then return "bad_target" end
	if not has_queued_pending() then
		debug_note("P_ATTACH_SKIP", { reason = "no_pending", generation_id = target.generation_id })
		return "no_pending"
	end
	if item._spawning_carrier then return "busy" end

	item.debug_audit.last_target_generation_id = target.generation_id
	local pickup = find_pickup_for_target(target)
	debug_note("P_TARGET_RESOLVE", {
		generation_id = target.generation_id,
		found = pickup ~= nil,
	})
	if not pickup then
		item.debug_audit.encounter_targets_lost = (item.debug_audit.encounter_targets_lost or 0) + 1
		return "lost"
	end
	local eligible, elig_reason = debug_host_eligibility(pickup)
	debug_note("P_HOST_RECHECK", {
		generation_id = target.generation_id,
		eligible = eligible == true,
		reason = elig_reason,
	})
	if not eligible then
		item.debug_audit.encounter_targets_lost = (item.debug_audit.encounter_targets_lost or 0) + 1
		return "ineligible"
	end

	local group, option_index = build_group_from_target(pickup)
	if not group or #group == 0 then
		item.debug_audit.encounter_targets_lost = (item.debug_audit.encounter_targets_lost or 0) + 1
		return "no_group"
	end

	local q = pending_queue()
	local before = #q
	local before_tokens = debug_pending_tokens_copy()
	debug_note("P_QUEUE_BEFORE_MATERIALIZE", {
		generation_id = target.generation_id,
		count_before = before,
		tokens_before = before_tokens,
	})
	local entries = {}
	while #q > 0 do
		entries[#entries + 1] = table.remove(q, 1)
	end
	local drained_tokens = {}
	for i, e in ipairs(entries) do
		drained_tokens[i] = e.token
	end
	debug_queue_mutation("P_QUEUE_DRAIN", "materialize_for_target", {
		tokens = drained_tokens,
		count_before = before,
		tokens_before = before_tokens,
		generation_id = target.generation_id,
	})
	debug_note("P_QUEUE_AFTER_DRAIN", {
		generation_id = target.generation_id,
		drained = #entries,
		drained_tokens = drained_tokens,
	})

	local spawned_any = false
	for i, entry in ipairs(entries) do
		local carrier, new_index = spawn_one_carrier(group, option_index, entry, i)
		if new_index then
			option_index = new_index
		end
		if carrier then
			spawned_any = true
			debug_note("P_CARRIER_SPAWN", {
				token = entry.token,
				source_generation_id = target.generation_id,
			})
		else
			push_queue_entry(entry, "requeue_carrier")
			debug_note("P_CARRIER_SPAWN_FAIL", {
				token = entry.token,
				reason = "spawn_nil",
				source_generation_id = target.generation_id,
			})
		end
	end
	if spawned_any then
		note_attach_transaction("successful_attach")
		item.debug_audit.encounter_targets_resolved = (item.debug_audit.encounter_targets_resolved or 0) + 1
		item.debug_audit.last_attached_generation_id = target.generation_id
		item.debug_audit.last_generation_id = target.generation_id
		item.debug_audit.new_host_hits = (item.debug_audit.new_host_hits or 0) + 1
		item.debug_audit.fresh_hits = (item.debug_audit.fresh_hits or 0) + 1
		return "ok"
	end
	return "spawn_failed"
end

local function process_encounter_target_queue()
	debug_note("P_ATTACH_CALLBACK_BEGIN", {})
	while #(item._pending_encounter_hosts or {}) > 0 do
		if not has_queued_pending() then
			clear_encounter_targets("no_pending")
			debug_note("P_ATTACH_CALLBACK_END", { result = "cleared_targets", reason = "no_pending" })
			return
		end
		local target = table.remove(item._pending_encounter_hosts, 1)
		debug_note("P_TARGET_QUEUE_POP", { generation_id = target and target.generation_id, queue_len = #(item._pending_encounter_hosts or {}) })
		local result = try_attach_for_target(target)
		if result == "ok" then
			-- 成功 drain 后若仍有 target 但 queue 已空，清掉残留 host，避免卡住
			if not has_queued_pending() then
				clear_encounter_targets("queue_drained")
			end
			debug_note("P_ATTACH_CALLBACK_END", { result = result, generation_id = target and target.generation_id })
			return
		end
		-- lost / ineligible：丢弃该 target，尝试下一 Encounter，不得改挂
		debug_note("P_TARGET_ATTACH_RESULT", {
			generation_id = target and target.generation_id,
			result = result,
		})
	end
	debug_note("P_ATTACH_CALLBACK_END", { result = "queue_empty" })
end

local function schedule_process_encounter_targets()
	if #(item._pending_encounter_hosts or {}) == 0 then return end
	if not has_queued_pending() then return end
	-- 无证据表明 POST_PEDESTAL_ENCOUNTER 时 generation/host 未就绪；禁止无证据 ATTACH_DELAY。
	debug_note("P_ATTACH_SCHEDULED", {
		target_queue_len = #(item._pending_encounter_hosts or {}),
		immediate = true,
	})
	process_encounter_target_queue()
	if #(item._pending_encounter_hosts or {}) > 0 and has_queued_pending() then
		process_encounter_target_queue()
	end
end

local function enqueue_encounter_target(encounter)
	if not encounter then return end
	debug_note("P_ENCOUNTER_RECEIVED", {
		generation_id = encounter.generation_id,
		subtype = encounter.subtype,
	})
	if not has_queued_pending() then
		debug_note("P_ENCOUNTER_REJECTED", {
			reason = "no_pending",
			generation_id = encounter.generation_id,
		})
		return
	end
	local pickup = encounter.pickup
	if not pickup then
		debug_note("P_ENCOUNTER_REJECTED", {
			reason = "bad_pickup",
			generation_id = encounter.generation_id,
		})
		return
	end
	local eligible, elig_reason = debug_host_eligibility(pickup)
	if not eligible then
		debug_note("P_ENCOUNTER_REJECTED", {
			reason = "host_ineligible",
			detail = elig_reason,
			generation_id = encounter.generation_id,
		})
		return
	end
	local gid = encounter.generation_id
	if gid == nil then
		debug_note("P_ENCOUNTER_REJECTED", {
			reason = "no_generation",
			generation_id = nil,
		})
		return
	end
	item._pending_encounter_hosts = item._pending_encounter_hosts or {}
	item._pending_encounter_hosts[#item._pending_encounter_hosts + 1] = {
		generation_id = gid,
		options_index = pickup.OptionsPickupIndex or 0,
		queued_frame = game_frame(),
	}
	item.debug_audit.encounter_targets_queued = (item.debug_audit.encounter_targets_queued or 0) + 1
	item.debug_audit.last_target_generation_id = gid
	debug_note("P_TARGET_QUEUED", {
		generation_id = gid,
		queue_len = #item._pending_encounter_hosts,
	})
	schedule_process_encounter_targets()
end

local function token_already_queued(token)
	if token == nil then return false end
	local q = pending_queue()
	for _, e in ipairs(q) do
		if e.token == token then return true end
	end
	return false
end

local function reject_or_abandon_on_leave()
	local seen_tokens = {}
	local list = auxi.getothers(nil, EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)
	for _, ent in ipairs(list) do
		local pickup = ent:ToPickup()
		if pickup and pickup:Exists() then
			-- 主路径：业务 token 绑定（不依赖 SubType/cycle）
			if not get_materialized_choice(pickup) then
				fallback_rehold_from_runtime(pickup)
			end
			local data = get_materialized_choice(pickup)
			if data then
				local token = data.pending_token
				if token ~= nil then seen_tokens[token] = true end
				-- Reserved lock：跨层 commitment 由保留意见持有同一 token，禁止普通 requeue
				if data.reserved_lock ~= nil then
					-- 解除本房 carrier 表现；token 不进 queue、不 alloc
					apply_carrier_hold(pickup, {
						reserved_lock = data.reserved_lock,
						reserved_cycle_paused = true,
						pending_entry_state = "materialized",
						abandoned_carrier = nil,
					})
					forget_carrier_runtime(pickup)
					-- Consistance payload 仍可随 entity unload；业务 token 在 RJ offer
				else
					requeue_carrier_entry(pickup)
				end
			else
				-- 仅尚未绑定 token 的自然 Perhaps：补 MATERIALIZE 再 requeue 同一 token
				local raw = refresh_flags(pickup) or read_data(pickup)
				if not (raw and raw.pending_token ~= nil) then
					materialize_natural_perhaps_if_needed(pickup)
					data = get_materialized_choice(pickup)
					if data then
						local token = data.pending_token
						if token ~= nil then seen_tokens[token] = true end
						if data.reserved_lock ~= nil then
							forget_carrier_runtime(pickup)
						else
							requeue_carrier_entry(pickup)
						end
					end
				end
			end
		end
	end
	-- 未 finalize 的 morph txn / recent pickup：按 token 补一次 REQUEUE（禁止旧 ptr）
	for token, txn in pairs(item._carrier_morph_txns or {}) do
		if txn and txn.finalized ~= true and not seen_tokens[token] and not txn.pickup_confirmed then
			local snap = txn.snapshot
			local st = snap and (snap.pending_entry_state or "materialized") or "materialized"
			if st == "materialized" and not (snap and snap.abandoned_carrier == true) then
				if not token_already_queued(token) then
					push_queue_entry({
						token = token,
						quote_state = snap and (snap.pending_quote_state
							or ((((snap.pending_has_price ~= nil) or (snap.pending_is_shop ~= nil) or (snap.pending_price ~= nil)) and QUOTE_RESOLVED) or QUOTE_UNRESOLVED)),
						has_price = snap and ((snap.pending_has_price == true) or (snap.pending_has_price == nil and snap.pending_is_shop == true)),
						price = snap and snap.pending_price,
						was_shop_item = snap and ((snap.pending_was_shop_item ~= nil) and (snap.pending_was_shop_item == true) or nil),
					}, "requeue_carrier")
				end
			end
		end
	end
	-- 离房后 bridge/txn 结束；跨房身份只靠 Consistance + queue
	clear_carrier_morph_runtime()
end

local function cleanup_rejected_or_abandoned(pickup)
	local data = refresh_flags(pickup)
	if not data then return false end
	if data.abandoned_carrier == true and data.is_carrier == true then
		forget_carrier_runtime(pickup)
		consistance_holder.try_remove_entity(pickup, item.own_key)
		pickup:Remove()
		return true
	end
	if data.rejected_origin == true and data.is_carrier ~= true then
		consistance_holder.try_remove_entity(pickup, item.own_key)
		pickup:Remove()
		return true
	end
	return false
end

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_GAME_STARTED, params = nil,
Function = function(_, continue)
	item._attach_scheduled = false
	item._spawning_carrier = nil
	item._attach_transactions_this_room = 0
	item._natural_birth_seen = {}
	clear_encounter_targets("game_start")
	clear_carrier_morph_runtime()
	morph_trace_clear()
	item._debug_events = {}
	if not continue then
		clear_pending("game_start_reset")
		save.elses[STATE_KEY] = {queue = {}, next_token = 0}
	else
		state()
	end
end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.PRE_NEW_ROOM, params = nil,
Function = function(_)
	final_sync_materialized_quotes()
	reject_or_abandon_on_leave()
	clear_encounter_targets("new_room")
	item._natural_birth_seen = {}
end,
})

-- Rewind：只清 module-local transient。save.elses 队列已由 snapshot 权威恢复，禁止再清。
table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_REWIND, params = nil,
Function = function(_)
	item._attach_scheduled = false
	item._attach_transactions_this_room = 0
	item._natural_birth_seen = {}
	clear_encounter_targets("rewind")
	clear_carrier_morph_runtime()
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE,
	params = PickupVariant.PICKUP_COLLECTIBLE,
	Function = function(_, pickup)
		if get_materialized_choice(pickup) then
			sync_carrier_quote_from_holder(pickup)
		end
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_PICKUP_COLLECTIBLE, params = nil,
Function = function(_, player, colid, touched, ent)
	local token, _snap, source = resolve_carrier_token_from_pickup_event(ent)
	if token == nil then return end

local cycle = {}
	if ent and ent.GetCollectibleCycle then
		local ok, c = pcall(function()
			return ent:GetCollectibleCycle()
		end)
		if ok and type(c) == "table" then
			cycle = c
		end
	end
	debug_note("P_PICKUP_TOKEN_RESOLVED", {
		token = token,
		colid = colid,
		current_subtype = ent and ent.SubType or nil,
		cycle = cycle,
		source = source or "carrier_data",
	})

	-- 任意成功拾取 MATERIALIZED Perhaps choice（含轮换显示为其它道具）→ CONSUMED
	mark_carrier_pickup_confirmed(token)
	clear_encounter_targets("pickup_carrier")

	local txn = item._carrier_morph_txns and item._carrier_morph_txns[token]
	if txn and txn.finalized ~= true then
		-- Morph txn：下一帧 finalize → CONSUMED（不立刻 migrate 到地上旧道具）
		return
	end
	-- 可能同帧稍后才 Morph：先记 recent，由 tick_plain / morph open 裁决
	-- 不在此处立即 consume（避免 pickup-before-morph 误终态）
end,
})

--- 普通 Pedestal Encounter：唯一 attach trigger（绑定该 generation，不改挂）。
table.insert(item.myToCall, #item.myToCall + 1, {CallBack = enums.Callbacks.POST_PEDESTAL_ENCOUNTER, params = nil,
Function = function(_, encounter)
	-- Encounter 仅：① 一次性 birth evidence ② QUEUED materialize trigger
	if encounter and encounter.pickup then
		materialize_natural_perhaps_if_needed(encounter.pickup, { from_encounter = true })
	end
	enqueue_encounter_target(encounter)
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_NEW_ROOM, params = nil,
Function = function(_)
	item._attach_scheduled = false
	item._attach_transactions_this_room = 0
	clear_encounter_targets("new_room")
	local list = auxi.getothers(nil, EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)
	for _, ent in ipairs(list) do
		local pickup = ent:ToPickup()
		if pickup then
			cleanup_rejected_or_abandoned(pickup)
		end
	end
	-- 不再全房扫描 attach；等本房新的 POST_PEDESTAL_ENCOUNTER
end,
})

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_PICKUP_INIT, params = PickupVariant.PICKUP_COLLECTIBLE,
Function = function(_, pickup)
	if not pickup then return end
	if item._spawning_carrier then
		return
	end
	if cleanup_rejected_or_abandoned(pickup) then
		return
	end
	local data = refresh_flags(pickup)
	-- 已有 Carrier 业务绑定：只按 token 维护，禁止再走 involves visual discovery
	if data and data.is_carrier == true and data.pending_token ~= nil then
		apply_carrier_hold(pickup, {
			abandoned_carrier = data.abandoned_carrier,
			pending_token = data.pending_token,
			pending_quote_state = carrier_quote_state(data),
			pending_has_price = data.pending_has_price,
			pending_price = data.pending_price,
			pending_was_shop_item = carrier_was_shop_item(data),
			pending_entry_state = data.pending_entry_state or "materialized",
		})
		if get_materialized_choice(pickup) then
			watch_for_option_reject(pickup)
		end
		return
	end
	materialize_natural_perhaps_if_needed(pickup)
	-- attach 仅由 POST_PEDESTAL_ENCOUNTER 触发；INIT 不再用 fresh 自判
end,
})

--- PRE：Reserved 冻结 presentation 可取消 Morph；Carrier capture 由 Pickup_Morph_Transaction_holder 负责。
if ModCallbacks.MC_PRE_PICKUP_MORPH then
	table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
		CallBack = ModCallbacks.MC_PRE_PICKUP_MORPH,
		params = nil,
		priority = -50,
		Function = function(_, pickup, newType, newVariant, newSubtype, keepPrice, keepSeed, ignoreModifiers)
			-- Reserved 冻结 presentation：取消 cycle 轮换 Morph（目标仍在快照 cycle 内）
			do
				local p = pickup and (pickup.ToPickup and pickup:ToPickup() or pickup) or nil
				if p and p.Variant == PickupVariant.PICKUP_COLLECTIBLE then
					local data = read_data(p)
					if data and data.reserved_cycle_paused == true and data.reserved_lock ~= nil then
						local target = tonumber(newSubtype) or 0
						local snap = data.reserved_cycle_snapshot
						local in_cycle = false
						if type(snap) == "table" then
							for _, id in ipairs(snap) do
								if id == target then
									in_cycle = true
									break
								end
							end
						end
						if in_cycle or target == data.reserved_frozen_subtype then
							return false
						end
					end
				end
			end
		end,
	})
end

morph_txn.register("PerhapsChosen", {
	priority = 0,
	policy = MORPH_POLICY,
	match_pre = function(pickup)
		return pickup
			and pickup.Type == EntityType.ENTITY_PICKUP
			and pickup.Variant == PickupVariant.PICKUP_COLLECTIBLE
	end,
	capture = function(pickup)
		return capture_carrier_morph_snapshot(pickup)
	end,
	on_post = function(txn)
		local ok, err = pcall(handle_carrier_morph_txn, txn)
		if not ok then
			print("[PerhapsChosen] morph_txn on_post error: " .. tostring(err))
		end
	end,
})

--- POST Morph pairing/dispatch：见 Pickup_Morph_Transaction_holder（PerhapsChosen consumer）。

--- DEBUG-ONLY：按 G 观察 Morph case，窗结束后才 freeze diagnosis（禁止用 POST dt0 当 final）。
local function tick_morph_case_observes()
	local tr = ensure_morph_trace()
	for _, id in ipairs(tr.order or {}) do
		local case = tr.cases[id]
		local watch = case and case.observe
		if watch and watch.active then
			local total = tonumber(watch.frames_total) or MORPH_CASE_OBSERVE_FRAMES
			local left = tonumber(watch.frames_left) or 0
			local dt = total - left + 1
			local gid = watch.generation_id or watch.post_generation_id
			local pickup = find_collectible_by_generation_id(gid)
			local raw = pickup and read_data(pickup) or nil
			local cycle = pickup and debug_cycle_ids_local(pickup) or {}
			local subtype = pickup and pickup.SubType or nil
			local expect_token = watch.token or case.token
			local raw_token = raw and raw.pending_token or nil
			item.append_morph_case_observation(case.case_id, {
				dt = dt,
				frame = game_frame(),
				case_id = case.case_id,
				token = expect_token,
				raw_token = raw_token,
				generation_id = pickup and (unique_holder.resolve_generation(pickup) or {}).id or gid,
				post_generation_id = gid,
				subtype = subtype,
				cycle = cycle,
				is_carrier = raw and raw.is_carrier == true or false,
				state = raw and raw.pending_entry_state or nil,
				contains_perhaps = presentation_contains_perhaps(subtype, cycle),
				found = pickup ~= nil,
				token_match = pickup ~= nil and raw_token == expect_token,
			})
		end
	end
end

table.insert(item.ToCall, #item.ToCall + 1, {CallBack = ModCallbacks.MC_POST_UPDATE, params = nil,
Function = function(_)
	tick_carrier_morph_txns()
	tick_morph_case_observes()
	tick_plain_carrier_consumes()
end,
})

--- ImGui / 调试：读写 Pending 队列长度（不碰存档外的其它 Debug 开关）。
function item.get_pending_count()
	return pending_count()
end

function item.count_active_carriers()
	return count_active_carriers()
end


--- DEBUG-ONLY：Morph case 列表（probe Summary 权威源）。
function item.get_morph_trace()
	return ensure_morph_trace()
end

function item.get_latest_any_morph_case()
	local tr = ensure_morph_trace()
	local order = tr.order or {}
	local id = order[#order]
	return id and tr.cases[id] or nil
end

function item.get_latest_external_morph_case()
	local tr = ensure_morph_trace()
	local order = tr.order or {}
	-- 最近一次 SUPERSEDE / external Morph；不被后续 STATE_SWITCH case 覆盖
	for i = #order, 1, -1 do
		local c = tr.cases[order[i]]
		if c and c.post and c.post.morph_kind == "SUPERSEDE" then
			return c
		end
		if c and (c.phase == "external_finalized"
			or c.phase == "external_txn_open"
			or c.phase == "external_txn_lost")
		then
			return c
		end
	end
	return nil
end

--- DEBUG-ONLY：最近一次 STATE_SWITCH / SAME_LIFETIME case（不被 external 覆盖）。
function item.get_latest_state_switch_morph_case()
	local tr = ensure_morph_trace()
	local order = tr.order or {}
	for i = #order, 1, -1 do
		local c = tr.cases[order[i]]
		if c and c.kind == "state_switch" then
			return c
		end
		if c and c.post then
			local mk = c.post.morph_kind
			if mk == "STATE_SWITCH" or mk == "SAME_LIFETIME" then
				return c
			end
		end
	end
	return nil
end

function item.append_morph_case_observation(case_id, obs)
	local case = morph_trace_get(case_id)
	if not case or type(obs) ~= "table" then return false end
	case.observations = case.observations or {}
	case.observations[#case.observations + 1] = obs
	local watch = case.observe
	if watch and watch.active then
		watch.frames_left = (tonumber(watch.frames_left) or 1) - 1
		if watch.frames_left <= 0 then
			watch.active = false
			morph_case_finalize_diagnosis(case)
		else
			morph_case_refresh_final(case)
		end
	end
	return true
end

function item.list_active_morph_observes()
	local out = {}
	local tr = ensure_morph_trace()
	for _, id in ipairs(tr.order or {}) do
		local c = tr.cases[id]
		if c and c.observe and c.observe.active then
			out[#out + 1] = c
		end
	end
	return out
end

--- DEBUG / consumer：authoritative MATERIALIZED binding（不看 SubType/cycle）。
function item.get_materialized_choice(pickup)
	return get_materialized_choice(pickup)
end

--- 权威 token 报价（resolved 后）。供 Reserved Judgment 等 provider 使用。
function item.get_materialized_quote(pickup)
	local data = get_materialized_choice(pickup)
	if not data then return nil end
	local qstate = carrier_quote_state(data)
	return {
		resolved = qstate == QUOTE_RESOLVED,
		quote_state = qstate,
		has_price = (qstate == QUOTE_RESOLVED) and carrier_has_price(data) or nil,
		price = data.pending_price,
		was_shop_item = carrier_was_shop_item(data),
		token = data.pending_token,
	}
end

function item.ensure_quote_resolved(pickup)
	return sync_carrier_quote_from_holder(pickup, {final = true})
end

local function cycle_snapshot_for_reserve(pickup)
	-- 仅 cycle 表（不含当前 SubType）；释放时按顺序 AddCollectibleCycle 恢复
	return debug_cycle_ids_local(pickup)
end

local function freeze_carrier_cycle_presentation(pickup)
	if not pickup then return nil, nil end
	local frozen_subtype = pickup.SubType
	local snapshot = cycle_snapshot_for_reserve(pickup)
	if pickup.RemoveCollectibleCycle then
		pcall(function()
			pickup:RemoveCollectibleCycle()
		end)
	end
	-- RemoveCollectibleCycle 若改了展示，Morph 回冻结项（同房可逆 freeze，非 Morph repair）
	if frozen_subtype and frozen_subtype > 0 and pickup.SubType ~= frozen_subtype and pickup.Morph then
		pcall(function()
			pickup:Morph(
				EntityType.ENTITY_PICKUP,
				PickupVariant.PICKUP_COLLECTIBLE,
				frozen_subtype,
				true, true, true
			)
		end)
	end
	return snapshot, frozen_subtype
end

local function restore_carrier_cycle_presentation(pickup, snapshot, frozen_subtype)
	if not pickup then return end
	if frozen_subtype and frozen_subtype > 0 and pickup.SubType ~= frozen_subtype and pickup.Morph then
		pcall(function()
			pickup:Morph(
				EntityType.ENTITY_PICKUP,
				PickupVariant.PICKUP_COLLECTIBLE,
				frozen_subtype,
				true, true, true
			)
		end)
	end
	if type(snapshot) ~= "table" or not pickup.AddCollectibleCycle then return end
	for _, id in ipairs(snapshot) do
		if id and id > 0 and id ~= pickup.SubType then
			pcall(function()
				pickup:AddCollectibleCycle(id)
			end)
		end
	end
end

--- Reserved Judgment 薄 adapter：锁定 MATERIALIZED choice，真正冻结 cycle presentation。
--- 返回 pending_token；失败返回 nil。不 alloc 新 token。
function item.reserve_materialized_choice(pickup, owner_key)
	local data = get_materialized_choice(pickup)
	if not data or data.pending_token == nil then return nil end
	local snapshot, frozen_subtype = freeze_carrier_cycle_presentation(pickup)
	apply_carrier_hold(pickup, {
		reserved_lock = owner_key or true,
		reserved_cycle_paused = true,
		reserved_cycle_snapshot = snapshot,
		reserved_frozen_subtype = frozen_subtype,
	})
	return data.pending_token
end

--- 释放 Reserved lock。默认恢复 cycle；opts.restore_cycle=false 时只清 lock（购买/D6 等失效路径）。
function item.release_reserved_choice(token, opts)
	if token == nil then return false end
	opts = opts or {}
	local restore = opts.restore_cycle ~= false
	local hit = false
	local list = auxi.getothers(nil, EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)
	for _, ent in ipairs(list) do
		local pickup = ent:ToPickup()
		local data = pickup and get_materialized_choice(pickup)
		if data and data.pending_token == token then
			local snap = data.reserved_cycle_snapshot
			local frozen = data.reserved_frozen_subtype
			apply_carrier_hold(pickup, {
				reserved_lock = nil,
				reserved_cycle_paused = nil,
				reserved_cycle_snapshot = nil,
				reserved_frozen_subtype = nil,
			})
			if restore then
				restore_carrier_cycle_presentation(pickup, snap, frozen)
			end
			hit = true
		end
	end
	return hit
end

--- 下一层兑现：用同一 token materialize（不得 alloc 新 token）。
--- opts: { has_price, quoted_price / price, was_shop_item, position }
--- 不恢复旧房 cycle snapshot；新 carrier 按普通 Perhaps 规则。
function item.materialize_reserved_choice(token, opts)
	if token == nil then return nil end
	opts = opts or {}
	local has_price = opts.has_price
	if has_price == nil and opts.is_shop ~= nil then
		has_price = opts.is_shop == true
	end
	local price = opts.quoted_price or opts.price
	local was_shop = opts.was_shop_item == true

	local function entry_from_opts(fallback_price)
		return {
			token = token,
			quote_state = QUOTE_RESOLVED,
			has_price = has_price == true,
			price = price ~= nil and price or fallback_price,
			was_shop_item = was_shop,
		}
	end

	-- 已在场则只恢复价格并解除 freeze
	local list = auxi.getothers(nil, EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)
	for _, ent in ipairs(list) do
		local pickup = ent:ToPickup()
		local data = pickup and get_materialized_choice(pickup)
		if data and data.pending_token == token then
			local entry = entry_from_opts(data.pending_price)
			if entry.has_price ~= true and carrier_has_price(data) then
				entry.has_price = true
				entry.price = entry.price or data.pending_price
			end
			entry.quote_state = QUOTE_RESOLVED
			apply_carrier_hold(pickup, {
				pending_quote_state = QUOTE_RESOLVED,
				pending_has_price = entry.has_price == true,
				pending_price = entry.price,
				pending_was_shop_item = entry.was_shop_item,
				reserved_lock = nil,
				reserved_cycle_paused = nil,
				reserved_cycle_snapshot = nil,
				reserved_frozen_subtype = nil,
			})
			apply_resolved_entry_quote(pickup, entry)
			return pickup
		end
	end

	local entry = entry_from_opts(nil)
	local room = Game():GetRoom()
	local pos = opts.position
	if not pos then
		local margin = 80
		local top_left = room:GetTopLeftPos()
		pos = room:FindFreePickupSpawnPosition(Vector(top_left.X + margin, top_left.Y + margin), 20, true)
	end
	item._spawning_carrier = true
	local carrier
	pedestal_encounter.with_suppressed_encounter(item.own_key, function()
		local spawned = Isaac.Spawn(
			EntityType.ENTITY_PICKUP,
			PickupVariant.PICKUP_COLLECTIBLE,
			item.entity,
			pos,
			Vector.Zero,
			nil
		)
		carrier = spawned and spawned:ToPickup()
		if carrier then
			pedestal_encounter.mark_suppressed(carrier, item.own_key)
		end
	end)
	item._spawning_carrier = nil
	if not carrier then return nil end
	carrier.OptionsPickupIndex = 0
	carrier:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
	hold_flags(carrier, {
		is_carrier = true,
		abandoned_carrier = nil,
		rejected_origin = nil,
		pending_token = entry.token,
		pending_quote_state = QUOTE_RESOLVED,
		pending_has_price = entry.has_price == true,
		pending_price = entry.price,
		pending_was_shop_item = entry.was_shop_item,
		pending_entry_state = "materialized",
	})
	apply_carrier_hold(carrier, {
		abandoned_carrier = nil,
		pending_token = entry.token,
		pending_quote_state = QUOTE_RESOLVED,
		pending_has_price = entry.has_price == true,
		pending_price = entry.price,
		pending_was_shop_item = entry.was_shop_item,
		pending_entry_state = "materialized",
		reserved_lock = nil,
		reserved_cycle_paused = nil,
	})
	entry.quote_state = QUOTE_RESOLVED
	apply_resolved_entry_quote(carrier, entry)
	watch_for_option_reject(carrier)
	Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, carrier.Position, Vector.Zero, nil)
	return carrier
end

function item.has_unresolved_choice()
	return has_unresolved_choice()
end

function item.set_pending_count(n)
	n = math.floor(tonumber(n) or 0)
	if n < 0 then n = 0 end
	if n > 32 then n = 32 end
	local q = pending_queue()
	local before = #q
	local before_tokens = debug_pending_tokens_copy()
	while #q > n do
		table.remove(q)
	end
	while #q < n do
		q[#q + 1] = {
			token = alloc_token(),
			has_price = false,
			price = nil,
			was_shop_item = false,
		}
	end
	if #q > before then
		debug_queue_mutation("P_QUEUE_PUSH", "debug_set_pending", {
			count_before = before,
			tokens_before = before_tokens,
		})
	elseif #q < before then
		debug_queue_mutation("P_QUEUE_REMOVE", "debug_set_pending", {
			count_before = before,
			tokens_before = before_tokens,
		})
	end
	return #q
end

function item.debug_clear_pending()
	clear_pending("debug_set_pending")
end

function item.reset_debug_audit()
	item.debug_audit.new_host_hits = 0
	item.debug_audit.fresh_hits = 0
	item.debug_audit.not_fresh_blocks = 0
	item.debug_audit.same_generation_blocks = 0
	item.debug_audit.restore_blocks = 0
	item.debug_audit.encounter_targets_queued = 0
	item.debug_audit.encounter_targets_resolved = 0
	item.debug_audit.encounter_targets_lost = 0
	item.debug_audit.last_generation_id = nil
	item.debug_audit.last_counted_new_id = nil
	item.debug_audit.last_target_generation_id = nil
	item.debug_audit.last_attached_generation_id = nil
end

--- 移除本房 Carrier。skip_requeue=true 时不回队（清空调试用）。
function item.debug_remove_active_carriers(skip_requeue)
	local list = auxi.getothers(nil, EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)
	for _, ent in ipairs(list) do
		local pickup = ent:ToPickup()
		if pickup and is_carrier(pickup) then
			local data = refresh_flags(pickup)
			if not skip_requeue and data and data.pending_entry_state == "materialized" then
				requeue_carrier_entry(pickup)
			end
			forget_carrier_runtime(pickup)
			consistance_holder.try_remove_entity(pickup, item.own_key)
			pickup:Remove()
		end
	end
	item._attach_transactions_this_room = 0
end

--- 立刻按当前队列挂接到本房可选项（先清掉旧 Carrier 并回队，再生成）。
--- Debug only：合成一个 target（优先最近可挂 pedestal），不走全房「挑 host」生产路径。
function item.debug_force_attach()
	if not Isaac.IsInGame or not Isaac.IsInGame() then
		return false, "not_in_game"
	end
	item.debug_remove_active_carriers(false)
	item._attach_scheduled = false
	item._attach_transactions_this_room = 0
	clear_encounter_targets("debug_reset")
	if not has_queued_pending() then
		return false, "empty_queue"
	end
	local player = Isaac.GetPlayer(0)
	local best, best_dist = nil, nil
	local list = auxi.getothers(nil, EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)
	for _, ent in ipairs(list) do
		local pickup = ent:ToPickup()
		if pickup and is_perhaps_host_eligible(pickup) then
			local gen = unique_holder.resolve_generation(pickup)
			if gen and gen.id then
				local dist = player and pickup.Position:Distance(player.Position) or 0
				if best == nil or dist < best_dist then
					best = { pickup = pickup, gen = gen }
					best_dist = dist
				end
			end
		end
	end
	if not best then
		return false, "no_host"
	end
	local result = try_attach_for_target({
		generation_id = best.gen.id,
		options_index = best.pickup.OptionsPickupIndex or 0,
		queued_frame = game_frame(),
	})
	if result == "ok" then
		return true
	end
	return false, tostring(result)
end

function item.debug_dump_queue_tokens()
	local parts = {}
	for _, entry in ipairs(pending_queue()) do
		if entry.has_price then
			parts[#parts + 1] = string.format("t%s@%s", tostring(entry.token), tostring(entry.price))
		else
			parts[#parts + 1] = "t" .. tostring(entry.token) .. "@free"
		end
	end
	return table.concat(parts, ",")
end

function item.debug_dump_carriers()
	local parts = {}
	local list = auxi.getothers(nil, EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)
	for _, ent in ipairs(list) do
		local pickup = ent:ToPickup()
		local data = pickup and refresh_flags(pickup)
		if data and data.is_carrier == true then
			parts[#parts + 1] = string.format(
				"t%s/%s@%s%s",
				tostring(data.pending_token),
				tostring(data.pending_entry_state or "?"),
				(carrier_quote_state(data) == QUOTE_RESOLVED)
					and (carrier_has_price(data) and tostring(data.pending_price) or "free")
					or "unresolved",
				data.abandoned_carrier and "/abd" or ""
			)
		end
	end
	return table.concat(parts, ",")
end

function item.debug_force_reroll_carriers()
	if not Isaac.IsInGame or not Isaac.IsInGame() then
		return false, "not_in_game"
	end
	local n = 0
	local pool = Game():GetItemPool()
	local list = auxi.getothers(nil, EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)
	for _, ent in ipairs(list) do
		local pickup = ent:ToPickup()
		if pickup and is_active_carrier(pickup) and pickup.Morph then
			local seed = pickup.InitSeed or Random()
			local id = pool:GetCollectible(ItemPoolType.POOL_TREASURE, true, seed)
			if id == item.entity then
				id = pool:GetCollectible(ItemPoolType.POOL_TREASURE, true, seed + 1)
			end
			if id and id > 0 then
				pcall(function()
					pickup:Morph(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, id, true, true, false)
				end)
				-- Morph txn + POST_UPDATE finalize 负责同 token ensure；禁止 ptr delay
				n = n + 1
			end
		end
	end
	return n > 0, n
end

function item.debug_status_text()
	local q = pending_count()
	local carriers = count_active_carriers()
	local force = item.force_seija()
	local active = item.is_seija_active()
	local attach_tx = item._attach_transactions_this_room or 0
	local a = item.debug_audit or {}
	return string.format(
		"queued=%d  carriers=%d  unresolved=%s  Seija(force=%s active=%s)  attach_tx=%d  Q[%s]  C[%s]  morph(pre=%s post=%s mism=%s sw=%s open=%s conf=%s ext=%s cons=%s lost=%s last=%s/%s)",
		q,
		carriers,
		has_unresolved_choice() and "Y" or "N",
		force and "Y" or "N",
		active and "Y" or "N",
		attach_tx,
		item.debug_dump_queue_tokens(),
		item.debug_dump_carriers(),
		tostring(a.morph_pre_captured or 0),
		tostring(a.morph_post_paired or 0),
		tostring(a.morph_pair_mismatch or 0),
		tostring(a.morph_state_switch_ignored or 0),
		tostring(a.morph_txn_opened or 0),
		tostring(a.morph_txn_pickup_confirmed or 0),
		tostring(a.morph_txn_external_finalized or 0),
		tostring(a.morph_txn_consumed_finalized or 0),
		tostring(a.morph_txn_lost or 0),
		tostring(a.last_morph_token),
		tostring(a.last_morph_result)
	)
end

--- DEBUG-ONLY：只读 runtime 快照（探针用；不暴露 entity refs）。
function item.get_debug_runtime_snapshot()
	local audit = {}
	for k, v in pairs(item.debug_audit or {}) do
		if type(v) ~= "table" then
			audit[k] = v
		else
			-- shallow: only scalar nested fields
			local copy = {}
			for kk, vv in pairs(v) do
				if type(vv) ~= "table" and type(vv) ~= "userdata" and type(vv) ~= "function" then
					copy[kk] = vv
				end
			end
			audit[k] = copy
		end
	end
	local materialized = {}
	local list = auxi.getothers(nil, EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)
	for _, ent in ipairs(list) do
		local pickup = ent:ToPickup()
		local data = pickup and get_materialized_choice(pickup)
		if data then
			local gen = unique_holder.resolve_generation(pickup)
			local hq = price_holder.get_quote(pickup)
			materialized[#materialized + 1] = {
				token = data.pending_token,
				generation_id = gen and gen.id or nil,
				subtype = pickup.SubType,
				quote_state = carrier_quote_state(data),
				has_price = data.pending_has_price,
				price = data.pending_price,
				was_shop_item = carrier_was_shop_item(data),
				price_holder_resolved = hq and hq.resolved == true or false,
				price_holder_price = hq and hq.price or nil,
				price_holder_locked = hq and hq.locked == true or false,
			}
		end
	end
	return {
		pending_count = pending_count(),
		pending_tokens = debug_pending_tokens_copy(),
		queued_tokens = debug_pending_tokens_copy(),
		materialized_tokens = materialized,
		active_carriers = count_active_carriers(),
		active_carrier_count = count_active_carriers(),
		unresolved = has_unresolved_choice() == true,
		attach_transactions_this_room = item._attach_transactions_this_room or 0,
		attach_scheduled = item._attach_scheduled == true,
		spawning_carrier = item._spawning_carrier == true,
		target_queue_len = #(item._pending_encounter_hosts or {}),
		attach_skip_reason = nil,
		audit = audit,
	}
end

function item.debug_host_eligibility(pickup)
	return debug_host_eligibility(pickup)
end

--- 已废弃：不再有 gameplay attach skip gate。
function item.debug_attach_skip_reason()
	return nil
end

--- DEBUG-ONLY：取出并清空 debug event ring（探针轮询）。
function item.take_debug_events()
	local ev = item._debug_events or {}
	item._debug_events = {}
	return ev
end

return item
