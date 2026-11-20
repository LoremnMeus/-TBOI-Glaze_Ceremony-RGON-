local g = require("Qing_Remaster_scripts.core.globals")
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local sound_tracker = require("Qing_Remaster_scripts.auxiliary.sound_tracker")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder") 
local record_holder = require("Qing_Remaster_scripts.others.Record_holder")
local item_displaying_holder = require("Qing_Remaster_scripts.callbacks.item_displaying_holder")
local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")

local item = {
	ToCall = {},
	myToCall = {},
	post_ToCall = {},
	entity = enums.Items.Nihilistic_Artificial_Eye,
	own_key = "Item_NAEye_",
	words = {
		zh = {
			"我看错了吗？", 
		},
		en = {
			"Did I mis-watch?", 
		},
	},
	Ignorers = {
		[enums.Items.Skiel] = true,
		[enums.Items.Wisel] = true,
		[enums.Items.Granel] = true,
	},
}
auxi.add_to_seija(item.entity)

-- Pedestal-lifetime record: survive CollectibleCycle STATE_SWITCH (InitSeed stable).
-- Display still gates on SubType == eye; companions only expand while eye is shown.
local EYE_HOLD = {
	ignore_subtype = true,
	consistance = true,
}

local function eye_check(ent)
	return consistance_holder.try_check_entity(ent, item.own_key, false, EYE_HOLD) == true
end

local function eye_hold(ent)
	return consistance_holder.try_hold_entity(ent, item.own_key, EYE_HOLD)
end

--- Probe bridge (require_probe only). Observe-only; never changes gameplay.
local function eye_record_probe()
	local ok, env = pcall(require, "Qing_Remaster_scripts.core.dev_environment")
	if not ok or not env or not env.probes_allowed or not env.probes_allowed() then
		return nil
	end
	if not env.require_probe then return nil end
	return env.require_probe("Qing_Remaster_scripts.others.nihilistic_eye_record_probe")
end

local function probe_note(kind, payload)
	local p = eye_record_probe()
	if p and p.get_config and p.get_config().enabled == true and p.note then
		p.note(kind, payload)
	end
end

local function probe_record_id(ent)
	if not ent or not ent.GetData then return nil end
	local names = ent:GetData()._Consistance_holder_names
	local id = names and names[item.own_key]
	if id == nil then return nil end
	return tostring(id)
end

local function probe_generation_id(ent)
	local gen = unique_holder.resolve_generation(ent)
	return gen and tonumber(gen.id) or nil
end

local function probe_companions(bag)
	local out = {}
	if type(bag) ~= "table" or type(bag.companions) ~= "table" then
		return out
	end
	for i = 1, 3 do
		local c = bag.companions[i]
		if type(c) == "table" then
			out[#out + 1] = {
				slot = i,
				id = tonumber(c.id),
				status = c.status or "active",
				name = c.name,
				has_nested = type(c.nested) == "table",
			}
		end
	end
	return out
end

function item.is_option_pending_remove(ent)
	if auxi.check_all_exists(ent) ~= true then
		return true
	end
	local pickup = ent:ToPickup()
	if not pickup then
		return true
	end
	local d = pickup:GetData()
	-- 只认 Option_Index_holder Remove = loser；禁止读 OptionsPickupIndex_should_remove（旧语义与名称相反）
	return d[option_index_holder.own_key.."Remove"] == true
end

function item.is_option_picked(ent)
	if auxi.check_all_exists(ent) ~= true then return false end
	local pickup = ent:ToPickup()
	if not pickup then return false end
	return pickup:GetData()[option_index_holder.own_key.."Pick"] == true
end

-- owner 消失原因：正常 Options 结算 vs 外部/异常清理
local CLEANUP_EXTERNAL = "external"
local CLEANUP_OPTION_SELECTION = "option_selection"

-- Forward: defined with companion snapshot helpers below.
local mark_companion_removed

--- 释放虚无假眼对三个伴生候选的引用。
--- option_selection：只断引用，不 Remove（原版 Options 负责 sibling cleanup；winner 可能留下新底座）。
--- external：主动 Remove 三个伴生，避免孤零零留在房间。
--- 两种原因都把槽位标为 removed，避免 Cycle 回显时把已结算奖励重新实体化。
--- 禁止按 child 的 live Pick flag 决定是否 Remove（时序竞争）；原因由调用方一次判定后传入。
function item.cleanup_linked_effects(ent, reason)
	local d = ent:GetData()
	local effects = d[item.own_key.."effect"]
	if not effects then
		return
	end
	local should_remove = reason ~= CLEANUP_OPTION_SELECTION
	for i = 1, 3 do
		local effect = effects[i]
		if should_remove and auxi.check_all_exists(effect) then
			effect:Remove()
		end
		effects[i] = nil
		mark_companion_removed(ent, i, reason == CLEANUP_OPTION_SELECTION and "option_selection" or "external_cleanup")
	end
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_EVALUATE_CACHE, params = nil,
Function = function(_,player,cacheFlag)
	if auxi.has_have_coll(player,item.entity) then
		local mul = player:GetCollectibleNum(item.entity)
		if cacheFlag == CacheFlag.CACHE_DAMAGE then
			player.Damage = player.Damage + auxi.get_damage_multiplier(player) * mul * 0.33
		end
	end
end,
})

local function mark_parent_slot_from_companion(et, reason)
	local d = et:GetData()
	local rec = d[item.own_key .. "record"]
	if not rec then return end
	local tg = rec.tg
	local slot = tonumber(rec.slot)
	if not slot or not auxi.check_all_exists(tg) then return end
	item.mark_companion_removed(tg, slot, reason or "companion_exit")
end

function item.record_entity(ent)
	local id = ent.SubType
	local st = ent.SubType
	local vr = ent.Variant
	record_holder.try_hold(ent,{check = function(et)
		if et.SubType ~= st or et.Variant ~= vr then return true,"Turn" end
	end,Function = function(tp,et)
		if tp == "Turn" then
			-- winner 拾取后 SubType/Variant 合法变化：不删、不黑烟
			if item.is_option_picked(et) then return end
			local pickup = et:ToPickup()
			if pickup
				and pickup.OptionsPickupIndex ~= 0
				and not (item.Ignorers[et.SubType] and item.Ignorers[st])
			then
				mark_parent_slot_from_companion(et, "external_morph")
				local q = Isaac.Spawn(1000,15,0,et.Position,Vector(0,0),nil)
				sound_tracker.PlayStackedSound(SoundEffect.SOUND_BLACK_POOF,1,1,false,0,2)
				if item.display_distance == nil then
					local language = Options.Language
					local wdinfo = item.words[language] or item.words["en"]
					item_displaying_holder.check_and_description("CardDesc",item.entity,wdinfo[1],"",player)
					item.display_distance = true
				end
				et:Remove()
			end
		end
	end,})
end

-- Fixed companion snapshot per eye display record (not per-run).
-- Cycle re-show rematerializes the same three IDs; exited slots stay removed.
local NEST_DEPTH_MAX = 4
local _expanding_offers = {}

local function bag_root(ent)
	local d = ent:GetData()
	d._Data = d._Data or {}
	d._Data[item.own_key] = d._Data[item.own_key] or {}
	return d._Data[item.own_key]
end

local function offer_key(ent)
	local gen = unique_holder.resolve_generation(ent)
	local gid = gen and tonumber(gen.id)
	if gid then
		return "g:" .. tostring(gid)
	end
	return "s:" .. tostring(ent.InitSeed)
end

local function copy_companions(src)
	local out = {}
	if type(src) ~= "table" then return out end
	for i = 1, 3 do
		local c = src[i]
		if type(c) == "table" then
			out[i] = {
				id = tonumber(c.id),
				status = c.status or "active",
				name = c.name,
			}
			if type(c.nested) == "table" then
				out[i].nested = {
					nest_depth = tonumber(c.nested.nest_depth) or 0,
					companions = copy_companions(c.nested.companions),
				}
			end
		end
	end
	return out
end

local function mark_slot_removed(bag, idx, reason)
	bag.effect = bag.effect or {}
	bag.effect[idx] = "Removed"
	bag.companions = bag.companions or {}
	local slot = bag.companions[idx]
	local prev_status = type(slot) == "table" and slot.status or nil
	local prev_id = type(slot) == "table" and slot.id or nil
	if type(slot) ~= "table" then
		bag.companions[idx] = {id = 0, status = "removed"}
	else
		slot.status = "removed"
		slot.name = nil
	end
	return prev_status, prev_id, reason
end

local function has_companion_snapshot(bag)
	if type(bag.companions) ~= "table" then return false end
	for i = 1, 3 do
		local companion = bag.companions[i]
		if type(companion) ~= "table" or tonumber(companion.id) == nil then
			return false
		end
	end
	return true
end

local function roll_companion_ids(ent, bag)
	local rng = ent:GetDropRNG()
	local depth = tonumber(ent:GetData()[item.own_key .. "nest_depth"])
		or tonumber(bag.nest_depth)
		or 0
	bag.nest_depth = depth
	bag.companions = {}
	for i = 1, 3 do
		-- Pool roll must stay outside with_missing: missing override forces PRE_GET_COLLECTIBLE → id.
		local colid = auxi.get_item_from_pool(nil, true, rng)
		if colid == item.entity then
			if depth >= NEST_DEPTH_MAX or #(auxi.getothers(5, 100, item.entity)) > 10 then
				colid = enums.Items.Hypermnesia
			end
		end
		bag.companions[i] = {id = colid, status = "active", name = nil}
	end
end

local function ensure_companion_snapshot(ent, bag)
	if has_companion_snapshot(bag) then return bag end
	bag.effect = {}
	roll_companion_ids(ent, bag)
	return bag
end

local function bind_companion_runtime(ent, companion, slot_index)
	companion.OptionsPickupIndex = ent.OptionsPickupIndex
	local d2 = companion:GetData()
	d2[item.own_key .. "record"] = {
		tg = ent,
		price = ent.Price,
		slot = slot_index,
	}
	companion.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
	if ent.Price ~= 0 then
		companion.Price = ent.Price
		price_holder.catch_price_over(companion)
	end
	item.record_entity(companion)
end

local spawn_companion_slot -- forward decl for nested eye expand

local function apply_nested_offer(child, nested, parent_bag)
	local cbag = bag_root(child)
	cbag.nest_depth = (nested and tonumber(nested.nest_depth))
		or ((parent_bag.nest_depth or 0) + 1)
	cbag.offer_key = offer_key(child)
	cbag.effect = cbag.effect or {}
	cbag.counter = cbag.counter or 0
	if nested and type(nested.companions) == "table" and #nested.companions >= 3 then
		cbag.companions = copy_companions(nested.companions)
	else
		roll_companion_ids(child, cbag)
	end
	return cbag
end

spawn_companion_slot = function(ent, bag, i, runtime_effects)
	local slot = bag.companions and bag.companions[i]
	if not slot or slot.status == "removed" then
		return nil
	end
	local colid = tonumber(slot.id)
	if not colid or colid <= 0 then
		return nil
	end

	local q = unique_holder.with_missing(33, function()
		local spawned = Isaac.Spawn(5, 100, colid, item.get_rotation_pos(ent, i), Vector(0, 0), nil):ToPickup()
		auxi.self_morph(spawned, {5, 100, colid})
		return spawned
	end)
	if not q then
		return nil
	end

	bind_companion_runtime(ent, q, i)
	local name = consistance_holder.get_name(q, {params_name_only = true})[1]
	bag.effect = bag.effect or {}
	bag.effect[i] = name
	slot.name = name
	if runtime_effects then
		runtime_effects[i] = q
	end

	if colid == item.entity then
		local parent_key = bag.offer_key or offer_key(ent)
		local child_key = offer_key(q)
		q:GetData()[item.own_key .. "nest_depth"] = (bag.nest_depth or 0) + 1
		q:GetData()[item.own_key .. "parent_offer"] = parent_key
		-- Same business record must not recurse into itself.
		if child_key == parent_key or _expanding_offers[child_key] then
			return q
		end
		_expanding_offers[child_key] = true
		consistance_holder.try_hold_over_entity(q, item.own_key)
		local cbag = apply_nested_offer(q, slot.nested, bag)
		slot.nested = {
			nest_depth = cbag.nest_depth,
			companions = copy_companions(cbag.companions),
		}
		local child_runtime = q:GetData()
		child_runtime[item.own_key .. "effect"] = child_runtime[item.own_key .. "effect"] or {}
		for j = 1, 3 do
			spawn_companion_slot(q, cbag, j, child_runtime[item.own_key .. "effect"])
		end
		eye_hold(q)
		_expanding_offers[child_key] = nil
	end
	return q
end

local function find_companion_by_name(want_name)
	if not want_name or want_name == "Removed" then
		return nil
	end
	local tgs = auxi.getothers(5, 100)
	for _, v in pairs(tgs) do
		if item.is_option_pending_remove(v) then
			goto continue
		end
		local names = consistance_holder.get_name(v, {params_name_only = true})
		if names and names[1] == want_name then
			return v:ToPickup()
		end
		::continue::
	end
	return nil
end

function item.try_find(ent, id)
	if item.is_option_pending_remove(ent) then return nil end
	local d = ent:GetData()
	local record_before = probe_record_id(ent)
	local key = offer_key(ent)
	local succ = eye_check(ent)
	local reattached = false

	-- lookup_success=false is not "first display". Prefer rematch of an existing store record
	-- (STATE_SWITCH may have cleared runtime binding; ignore_subtype record should still exist).
	if not succ then
		local testing = consistance_holder.try_check_entity(ent, item.own_key, true, EYE_HOLD)
		if type(testing) == "table" and testing.desc then
			local held_id = eye_hold(ent)
			succ = eye_check(ent)
			reattached = succ == true
			probe_note("EYE_RECORD_REATTACH", {
				slot = id,
				generation_id = probe_generation_id(ent),
				init_seed = ent.InitSeed,
				current_subtype = ent.SubType,
				offer_key = key,
				record_id_before = record_before,
				record_id_after = probe_record_id(ent) or (testing.name and tostring(testing.name)) or held_id,
				lookup_success = succ == true,
				ignore_subtype = true,
				store_record_id = testing.name and tostring(testing.name) or nil,
			})
		end
	end

	local record_after = probe_record_id(ent)
	probe_note("EYE_RECORD_LOOKUP", {
		slot = id,
		generation_id = probe_generation_id(ent),
		init_seed = ent.InitSeed,
		current_subtype = ent.SubType,
		offer_key = key,
		record_id_before = record_before,
		record_id_after = record_after,
		lookup_success = succ == true,
		record_matches = succ == true and record_after ~= nil,
		ignore_subtype = true,
		reattached = reattached,
		companions = probe_companions(succ and bag_root(ent) or nil),
	})

	if not succ then
		if _expanding_offers[key] then
			return nil
		end
		-- True first display only: no store record for this pedestal family + owner.
		_expanding_offers[key] = true
		consistance_holder.try_hold_over_entity(ent, item.own_key)
		local bag = bag_root(ent)
		bag.counter = bag.counter or 0
		bag.offer_key = key
		local has_snapshot = has_companion_snapshot(bag)
		local had_fixed_ids = false
		if has_snapshot then
			for i = 1, 3 do
				local c = bag.companions[i]
				if type(c) == "table" and tonumber(c.id) and c.id > 0 and c.status ~= "removed" then
					had_fixed_ids = true
					break
				end
			end
		end
		if not has_snapshot then
			bag.effect = {}
			ensure_companion_snapshot(ent, bag)
		end
		d[item.own_key .. "effect"] = d[item.own_key .. "effect"] or {}
		for i = 1, 3 do
			spawn_companion_slot(ent, bag, i, d[item.own_key .. "effect"])
		end
		eye_hold(ent)
		_expanding_offers[key] = nil
		if had_fixed_ids then
			probe_note("EYE_SNAPSHOT_LOADED", {
				slot = id,
				generation_id = probe_generation_id(ent),
				offer_key = key,
				record_id = probe_record_id(ent),
				companions = probe_companions(bag),
				reason = "create_path_reused_snapshot",
				ignore_subtype = true,
			})
		else
			probe_note("EYE_RECORD_CREATED", {
				slot = id,
				generation_id = probe_generation_id(ent),
				init_seed = ent.InitSeed,
				current_subtype = ent.SubType,
				offer_key = key,
				record_id_before = record_before,
				record_id_after = probe_record_id(ent),
				companions = probe_companions(bag),
				nest_depth = bag.nest_depth,
				parent_offer = d[item.own_key .. "parent_offer"],
				ignore_subtype = true,
			})
		end
		return d[item.own_key .. "effect"][id]
	end

	local bag = bag_root(ent)
	ensure_companion_snapshot(ent, bag)
	bag.offer_key = bag.offer_key or key
	eye_hold(ent)
	probe_note("EYE_SNAPSHOT_LOADED", {
		slot = id,
		generation_id = probe_generation_id(ent),
		offer_key = bag.offer_key,
		record_id = record_after or probe_record_id(ent),
		companions = probe_companions(bag),
		nest_depth = bag.nest_depth,
		parent_offer = d[item.own_key .. "parent_offer"],
		ignore_subtype = true,
		reattached = reattached,
	})
	local slot = bag.companions and bag.companions[id]
	if slot and slot.status == "removed" then
		return nil
	end
	if bag.effect and bag.effect[id] == "Removed" then
		return nil
	end

	local want_name = (slot and slot.name) or (bag.effect and bag.effect[id])
	local found = find_companion_by_name(want_name)
	if found then
		bind_companion_runtime(ent, found, id)
		if slot then
			slot.name = want_name
			if (not slot.id or slot.id <= 0) and found.SubType and found.SubType > 0 then
				slot.id = found.SubType
			end
		end
		eye_hold(ent)
		probe_note("EYE_COMPANION_FOUND", {
			slot = id,
			generation_id = probe_generation_id(ent),
			offer_key = bag.offer_key,
			record_id = probe_record_id(ent),
			companion_subtype = found.SubType,
			companion_ptr = GetPtrHash(found),
			companion_seed = found.InitSeed,
			want_name = want_name,
		})
		return found
	end

	-- Rematerialize from fixed collectible ID only — never re-roll the pool.
	if slot and tonumber(slot.id) and slot.id > 0 and slot.status ~= "removed" then
		d[item.own_key .. "effect"] = d[item.own_key .. "effect"] or {}
		local existing_runtime = d[item.own_key .. "effect"][id]
		local duplicate_existing = auxi.check_all_exists(existing_runtime) == true
		local remade = spawn_companion_slot(ent, bag, id, d[item.own_key .. "effect"])
		eye_hold(ent)
		probe_note("EYE_COMPANION_REMATERIALIZED", {
			slot = id,
			generation_id = probe_generation_id(ent),
			offer_key = bag.offer_key,
			record_id = probe_record_id(ent),
			fixed_id = slot.id,
			from_fixed_id = true,
			duplicate_existing = duplicate_existing,
			companion_ptr = remade and GetPtrHash(remade) or nil,
			companion_seed = remade and remade.InitSeed or nil,
			reason = "missing_runtime_restore",
		})
		return remade
	end

	-- Legacy name-only slot that vanished: treat as permanently exited.
	mark_slot_removed(bag, id, "legacy_name_missing")
	eye_hold(ent)
	probe_note("EYE_SLOT_REMOVED", {
		slot = id,
		generation_id = probe_generation_id(ent),
		offer_key = bag.offer_key,
		record_id = probe_record_id(ent),
		reason = "legacy_name_missing",
		companions = probe_companions(bag),
	})
	return nil
end

function item.get_rotation_pos(ent, id)
	local d = ent:GetData()
	local speed = 5
	if auxi.should_do_Seija_all() then speed = 20 end
	local eff = d[item.own_key .. "effect"]
	local counter = (type(eff) == "table" and eff.counter) or 0
	return ent.Position + auxi.get_by_rotate(nil, id * 120 + counter * speed, 60)
end

mark_companion_removed = function(ent, idx, reason)
	if not ent then return end
	consistance_holder.try_hold_over_entity(ent, item.own_key)
	local bag = bag_root(ent)
	local prev_status, prev_id = mark_slot_removed(bag, idx, reason)
	eye_hold(ent)
	probe_note("EYE_SLOT_REMOVED", {
		slot = idx,
		generation_id = probe_generation_id(ent),
		offer_key = bag.offer_key or offer_key(ent),
		record_id = probe_record_id(ent),
		reason = reason or "unspecified",
		prev_status = prev_status,
		prev_id = prev_id,
		companions = probe_companions(bag),
	})
end

function item.mark_companion_removed(ent, idx, reason)
	mark_companion_removed(ent, idx, reason)
end

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE, params = 100,
Function = function(_,ent)
	local d = ent:GetData()
	if ent.SubType == item.entity then
		if item.is_option_pending_remove(ent) then
			-- was_rejected_by_selection 会 consume：只查一次，把 reason 传入 cleanup
			local rejected = option_index_holder.was_rejected_by_selection
				and option_index_holder.was_rejected_by_selection(ent) == true
			item.cleanup_linked_effects(
				ent,
				rejected and CLEANUP_OPTION_SELECTION or CLEANUP_EXTERNAL
			)
			return
		end
		if ent.OptionsPickupIndex == 0 then 
			local ndx = option_index_holder.find_a_new_index()
			ent.OptionsPickupIndex = ndx
		end
		d[item.own_key.."effect"] = d[item.own_key.."effect"] or {}
		-- Reattach pedestal record across Cycle before expanding companions.
		local succ = eye_check(ent)
		if not succ then
			local testing = consistance_holder.try_check_entity(ent, item.own_key, true, EYE_HOLD)
			if type(testing) == "table" and testing.desc then
				eye_hold(ent)
				succ = eye_check(ent)
			end
		end
		-- Animation counter is runtime-only. Do NOT eye_hold every frame — Consistance
		-- deep-copies bag data; counter churn was a confirmed redundant persist hotspot.
		if succ then
			local eff = d[item.own_key .. "effect"]
			if eff.counter == nil then
				local bag = d._Data and d._Data[item.own_key]
				eff.counter = (type(bag) == "table" and tonumber(bag.counter)) or 0
			end
			eff.counter = (eff.counter or 0) + 1
		end
		for i = 1,3 do
			if auxi.check_all_exists(d[item.own_key.."effect"][i]) ~= true then
				-- Missing slot: rematerialize from fixed IDs if still active.
				-- Do NOT mark removed here — Cycle host switch clears companions without exiting the offer.
				local t0 = (os and os.clock) and os.clock() or nil
				d[item.own_key.."effect"][i] = item.try_find(ent,i)
				if t0 and os and os.clock then
					probe_note("EYE_COMPANION_RESTORE_TIMING", {
						slot = i,
						seconds = os.clock() - t0,
						ok = auxi.check_all_exists(d[item.own_key.."effect"][i]) == true,
					})
				end
			end
			if auxi.check_all_exists(d[item.own_key.."effect"][i]) then
				local v = d[item.own_key.."effect"][i]
				local d2 = v:GetData()
				d2[item.own_key.."record"] = d2[item.own_key.."record"] or {}
				d2[item.own_key.."record"].tg = ent
				d2[item.own_key.."record"].price = ent.Price
				d2[item.own_key.."record"].slot = i
				d2[item.own_key.."record"].pos = item.get_rotation_pos(ent,i)
			end
		end

	end
	if d[item.own_key.."record"] then
		-- winner 已被玩家选中：后续底座保留/换主动/里以撒换被动等，虚无假眼不再干预
		if item.is_option_picked(ent) then
			return
		end
		local tg = d[item.own_key.."record"].tg
		if item.is_option_pending_remove(ent) then
			-- Options loser / selection exit: permanent for this offer slot.
			mark_parent_slot_from_companion(ent, "option_selection")
			Isaac.Spawn(1000,15,0,ent.Position,Vector(0,0),nil)
			ent:Remove()
			return
		end
		if item.is_option_pending_remove(tg) or (auxi.check_all_exists(tg) and tg.SubType ~= item.entity) then
			-- Host Options cleanup or Cycle switched display away: temporary despawn only.
			Isaac.Spawn(1000,15,0,ent.Position,Vector(0,0),nil)
			ent:Remove()
			return
		end
		local tgpos = d[item.own_key.."record"].pos
		if tgpos then
			ent.TargetPosition = tgpos
			ent.Position = tgpos
			ent.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
			ent.EntityCollisionClass = EntityCollisionClass.ENTCOLL_PLAYERONLY
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_CHECK_PRICE, params = 100,
Function = function(_,ent,val)
	local d = ent:GetData()
	if d[item.own_key.."record"] then
		local pr = nil
		if d[item.own_key.."record"].price then pr = d[item.own_key.."record"].price end 
		if auxi.check_all_exists(d[item.own_key.."record"].tg) then
			local tg = d[item.own_key.."record"].tg:ToPickup()
			if tg then pr = tg.Price end
		end
		if pr > 0 then 
			local config = Isaac:GetItemConfig()
			local collectibleinfo = config:GetCollectible(ent.SubType)
			if collectibleinfo then return collectibleinfo.ShopPrice 
			else return 15 end
		elseif pr < 0 then return auxi.get_acceptible_devil_price(ent,val) end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.POST_GAIN_COLLECTIBLE, params = item.entity,
Function = function(_,player,colid,cnt,touched)
	if touched ~= true then
		save.elses[item.own_key.."effect"] = (save.elses[item.own_key.."effect"] or 0) + 2
	end
end,
})

table.insert(item.ToCall,#item.ToCall + 1,{CallBack = ModCallbacks.MC_PRE_GET_COLLECTIBLE, params = nil,
Function = function(_,pool,decrease,seed)
	if (save.elses[item.own_key.."effect"] or 0) > 0 and Game():GetFrameCount() > 5 then
		local rng = RNG()
		rng:SetSeed(seed,0)
		rng = auxi.rng_for_sake(rng)
		local rnd = rng:RandomInt(10)
		if rnd == 1 then
			if decrease == true then save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] - 1 end
			return item.entity
		end
	end
end,
})

table.insert(item.myToCall,#item.myToCall + 1,{CallBack = enums.Callbacks.PRE_GET_COLLECTIBLE_FROM_POOL, params = nil,
Function = function(_,colid,pool,decrease,seed)
	if (save.elses[item.own_key.."effect"] or 0) > 0 and Game():GetFrameCount() > 5 then
		local rng = RNG()
		rng:SetSeed(seed,0)
		rng = auxi.rng_for_sake(rng)
		local rnd = rng:RandomInt(10)
		if rnd == 1 then
			if decrease == true then save.elses[item.own_key.."effect"] = save.elses[item.own_key.."effect"] - 1 end
			return item.entity
		end
	end
end,
})

return item
