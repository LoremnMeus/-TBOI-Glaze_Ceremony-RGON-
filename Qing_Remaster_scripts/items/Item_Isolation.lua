-- 孤立 Isolation：本局 10 人小团体；持有时遇成员 → 10 选 1；成功选择后孤立被拒绝拾取。
local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local g = require("Qing_Remaster_scripts.core.globals")
local option_index_holder = require("Qing_Remaster_scripts.others.Option_Index_holder")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local unique_holder = require("Qing_Remaster_scripts.others.Unique_holder")
local pedestal_encounter = require("Qing_Remaster_scripts.others.Pedestal_Encounter_holder")
local pedestal_restore = require("Qing_Remaster_scripts.auxiliary.pedestal_restore")
local morph_txn = require("Qing_Remaster_scripts.others.Pickup_Morph_Transaction_holder")
local price_holder = require("Qing_Remaster_scripts.callbacks.price_holder")
local delay_buffer = require("Qing_Remaster_scripts.auxiliary.delay_buffer")
local collectible_holder = require("Qing_Remaster_scripts.callbacks.collectible_holder")
local gui = require("Qing_Remaster_scripts.auxiliary.gui")

local item = {
	ToCall = {},
	pre_ToCall = {},
	myToCall = {},
	entity = enums.Items.Isolation,
	own_key = "Item_Isolation_",
}

local REFUSE_LINES = {
	zh = {coward = "……", refuse = "我不接受。"},
	en = {coward = "...", refuse = "I refuse."},
}

local PICKUP_COLLECTIBLE = PickupVariant.PICKUP_COLLECTIBLE
local TAG_QUEST = ItemConfig.TAG_QUEST or (1 << 15)
local QUALITY_WEIGHT = {[0] = 1.0, [1] = 1.0, [2] = 1.0, [3] = 1.0, [4] = 0.15}
local MEMBER_COUNT = 10
local TOUCH_COOLDOWN = 30
local CIRCLE_SLOTS = 10
local CIRCLE_RADIUS = 64 -- Preferred ring; debug-tunable via item.debug_set_circle_radius
local CIRCLE_COMPRESS_RADII = {60, 56, 52} -- Floor ~52: keep adjacent pick spacing usable
local ROOM_EDGE_MARGIN = 24
local LAYOUT_MIN_OPTION_GAP = 30 -- Hard min between option centers (~0.618*52)
local LAYOUT_CONTACT_DIST = 28 -- Offset ring used to find a reachable touch point
local LAYOUT_ENTITY_CLEAR = 26
local LAYOUT_DOOR_CLEAR = 40
local LAYOUT_CANDIDATE_BUDGET = 140
local SETTLE_PENDING_FRAMES = 12
-- Consistance owner for party role marks (must not collide with rejected Isolation bag).
local PARTY_MARK = item.own_key .. "party_mark"

-- 仅无法用 Hidden / quest 标签判断的特殊排除（保持最小）。
local EXTRA_EXCLUDE = {
	-- 内部双形态 / 技术占位：Hidden 之外再保险
}

local touch_cd = {}
local touch_step = {}
local _spawning_companions = false
local _last_debug_report = ""
local _companion_exit_pending = {} -- PtrHash -> {token, index, frame}
local _companion_exit_done = {} -- PtrHash -> true (same-room morph dual-path guard)
local _room_rebind_scheduled = false
local _room_epoch = 0
local _refuse_speech = nil

local function snapshot_collectible_cycle(pickup)
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

local function restore_collectible_cycle(pickup, snapshot)
	if not pickup or type(snapshot) ~= "table" or not pickup.AddCollectibleCycle then
		return
	end
	for _, id in ipairs(snapshot) do
		if id and id > 0 and id ~= pickup.SubType then
			pcall(function()
				pickup:AddCollectibleCycle(id)
			end)
		end
	end
end

--- Freeze current displayed subtype as Host; clear Glitched Crown cycle.
local function freeze_host_cycle(pickup, frozen_subtype)
	if not pickup then return {} end
	frozen_subtype = tonumber(frozen_subtype) or pickup.SubType
	local snapshot = snapshot_collectible_cycle(pickup)
	if pickup.RemoveCollectibleCycle then
		pcall(function()
			pickup:RemoveCollectibleCycle()
		end)
	end
	if frozen_subtype and frozen_subtype > 0 and pickup.SubType ~= frozen_subtype and pickup.Morph then
		pcall(function()
			pickup:Morph(
				EntityType.ENTITY_PICKUP,
				PICKUP_COLLECTIBLE,
				frozen_subtype,
				true, true, true
			)
		end)
	end
	return snapshot
end

local SPEECH_DURATION = 45
local SPEECH_RISE = 24

local function clear_refuse_speech()
	_refuse_speech = nil
end

local function say_refuse(pos, key)
	if not pos then return end
	local lang = Options and Options.Language or "en"
	local pack = REFUSE_LINES[lang] or REFUSE_LINES.en
	local text = pack[key] or pack.refuse
	local chars = auxi.spilt_string and auxi.spilt_string(text) or {}
	_refuse_speech = {
		text = text,
		position = Vector(pos.X - (#chars) / 2, pos.Y - 36),
		age = 0,
		duration = SPEECH_DURATION,
		offset = Vector(0, 0),
		alpha = 1,
	}
end

local function advance_refuse_speech()
	if not _refuse_speech then return end
	local duration = _refuse_speech.duration or SPEECH_DURATION
	if duration <= 0 then
		clear_refuse_speech()
		return
	end
	_refuse_speech.age = (_refuse_speech.age or 0) + 1
	if _refuse_speech.age >= duration then
		clear_refuse_speech()
		return
	end
	local t = _refuse_speech.age / duration
	_refuse_speech.offset = Vector(0, -SPEECH_RISE * t)
	_refuse_speech.alpha = 1 - t
end

local function draw_refuse_speech()
	if not _refuse_speech or not _refuse_speech.text or not _refuse_speech.position then
		return
	end
	local alpha = _refuse_speech.alpha or 1
	if alpha <= 0 then return end
	local offset = _refuse_speech.offset or Vector(0, 0)
	local pos = Isaac.WorldToScreen(_refuse_speech.position + offset)
	gui.draw_text_units(_refuse_speech.text, pos.X, pos.Y, 1, 1, KColor(1, 1, 1, alpha), nil)
end

local function state_root()
	local root = save.elses[item.own_key .. "run"]
	if type(root) ~= "table" then
		root = {
			schema_version = 1,
			members = {},
			generated = false,
			parties = {},
			next_party = 1,
			expanded_gids = {},
		}
		save.elses[item.own_key .. "run"] = root
	end
	root.parties = root.parties or {}
	root.members = root.members or {}
	root.expanded_gids = root.expanded_gids or {}
	return root
end

-- Dev-only: Force Next Encounter as Clique Member (memory; never written to save.elses).
local _force_next_encounter_armed = false
local _test_members_override = nil -- {members, original, host_id, replaced_index, already_member, party_token}
-- force helpers defined after probe_note (see below).
local clear_test_members_override
local build_force_members_for_host
local active_members
local canonical_members

local function member_set()
	local set = {}
	local list
	if active_members then
		list = active_members()
	else
		list = state_root().members or {}
	end
	for _, id in ipairs(list) do
		set[tonumber(id) or 0] = true
	end
	return set
end

local function is_member(id)
	id = tonumber(id) or 0
	return id > 0 and member_set()[id] == true
end

local function holds_isolation(player)
	return player and player:GetCollectibleNum(item.entity) > 0
end

local function any_holder()
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if holds_isolation(p) then
			return true
		end
	end
	return false
end

local function player_key(player)
	if not player or not player.ToPlayer then return nil end
	player = player:ToPlayer()
	if not player then return nil end
	local data = player:GetData()
	local idx = data and data.__Index
	if idx == nil then return nil end
	return tostring(idx)
end

--- Probe bridge (require_probe only). Declared early so drop/settle can emit.
local function spawn_probe()
	local ok, env = pcall(require, "Qing_Remaster_scripts.core.dev_environment")
	if not ok or not env or not env.probes_allowed or not env.probes_allowed() then
		return nil
	end
	if not env.require_probe then return nil end
	return env.require_probe("Qing_Remaster_scripts.others.isolation_spawn_probe")
end

local function probe_note(kind, payload)
	local p = spawn_probe()
	if p and p.get_config and p.get_config().enabled == true and p.note then
		p.note(kind, payload)
	end
end

canonical_members = function()
	return state_root().members or {}
end

active_members = function()
	if type(_test_members_override) == "table"
		and type(_test_members_override.members) == "table"
		and #_test_members_override.members > 0
	then
		return _test_members_override.members
	end
	return canonical_members()
end

clear_test_members_override = function(reason)
	if not _test_members_override then
		return
	end
	local snap = _test_members_override
	_test_members_override = nil
	probe_note("FORCE_OVERRIDE_CLEARED", {
		reason = reason or "cleared",
		host_id = snap.host_id,
		party_token = snap.party_token,
		already_member = snap.already_member == true,
		replaced_index = snap.replaced_index,
	})
end

--- Build a 10-id temp clique: Host replaces one original slot (no duplicate IDs).
build_force_members_for_host = function(host_id)
	host_id = tonumber(host_id) or 0
	local original = {}
	for i, id in ipairs(canonical_members()) do
		original[i] = tonumber(id) or 0
	end
	if host_id <= 0 or #original == 0 then
		return nil, "NO_CANONICAL_CLIQUE"
	end
	local already = false
	for i = 1, #original do
		if original[i] == host_id then
			already = true
			break
		end
	end
	local temp = {}
	for i = 1, #original do
		temp[i] = original[i]
	end
	local replaced_index = nil
	if not already then
		replaced_index = 1
		for i = 1, #temp do
			if temp[i] ~= host_id then
				replaced_index = i
				break
			end
		end
		temp[replaced_index] = host_id
		local seen = {[host_id] = true}
		local cleaned = {host_id}
		for i = 1, #temp do
			local id = temp[i]
			if id ~= host_id and not seen[id] then
				seen[id] = true
				cleaned[#cleaned + 1] = id
			end
		end
		if #cleaned < #original then
			for i = 1, #original do
				local id = original[i]
				if not seen[id] then
					seen[id] = true
					cleaned[#cleaned + 1] = id
					if #cleaned >= #original then
						break
					end
				end
			end
		end
		temp = cleaned
		for i = 1, #temp do
			if temp[i] == host_id then
				replaced_index = i
				break
			end
		end
	end
	return {
		members = temp,
		original = original,
		host_id = host_id,
		replaced_index = replaced_index,
		already_member = already,
	}, nil
end

local function collectible_cfg(id)
	return Isaac.GetItemConfig():GetCollectible(id)
end

local function can_spawn_unlocked(id)
	local pool = Game():GetItemPool()
	if pool and pool.CanSpawnCollectible then
		local ok, ret = pcall(function()
			return pool:CanSpawnCollectible(id, false)
		end)
		if ok then
			return ret == true, "ok"
		end
		-- API 存在但调用失败：拒绝进入名单，避免未验证资格。
		return false, "can_spawn_error"
	end
	-- 无 RGON CanSpawnCollectible 时：仅依赖 Hidden/quest，不假装已解锁确认。
	return true, "no_api"
end

function item.is_clique_candidate(id)
	id = tonumber(id) or 0
	if id <= 0 or id == item.entity then
		return false, "self_or_invalid"
	end
	if EXTRA_EXCLUDE[id] then
		return false, "extra_exclude"
	end
	local cfg = collectible_cfg(id)
	if not cfg then
		return false, "no_config"
	end
	if cfg.Hidden then
		return false, "hidden"
	end
	if cfg.HasTags and cfg:HasTags(TAG_QUEST) then
		return false, "quest"
	end
	-- 剧情碎片 / 任务向标签的补充：部分条目仅靠字符串名不够，仍以 Tag 为准。
	local typ = cfg.Type
	if typ ~= ItemType.ITEM_PASSIVE and typ ~= ItemType.ITEM_ACTIVE and typ ~= ItemType.ITEM_FAMILIAR then
		return false, "type"
	end
	local unlocked, unlock_reason = can_spawn_unlocked(id)
	if not unlocked then
		return false, unlock_reason or "locked"
	end
	return true, nil
end

local function build_candidates()
	local by_quality = {[0] = {}, [1] = {}, [2] = {}, [3] = {}, [4] = {}}
	local itemConfig = Isaac.GetItemConfig()
	local sz = itemConfig:GetCollectibles().Size
	for id = 1, sz - 1 do
		local ok = item.is_clique_candidate(id)
		if ok then
			local cfg = collectible_cfg(id)
			local q = tonumber(cfg and cfg.Quality) or 0
			if q < 0 then q = 0 end
			if q > 4 then q = 4 end
			local bucket = by_quality[q]
			bucket[#bucket + 1] = id
		end
	end
	return by_quality
end

local function weighted_pick(rng, entries)
	local total = 0
	for i = 1, #entries do
		total = total + (entries[i].w or 0)
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:RandomFloat() * total
	local acc = 0
	for i = 1, #entries do
		acc = acc + (entries[i].w or 0)
		if roll <= acc then
			return entries[i]
		end
	end
	return entries[#entries]
end

local function isolation_rng()
	local player = Game():GetPlayer(0)
	local rng
	if player and player.GetCollectibleRNG then
		rng = player:GetCollectibleRNG(item.entity)
	end
	if not rng then
		rng = RNG()
		local seed = Game():GetSeeds():GetStartSeed()
		if seed == 0 then seed = 1 end
		rng:SetSeed(seed, 35)
	end
	return auxi.rng_for_sake(rng)
end

function item.generate_clique(opts)
	opts = opts or {}
	local root = state_root()
	if root.generated == true and opts.force ~= true then
		return root.members
	end
	local rng = opts.rng or isolation_rng()
	local by_q = build_candidates()
	local picked = {}
	local picked_set = {}
	local q4_used = 0
	local log = {}

	for _ = 1, MEMBER_COUNT do
		local entries = {}
		for q = 0, 4 do
			if q == 4 and q4_used >= 1 then
				goto continue_q
			end
			local bucket = by_q[q]
			local available = 0
			for i = 1, #bucket do
				if not picked_set[bucket[i]] then
					available = available + 1
				end
			end
			if available > 0 then
				entries[#entries + 1] = {
					q = q,
					w = (QUALITY_WEIGHT[q] or 0) * available,
					bucket = bucket,
				}
			end
			::continue_q::
		end
		if #entries == 0 then
			break
		end
		local choice = weighted_pick(rng, entries)
		if not choice then break end
		local pool = {}
		for i = 1, #choice.bucket do
			local id = choice.bucket[i]
			if not picked_set[id] then
				pool[#pool + 1] = id
			end
		end
		if #pool == 0 then break end
		local id = pool[rng:RandomInt(#pool) + 1]
		picked[#picked + 1] = id
		picked_set[id] = true
		if choice.q == 4 then
			q4_used = q4_used + 1
		end
		local cfg = collectible_cfg(id)
		log[#log + 1] = {
			id = id,
			name = cfg and cfg.Name or "?",
			quality = choice.q,
		}
	end

	if #picked < MEMBER_COUNT then
		Isaac.DebugString(string.format(
			"[Isolation] clique undersized: %d/%d",
			#picked, MEMBER_COUNT
		))
	end

	root.members = picked
	root.generated = true
	root.draw_log = log
	root.parties = {}
	root.next_party = 1
	if opts.force == true then
		root.expanded_gids = {}
	end
	return picked
end

function item.get_members()
	if type(_test_members_override) == "table"
		and type(_test_members_override.members) == "table"
		and #_test_members_override.members > 0
	then
		return _test_members_override.members
	end
	local root = state_root()
	if root.generated ~= true then
		return {}
	end
	return root.members or {}
end

function item.ensure_clique()
	local root = state_root()
	if root.generated ~= true then
		item.generate_clique()
	end
	return item.get_members()
end

--- Dev probe: arm one-shot Force Next Eligible Encounter as Clique Member.
function item.set_force_next_encounter_as_member(armed)
	_force_next_encounter_armed = armed == true
	if not _force_next_encounter_armed and not (
		type(_test_members_override) == "table"
		and _test_members_override.party_token
	) then
		-- Disarm before a party started: drop idle override immediately.
		clear_test_members_override("force_disarmed")
	end
	return _force_next_encounter_armed
end

function item.is_force_next_encounter_as_member()
	return _force_next_encounter_armed == true
end

function item.has_test_members_override()
	return type(_test_members_override) == "table"
		and type(_test_members_override.members) == "table"
		and #_test_members_override.members > 0
end

function item.get_test_members_override_snapshot()
	if not item.has_test_members_override() then
		return nil
	end
	local o = _test_members_override
	return {
		host_id = o.host_id,
		replaced_index = o.replaced_index,
		already_member = o.already_member == true,
		party_token = o.party_token,
		members = o.members,
		original = o.original,
	}
end

local function rejected_data(pickup)
	if not pickup or not pickup.GetData then return nil end
	local data = pickup:GetData()
	local function get_bag()
		local bag = data._Data and data._Data[item.own_key]
		if type(bag) == "table" and bag.rejected == true then
			-- Rematerialized rejected Isolation must stay contactable for refuse feedback.
			pickup.EntityCollisionClass = EntityCollisionClass.ENTCOLL_PLAYERONLY
			return bag
		end
		return nil
	end
	local bag = get_bag()
	if bag then return bag end
	if consistance_holder.try_check_entity(pickup, item.own_key) then
		return get_bag()
	end
	return nil
end

local function mark_rejected(pickup, rejected_by)
	local data = pickup:GetData()
	data._Data = data._Data or {}
	local bag = {rejected = true}
	rejected_by = tonumber(rejected_by)
	if rejected_by and rejected_by > 0 then
		bag.rejected_by = rejected_by
	end
	data._Data[item.own_key] = bag
	-- Keep player contact so refuse feedback can fire; collision callback still blocks acquire.
	pickup.EntityCollisionClass = EntityCollisionClass.ENTCOLL_PLAYERONLY
	consistance_holder.try_hold_entity(pickup, item.own_key, {consistance = true})
end

local function drop_rejected(player, collectible_id)
	local before = player and player:GetCollectibleNum(item.entity) or 0
	local winner_id = tonumber(collectible_id)
	local pedestal = pedestal_restore.spawn_owned_collectible(
		item.own_key,
		{collectible_id = item.entity, touched = true, charge = 0},
		player.Position,
		player,
		function(pickup)
			mark_rejected(pickup, winner_id)
		end
	)
	if not pedestal then
		probe_note("ISOLATION_DROP", {
			ok = false,
			reason = "DROP_FAILED",
			before = before,
			after = before,
			rejected_by = winner_id,
		})
		return false
	end
	player:RemoveCollectible(item.entity)
	local after = player:GetCollectibleNum(item.entity)
	say_refuse(pedestal.Position, "refuse")
	probe_note("ISOLATION_DROP", {
		ok = true,
		before = before,
		after = after,
		removed = before - after,
		rejected_by = winner_id,
		pedestal_x = pedestal.Position.X,
		pedestal_y = pedestal.Position.Y,
	})
	return true
end

local function party_data(pickup)
	if not pickup then return nil end
	local d = pickup:GetData()
	return d[item.own_key .. "party"]
end

local function set_party_data(pickup, info)
	pickup:GetData()[item.own_key .. "party"] = info
end

local function clear_party_mark(pickup)
	if not pickup then return end
	set_party_data(pickup, nil)
	local data = pickup:GetData()
	if data._Data then
		data._Data[PARTY_MARK] = nil
	end
	if consistance_holder.try_remove_entity then
		consistance_holder.try_remove_entity(pickup, PARTY_MARK)
	end
end

--- Persist party role on pedestal via Consistance so leave/return can rebind.
local function persist_party_mark(pickup, info)
	if not pickup or not info then return end
	set_party_data(pickup, info)
	local data = pickup:GetData()
	data._Data = data._Data or {}
	data._Data[PARTY_MARK] = {party = auxi.deepCopy(info)}
	consistance_holder.try_hold_entity(pickup, PARTY_MARK, {consistance = true})
end

local function restore_party_mark(pickup)
	if not pickup then return nil end
	local live = party_data(pickup)
	if live then return live end
	if not consistance_holder.try_check_entity(pickup, PARTY_MARK) then
		return nil
	end
	local bag = pickup:GetData()._Data and pickup:GetData()._Data[PARTY_MARK]
	local info = bag and bag.party
	if type(info) ~= "table" or not info.token then
		return nil
	end
	set_party_data(pickup, info)
	return info
end

local function party_is_open(party)
	return party
		and party.settled ~= true
		and party.dissolved ~= true
end

local function find_open_party_by_gid(gid)
	gid = tonumber(gid)
	if not gid then return nil end
	local root = state_root()
	for token, party in pairs(root.parties or {}) do
		if party_is_open(party) then
			if tonumber(party.host_gid) == gid then
				return party, token, "host", nil
			end
			for i, row in ipairs(party.companions or {}) do
				if row and row.status ~= "exited" and tonumber(row.gid) == gid then
					return party, token, "companion", i
				end
			end
		end
	end
	return nil
end

local function rebind_pickup_to_party(pickup)
	if not pickup or pickup.Variant ~= PICKUP_COLLECTIBLE then return nil end
	if _spawning_companions then return nil end

	local info = restore_party_mark(pickup)
	local root = state_root()
	if info and info.token then
		local party = root.parties[info.token]
		if not party_is_open(party) then
			clear_party_mark(pickup)
			return nil
		end
		if (tonumber(pickup.OptionsPickupIndex) or 0) == 0 then
			pickup.OptionsPickupIndex = party.option_index or 0
		end
		-- Room restore: redeploy to saved layout slots (not assumed circle).
		if party.layout then
			local want = nil
			if info.role == "host" and party.layout.host_target_x then
				want = Vector(party.layout.host_target_x, party.layout.host_target_y)
			elseif info.role == "companion" and type(party.layout.companion_targets) == "table" then
				local slot = party.layout.companion_targets[tonumber(info.index) or 0]
				if slot and slot.x and slot.y then
					want = Vector(slot.x, slot.y)
				end
			end
			if want then
				local dist = pickup.Position:Distance(want)
				if dist > 8 then
					probe_note("HOST_POSITION_DRIFT", {
						token = info.token,
						role = info.role,
						index = info.index,
						layout_type = party.layout.layout_type,
						delay = "rebind",
						x = pickup.Position.X,
						y = pickup.Position.Y,
						want_x = want.X,
						want_y = want.Y,
						dist = dist,
						same_room = false,
						room_restore = true,
					})
					pickup.Position = want
					pickup.Velocity = Vector.Zero
					pickup.TargetPosition = Vector(want.X, want.Y)
				end
			end
		end
		return info
	end

	local gen = unique_holder.resolve_generation(pickup)
	local gid = gen and tonumber(gen.id)
	if not gid then return nil end
	local party, token, role, index = find_open_party_by_gid(gid)
	if not party then return nil end

	local expected = pickup.SubType
	if role == "host" then
		expected = tonumber(party.host_subtype) or expected
	elseif role == "companion" then
		local row = party.companions and party.companions[index]
		expected = (row and tonumber(row.id)) or expected
	end
	info = {
		token = token,
		role = role,
		expected = expected,
		index = index,
	}
	persist_party_mark(pickup, info)
	pickup.OptionsPickupIndex = party.option_index or pickup.OptionsPickupIndex
	if pedestal_encounter.mark_suppressed and role == "companion" then
		pedestal_encounter.mark_suppressed(pickup, item.own_key)
	end
	-- Apply saved layout coordinates on first rebind as well.
	if party.layout then
		local want = nil
		if role == "host" and party.layout.host_target_x then
			want = Vector(party.layout.host_target_x, party.layout.host_target_y)
		elseif role == "companion" and type(party.layout.companion_targets) == "table" then
			local slot = party.layout.companion_targets[tonumber(index) or 0]
			if slot and slot.x and slot.y then
				want = Vector(slot.x, slot.y)
			end
		end
		if want and pickup.Position:Distance(want) > 8 then
			pickup.Position = want
			pickup.Velocity = Vector.Zero
			pickup.TargetPosition = Vector(want.X, want.Y)
		end
	end
	return info
end

local dissolve_party -- forward decl for room validate

local function is_option_pending_remove(ent)
	if auxi.check_all_exists(ent) ~= true then return true end
	local pickup = ent:ToPickup()
	if not pickup then return true end
	return pickup:GetData()[option_index_holder.own_key .. "Remove"] == true
end

local function is_option_picked(ent)
	if auxi.check_all_exists(ent) ~= true then return false end
	local pickup = ent:ToPickup()
	if not pickup then return false end
	return pickup:GetData()[option_index_holder.own_key .. "Pick"] == true
end

--- Capture Host trade condition for the whole party (shared deal, not per-item reprice).
local function resolve_host_trade(host)
	if not host then
		return {resolved = false, has_price = false, source = "nil_host"}
	end
	local quote = price_holder.get_quote(host)
	if not quote or quote.resolved ~= true then
		local captured, ok = price_holder.capture_quote(host)
		if ok then
			quote = captured
		end
	end
	if quote and quote.resolved == true then
		return {
			resolved = true,
			has_price = quote.has_price == true,
			price = quote.has_price and quote.price or nil,
			was_shop_item = quote.is_shop_item == true,
			locked = quote.locked == true,
			source = "price_holder",
		}
	end
	local raw = host.Price or 0
	local shop = host.IsShopItem and host:IsShopItem() == true or false
	if shop or raw ~= 0 then
		return {
			resolved = true,
			has_price = true,
			price = raw,
			was_shop_item = shop,
			locked = false,
			source = "live_fallback",
		}
	end
	return {
		resolved = true,
		has_price = false,
		price = nil,
		was_shop_item = false,
		locked = false,
		source = "free",
	}
end

local function price_audit_fields(pickup, extra)
	local quote = pickup and price_holder.get_quote(pickup) or nil
	local auto = nil
	if pickup then
		pcall(function()
			auto = pickup.AutoUpdatePrice
		end)
	end
	local row = {
		subtype = pickup and pickup.SubType or nil,
		price = pickup and pickup.Price or nil,
		shop_item_id = pickup and pickup.ShopItemId or nil,
		auto_update_price = auto,
		is_shop_item = pickup and pickup.IsShopItem and pickup:IsShopItem() == true or false,
		quote_resolved = quote and quote.resolved == true or false,
		quote_has_price = quote and quote.has_price == true or false,
		quote_price = quote and quote.price or nil,
		quote_locked = quote and quote.locked == true or false,
	}
	if type(extra) == "table" then
		for k, v in pairs(extra) do
			row[k] = v
		end
	end
	return row
end

--- Apply the Host's resolved trade to a party pedestal. Free Host → leave alone.
local function apply_party_trade(pickup, trade)
	if not pickup or type(trade) ~= "table" then
		return false
	end
	if trade.has_price == true and type(trade.price) == "number" then
		return price_holder.lock_price(pickup, trade.price, {
			was_shop_item = trade.was_shop_item == true,
		}) == true
	end
	return false
end

local function skip_party_scene(pickup)
	if not pickup then return true, "NIL" end
	-- Shop pedestals are allowed: Host trade is captured and Companions inherit via lock_price.
	if (pickup.OptionsPickupIndex or 0) ~= 0 then return true, "EXISTING_OPTIONS" end
	if pedestal_encounter.is_death_certificate_display
		and pedestal_encounter.is_death_certificate_display(pickup) then
		return true, "DC_DISPLAY"
	end
	if pedestal_encounter.is_suppressed and pedestal_encounter.is_suppressed(pickup) then
		return true, "SUPPRESSED"
	end
	return false, nil
end

function item.debug_set_circle_radius(r)
	r = tonumber(r)
	if not r or r < 24 then r = 24 end
	if r > 120 then r = 120 end
	CIRCLE_RADIUS = r
	return CIRCLE_RADIUS
end

function item.debug_get_circle_radius()
	return CIRCLE_RADIUS
end

--- Observe-only gate snapshot for D6 / Morph probes (does not start a party).
function item.probe_d6_expand_status(pickup)
	local out = {
		holders = 0,
		is_member = false,
		already_party = false,
		skip_scene = false,
		skip_reason = nil,
		generation_id = nil,
		generation_kind = nil,
		birth_room_epoch = nil,
		room_generation_epoch = unique_holder.get_room_generation_epoch
			and unique_holder.get_room_generation_epoch()
			or nil,
		is_fresh_generation = false,
		expanded_gid = false,
		has_cycle = false,
		cycle_size = 0,
		encounter_published = false,
		encounter_class = nil,
		would_start_party = false,
		block_reasons = {},
		trigger_paths = {
			encounter = false,
			cycle_display = false,
			d6_dedicated = false,
		},
	}
	if not pickup then
		out.block_reasons[#out.block_reasons + 1] = "NIL_PICKUP"
		return out
	end
	do
		local n = 0
		for i = 0, Game():GetNumPlayers() - 1 do
			local p = Game():GetPlayer(i)
			if holds_isolation(p) then
				n = n + 1
			end
		end
		out.holders = n
	end
	if out.holders <= 0 then
		out.block_reasons[#out.block_reasons + 1] = "NO_ISOLATION_HOLDER"
	end
	item.ensure_clique()
	out.is_member = is_member(pickup.SubType) == true
	if not out.is_member then
		out.block_reasons[#out.block_reasons + 1] = "NOT_CLIQUE_MEMBER"
	end
	local info = party_data(pickup) or restore_party_mark(pickup)
	out.already_party = info ~= nil
	if out.already_party then
		out.block_reasons[#out.block_reasons + 1] = "ALREADY_PARTY"
		out.party_role = info.role
		out.party_token = info.token
	end
	local skip, skip_reason = skip_party_scene(pickup)
	out.skip_scene = skip == true
	out.skip_reason = skip_reason
	if skip then
		out.block_reasons[#out.block_reasons + 1] = skip_reason or "SCENE_SKIP"
	end
	local gen = unique_holder.resolve_generation(pickup)
	out.generation_id = gen and tonumber(gen.id) or nil
	out.generation_kind = gen and gen.kind or nil
	out.birth_room_epoch = gen and tonumber(gen.birth_room_epoch) or nil
	out.is_fresh_generation = unique_holder.is_fresh_generation
		and unique_holder.is_fresh_generation(pickup) == true
	if out.generation_id then
		local root = state_root()
		out.expanded_gid = root.expanded_gids[tostring(out.generation_id)] == true
		if out.expanded_gid then
			out.block_reasons[#out.block_reasons + 1] = "ALREADY_EXPANDED"
		end
		if pedestal_encounter.has_published_normal_encounter then
			out.encounter_published = pedestal_encounter.has_published_normal_encounter(out.generation_id) == true
		end
	else
		out.block_reasons[#out.block_reasons + 1] = "NO_GENERATION_ID"
	end
	if pickup.GetCollectibleCycle then
		local ok, cycle = pcall(function()
			return pickup:GetCollectibleCycle()
		end)
		if ok and type(cycle) == "table" then
			out.cycle_size = #cycle
			out.has_cycle = #cycle > 0
		end
	end
	local d = pickup:GetData()
	out.encounter_class = (d and d._QingPedestalEncounterClass)
		or (pedestal_encounter.debug and pedestal_encounter.debug.last_class)
	-- Current product paths (no dedicated D6 path yet).
	out.trigger_paths.encounter = out.is_fresh_generation == true
		and out.encounter_published ~= true
		and out.is_member == true
	out.trigger_paths.cycle_display = out.has_cycle == true and out.is_member == true
	out.trigger_paths.d6_dedicated = false
	if out.trigger_paths.encounter or out.trigger_paths.cycle_display then
		out.would_start_party = out.holders > 0
			and out.is_member
			and not out.already_party
			and not out.skip_scene
			and out.generation_id ~= nil
			and not out.expanded_gid
	else
		out.block_reasons[#out.block_reasons + 1] = "NO_TRIGGER_PATH"
		-- Helpful detail when Morph to member but Encounter/Cycle both unavailable.
		if out.is_member and not out.has_cycle and not out.is_fresh_generation then
			out.block_reasons[#out.block_reasons + 1] = "NOT_FRESH_NO_CYCLE"
		elseif out.is_member and not out.has_cycle and out.encounter_published then
			out.block_reasons[#out.block_reasons + 1] = "ENCOUNTER_ALREADY_PUBLISHED_NO_CYCLE"
		end
	end
	return out
end

--- Ten equal slots on a circle. Slot 0 = host (visual top: angle -pi/2).
local function circle_slot_positions(center, radius, companion_count, phase)
	companion_count = math.max(0, math.min(9, tonumber(companion_count) or 9))
	radius = tonumber(radius) or CIRCLE_RADIUS
	phase = tonumber(phase) or 0
	local step = (math.pi * 2) / CIRCLE_SLOTS
	local host_angle = -math.pi / 2 + phase
	local host_pos = center + Vector(
		math.cos(host_angle) * radius,
		math.sin(host_angle) * radius
	)
	local companions = {}
	for i = 1, companion_count do
		local angle = host_angle + i * step
		companions[i] = center + Vector(math.cos(angle) * radius, math.sin(angle) * radius)
	end
	return host_pos, companions
end

--- Dual-row / dual-column / staggered formations. Host = top-center (or left-center for vertical).
local function dual_slot_positions(center, companion_count, kind, spacing, stagger)
	companion_count = math.max(0, math.min(9, tonumber(companion_count) or 9))
	spacing = tonumber(spacing) or 40
	stagger = tonumber(stagger) or 0
	local total = 1 + companion_count
	local positions = {}
	if kind == "dual_row_h" or kind == "dual_row_stagger" then
		-- 5 on top, 5 on bottom; Host at top-center index 2.
		local cols = 5
		local rows = 2
		local ox = -(cols - 1) * spacing * 0.5
		local oy = -spacing * 0.5
		local idx = 0
		for r = 0, rows - 1 do
			local row_stagger = (kind == "dual_row_stagger" and r == 1) and stagger or 0
			for c = 0, cols - 1 do
				idx = idx + 1
				if idx > total then break end
				positions[idx] = center + Vector(
					ox + c * spacing + row_stagger,
					oy + r * spacing
				)
			end
		end
	else
		-- dual_col_v: 2 columns × 5 rows; Host at left-center (row 2, col 0).
		local cols = 2
		local rows = 5
		local ox = -spacing * 0.5
		local oy = -(rows - 1) * spacing * 0.5
		local idx = 0
		for r = 0, rows - 1 do
			for c = 0, cols - 1 do
				idx = idx + 1
				if idx > total then break end
				positions[idx] = center + Vector(
					ox + c * spacing,
					oy + r * spacing
				)
			end
		end
	end
	-- Map Host to a distinctive center-ish slot; rest become companions in list order.
	local host_slot = 3 -- top-center for 5-col; for 2-col remap below
	if kind == "dual_col_v" then
		host_slot = 5 -- left column, middle row (0-based row2 col0 → index 5)
	end
	if host_slot > #positions then
		host_slot = 1
	end
	local host_pos = positions[host_slot]
	local companions = {}
	for i = 1, #positions do
		if i ~= host_slot then
			companions[#companions + 1] = positions[i]
			if #companions >= companion_count then
				break
			end
		end
	end
	return host_pos, companions
end

local function layout_now_ms()
	if Isaac and Isaac.GetTime then
		return Isaac.GetTime()
	end
	return nil
end

local function grid_walkable_cached(ctx, index)
	if index == nil or index < 0 then
		return false
	end
	local cached = ctx.walk_cache[index]
	if cached ~= nil then
		return cached
	end
	local room = ctx.room
	-- Align with project PathFinding: empty / none-collision, or GridPath < 900.
	local gent = room:GetGridEntity(index)
	local ok
	if not gent or gent.CollisionClass == GridCollisionClass.COLLISION_NONE then
		ok = true
	else
		local path = room:GetGridPath(index)
		ok = path ~= nil and path < 900
		local gt = gent:GetType()
		if gt == GridEntityType.GRID_PIT then
			ok = false
		end
	end
	ctx.walk_cache[index] = ok == true
	return ctx.walk_cache[index]
end

local function build_reachable_set(ctx)
	local room = ctx.room
	local width = room:GetGridWidth()
	local size = room:GetGridSize()
	local queue = {}
	local head = 1
	local reachable = {}
	local function push(idx)
		if idx == nil or idx < 0 or idx >= size then return end
		if reachable[idx] then return end
		if not grid_walkable_cached(ctx, idx) then return end
		reachable[idx] = true
		queue[#queue + 1] = idx
	end
	for i = 1, #ctx.seed_indices do
		push(ctx.seed_indices[i])
	end
	while head <= #queue do
		local cur = queue[head]
		head = head + 1
		local x = cur % width
		local y = math.floor(cur / width)
		local neigh = {
			cur - 1, cur + 1, cur - width, cur + width,
		}
		-- Bound horizontal wrap.
		if x > 0 then push(neigh[1]) end
		if x < width - 1 then push(neigh[2]) end
		push(neigh[3])
		push(neigh[4])
	end
	ctx.reachable = reachable
end

local function build_layout_context(host)
	local room = Game():GetRoom()
	local host_ptr = GetPtrHash(host)
	local entities = Isaac.GetRoomEntities()
	local blockers = {}
	for _, ent in ipairs(entities) do
		if ent and ent.Exists and ent:Exists() and GetPtrHash(ent) ~= host_ptr then
			local use = false
			if ent.Type == EntityType.ENTITY_PICKUP
				or ent.Type == EntityType.ENTITY_SLOT
			then
				use = true
			elseif ent.ToNPC and ent:ToNPC() and ent:IsActiveEnemy(false) then
				use = true
			end
			if use then
				blockers[#blockers + 1] = {
					x = ent.Position.X,
					y = ent.Position.Y,
					type = ent.Type,
					variant = ent.Variant,
				}
			end
		end
	end
	local doors = {}
	for slot = 0, DoorSlot.NUM_DOOR_SLOTS - 1 do
		local door = room:GetDoor(slot)
		if door then
			doors[#doors + 1] = {
				x = door.Position.X,
				y = door.Position.Y,
			}
		end
	end
	local seed_indices = {}
	local function add_seed(pos)
		if not pos then return end
		local idx = room:GetGridIndex(pos)
		if idx and idx >= 0 then
			seed_indices[#seed_indices + 1] = idx
		end
	end
	add_seed(host.Position)
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		if p then
			add_seed(p.Position)
		end
	end
	add_seed(room:GetCenterPos())
	local ctx = {
		room = room,
		host_ptr = host_ptr,
		host_origin = Vector(host.Position.X, host.Position.Y),
		blockers = blockers,
		doors = doors,
		seed_indices = seed_indices,
		walk_cache = {},
		collision_cache = {},
		reachable = {},
	}
	build_reachable_set(ctx)
	return ctx
end

local function collision_flags_cached(ctx, pos)
	local room = ctx.room
	local idx = room:GetGridIndex(pos)
	local key = idx
	local cached = ctx.collision_cache[key]
	if cached then
		return cached.out, cached.solid, cached.pit
	end
	local out, solid, pit = 0, 0, 0
	if not room:IsPositionInRoom(pos, ROOM_EDGE_MARGIN * 0.5) then
		out = 1
	end
	local col = room:GetGridCollisionAtPos(pos)
	if col == GridCollisionClass.COLLISION_PIT then
		pit = 1
	elseif col ~= nil and col ~= GridCollisionClass.COLLISION_NONE then
		solid = 1
	end
	local gent = room.GetGridEntityFromPos and room:GetGridEntityFromPos(pos)
	if gent then
		local gt = gent:GetType()
		if gt == GridEntityType.GRID_PIT then
			pit = 1
			solid = 0
		elseif gt == GridEntityType.GRID_WALL
			or gt == GridEntityType.GRID_ROCK
			or gt == GridEntityType.GRID_ROCKB
			or gt == GridEntityType.GRID_ROCKT
			or gt == GridEntityType.GRID_ROCK_ALT
			or gt == GridEntityType.GRID_ROCK_SPIKED
			or gt == GridEntityType.GRID_ROCK_ALT2
			or gt == GridEntityType.GRID_ROCK_GOLD
		then
			solid = 1
		end
	end
	ctx.collision_cache[key] = {out = out, solid = solid, pit = pit}
	return out, solid, pit
end

local function count_blocker_hits(ctx, pos, radius)
	radius = radius or LAYOUT_ENTITY_CLEAR
	local hits = 0
	for i = 1, #ctx.blockers do
		local b = ctx.blockers[i]
		local dx = b.x - pos.X
		local dy = b.y - pos.Y
		if dx * dx + dy * dy < radius * radius then
			hits = hits + 1
		end
	end
	return hits
end

local function count_door_hits(ctx, pos, radius)
	radius = radius or LAYOUT_DOOR_CLEAR
	local hits = 0
	for i = 1, #ctx.doors do
		local d = ctx.doors[i]
		local dx = d.x - pos.X
		local dy = d.y - pos.Y
		if dx * dx + dy * dy < radius * radius then
			hits = hits + 1
		end
	end
	return hits
end

--- Pedestal may sit slightly off-center; need a reachable contact cell nearby.
local function has_reachable_contact(ctx, pos)
	local room = ctx.room
	local offsets = {
		Vector(0, 0),
		Vector(LAYOUT_CONTACT_DIST, 0),
		Vector(-LAYOUT_CONTACT_DIST, 0),
		Vector(0, LAYOUT_CONTACT_DIST),
		Vector(0, -LAYOUT_CONTACT_DIST),
		Vector(LAYOUT_CONTACT_DIST * 0.7, LAYOUT_CONTACT_DIST * 0.7),
		Vector(-LAYOUT_CONTACT_DIST * 0.7, LAYOUT_CONTACT_DIST * 0.7),
		Vector(LAYOUT_CONTACT_DIST * 0.7, -LAYOUT_CONTACT_DIST * 0.7),
		Vector(-LAYOUT_CONTACT_DIST * 0.7, -LAYOUT_CONTACT_DIST * 0.7),
	}
	for i = 1, #offsets do
		local p = pos + offsets[i]
		if room:IsPositionInRoom(p, 0) then
			local idx = room:GetGridIndex(p)
			if idx and ctx.reachable[idx] then
				return true
			end
		end
	end
	return false
end

local function validate_layout_positions(ctx, host_pos, companions)
	local positions = {host_pos}
	for i = 1, #companions do
		positions[#positions + 1] = companions[i]
	end
	local out_of_room, solid, pit = 0, 0, 0
	local entity_hits, door_hits = 0, 0
	local unreachable, option_overlap = 0, 0
	local min_gap = math.huge
	for i = 1, #positions do
		local o, s, p = collision_flags_cached(ctx, positions[i])
		out_of_room = out_of_room + o
		solid = solid + s
		pit = pit + p
		entity_hits = entity_hits + count_blocker_hits(ctx, positions[i], LAYOUT_ENTITY_CLEAR)
		door_hits = door_hits + count_door_hits(ctx, positions[i], LAYOUT_DOOR_CLEAR)
		if not has_reachable_contact(ctx, positions[i]) then
			unreachable = unreachable + 1
		end
		for j = i + 1, #positions do
			local d = positions[i]:Distance(positions[j])
			if d < min_gap then
				min_gap = d
			end
			if d < LAYOUT_MIN_OPTION_GAP then
				option_overlap = option_overlap + 1
			end
		end
	end
	if min_gap == math.huge then
		min_gap = 0
	end
	local fully_valid = out_of_room == 0
		and solid == 0
		and pit == 0
		and unreachable == 0
		and option_overlap == 0
		and door_hits == 0
	-- Soft entity hits do not alone fail hard validity (busy rooms), but count for ranking.
	local hard_entity = 0
	-- Treat entity sitting exactly on a slot as blocked access.
	for i = 1, #positions do
		if count_blocker_hits(ctx, positions[i], 14) > 0 then
			hard_entity = hard_entity + 1
		end
	end
	if hard_entity > 0 then
		fully_valid = false
	end
	return fully_valid, {
		out_of_room = out_of_room,
		solid = solid,
		pit = pit,
		entity_hits = entity_hits,
		door_hits = door_hits,
		unreachable = unreachable,
		option_overlap = option_overlap,
		blocked_access = unreachable + hard_entity,
		min_gap = min_gap,
		slot_count = #positions,
	}
end

local function soft_score(layout_priority, host_origin, host_pos, center, flags, preferred_center)
	local host_disp = host_origin:Distance(host_pos)
	local center_disp = preferred_center and preferred_center:Distance(center) or 0
	return layout_priority * 1000
		+ flags.out_of_room * 200
		+ flags.solid * 80
		+ flags.pit * 70
		+ flags.unreachable * 90
		+ flags.option_overlap * 60
		+ flags.door_hits * 50
		+ flags.blocked_access * 40
		+ flags.entity_hits * 8
		+ host_disp * 0.12
		+ center_disp * 0.05
		- math.min(flags.min_gap or 0, 80) * 0.15
end

local function dedupe_centers(cands)
	local uniq = {}
	local out = {}
	for i = 1, #cands do
		local c = cands[i]
		local key = string.format("%d:%d", math.floor(c.X / 8 + 0.5), math.floor(c.Y / 8 + 0.5))
		if not uniq[key] then
			uniq[key] = true
			out[#out + 1] = c
		end
	end
	return out
end

local function build_translation_candidates(host_pos, preferred, denser)
	local room = Game():GetRoom()
	local room_center = room:GetCenterPos()
	local cands = {preferred, room_center, host_pos}
	local ring = denser and {0, 24, 48, 72, 96, 120} or {0, 40, 80, 120}
	local angles = {0, 45, 90, 135, 180, 225, 270, 315}
	for _, dist in ipairs(ring) do
		if dist > 0 then
			for _, deg in ipairs(angles) do
				local rad = deg * math.pi / 180
				local off = Vector(math.cos(rad) * dist, math.sin(rad) * dist)
				cands[#cands + 1] = preferred + off
				cands[#cands + 1] = room_center + off
			end
		end
	end
	return dedupe_centers(cands)
end

--- Adaptive layout V2: circle → compress → dual-row. Always returns a layout.
local function compute_party_layout(host, companion_count)
	local t0 = layout_now_ms()
	local ctx = build_layout_context(host)
	local host_pos = ctx.host_origin
	companion_count = math.max(0, math.min(9, tonumber(companion_count) or 9))

	local plans = {}
	-- Priority 1: standard ring.
	plans[#plans + 1] = {
		layout_type = "circle",
		priority = 1,
		radius = CIRCLE_RADIUS,
		phases = {0},
	}
	-- Priority 2: compressed rings.
	for _, r in ipairs(CIRCLE_COMPRESS_RADII) do
		plans[#plans + 1] = {
			layout_type = "circle",
			priority = 2,
			radius = r,
			phases = {0, math.pi / 20, -math.pi / 20},
		}
	end
	-- Priority 3+: dual formations.
	plans[#plans + 1] = {
		layout_type = "dual_row_h",
		priority = 3,
		spacings = {40, 36, 44},
	}
	plans[#plans + 1] = {
		layout_type = "dual_col_v",
		priority = 4,
		spacings = {40, 36, 44},
	}
	plans[#plans + 1] = {
		layout_type = "dual_row_stagger",
		priority = 5,
		spacings = {40, 36},
		stagger = 20,
	}

	local evaluated = 0
	local valid_count = 0
	local best_valid = nil
	local best_any = nil

	local function consider(cand)
		evaluated = evaluated + 1
		if cand.fully_valid then
			valid_count = valid_count + 1
			if not best_valid or cand.score < best_valid.score then
				best_valid = cand
			end
		end
		if not best_any or cand.score < best_any.score then
			best_any = cand
		end
	end

	for pi = 1, #plans do
		if evaluated >= LAYOUT_CANDIDATE_BUDGET then
			break
		end
		-- Once we have a fully valid layout in a better-or-equal priority tier, skip worse tiers.
		if best_valid and plans[pi].priority > best_valid.priority then
			break
		end
		local plan = plans[pi]
		local preferred
		if plan.layout_type == "circle" then
			preferred = host_pos + Vector(0, plan.radius)
		else
			preferred = host_pos + Vector(0, 20)
		end
		local denser = plan.priority >= 3
		local centers = build_translation_candidates(host_pos, preferred, denser)
		local phases = plan.phases or {0}
		local spacings = plan.spacings or {40}

		for _, center in ipairs(centers) do
			if evaluated >= LAYOUT_CANDIDATE_BUDGET then
				break
			end
			if plan.layout_type == "circle" then
				for _, phase in ipairs(phases) do
					if evaluated >= LAYOUT_CANDIDATE_BUDGET then break end
					local hpos, comps = circle_slot_positions(center, plan.radius, companion_count, phase)
					local fully, flags = validate_layout_positions(ctx, hpos, comps)
					local score = soft_score(plan.priority, host_pos, hpos, center, flags, preferred)
					consider({
						layout_type = "circle_r" .. tostring(plan.radius),
						priority = plan.priority,
						radius = plan.radius,
						phase = phase,
						center = center,
						host = hpos,
						companions = comps,
						fully_valid = fully,
						flags = flags,
						score = score,
						preferred = preferred,
					})
					-- Early accept excellent standard ring.
					if fully and plan.priority == 1 and flags.entity_hits == 0 then
						break
					end
				end
			else
				for _, spacing in ipairs(spacings) do
					if evaluated >= LAYOUT_CANDIDATE_BUDGET then break end
					local hpos, comps = dual_slot_positions(
						center,
						companion_count,
						plan.layout_type,
						spacing,
						plan.stagger or 0
					)
					local fully, flags = validate_layout_positions(ctx, hpos, comps)
					local score = soft_score(plan.priority, host_pos, hpos, center, flags, preferred)
					consider({
						layout_type = plan.layout_type,
						priority = plan.priority,
						radius = nil,
						spacing = spacing,
						stagger = plan.stagger,
						center = center,
						host = hpos,
						companions = comps,
						fully_valid = fully,
						flags = flags,
						score = score,
						preferred = preferred,
					})
				end
			end
		end
	end

	local selected = best_valid or best_any
	local fallback_unsafe = selected == nil or selected.fully_valid ~= true
	if not selected then
		-- Absolute last resort: fixed ring on host (should be unreachable).
		local center = host_pos + Vector(0, CIRCLE_RADIUS)
		local hpos, comps = circle_slot_positions(center, CIRCLE_RADIUS, companion_count, 0)
		local fully, flags = validate_layout_positions(ctx, hpos, comps)
		selected = {
			layout_type = "circle_r" .. tostring(CIRCLE_RADIUS),
			priority = 99,
			radius = CIRCLE_RADIUS,
			center = center,
			host = hpos,
			companions = comps,
			fully_valid = fully,
			flags = flags or {},
			score = 99999,
		}
		fallback_unsafe = true
	end

	local elapsed = nil
	if t0 and Isaac and Isaac.GetTime then
		elapsed = Isaac.GetTime() - t0
	end

	probe_note("LAYOUT_CANDIDATES", {
		candidate_count = evaluated,
		valid_candidate_count = valid_count,
		budget = LAYOUT_CANDIDATE_BUDGET,
		preferred_x = selected.preferred and selected.preferred.X or nil,
		preferred_y = selected.preferred and selected.preferred.Y or nil,
	})
	probe_note("LAYOUT_VALIDATION", {
		layout_type = selected.layout_type,
		fully_valid = selected.fully_valid == true,
		out_of_room = selected.flags.out_of_room,
		solid = selected.flags.solid,
		pit = selected.flags.pit,
		unreachable = selected.flags.unreachable,
		option_overlap = selected.flags.option_overlap,
		blocked_access = selected.flags.blocked_access,
		entity_hits = selected.flags.entity_hits,
		door_hits = selected.flags.door_hits,
		min_gap = selected.flags.min_gap,
	})
	probe_note("LAYOUT_SELECTED", {
		layout_type = selected.layout_type,
		radius = selected.radius,
		spacing = selected.spacing,
		center_x = selected.center.X,
		center_y = selected.center.Y,
		host_x = selected.host.X,
		host_y = selected.host.Y,
		dist_host_origin = host_pos:Distance(selected.host),
		score = selected.score,
		fully_valid = selected.fully_valid == true,
		fallback_unsafe = fallback_unsafe,
	})
	if fallback_unsafe then
		probe_note("LAYOUT_FALLBACK", {
			reason = "LAYOUT_NO_FULLY_VALID_CANDIDATE",
			layout_type = selected.layout_type,
			score = selected.score,
			out_of_room = selected.flags.out_of_room,
			solid = selected.flags.solid,
			pit = selected.flags.pit,
			unreachable = selected.flags.unreachable,
			option_overlap = selected.flags.option_overlap,
			blocked_access = selected.flags.blocked_access,
			FALLBACK_UNSAFE = true,
		})
		probe_note("LAYOUT_NO_FULLY_VALID_CANDIDATE", {
			layout_type = selected.layout_type,
			candidate_count = evaluated,
			valid_candidate_count = valid_count,
		})
	end
	probe_note("LAYOUT_PERFORMANCE", {
		elapsed_ms = elapsed,
		candidate_count = evaluated,
		valid_candidate_count = valid_count,
		blocker_count = #ctx.blockers,
		door_count = #ctx.doors,
		reachable_seed_count = #ctx.seed_indices,
	})
	-- Soft score probe kept for continuity with older reports.
	probe_note("LAYOUT_SCORE", {
		score = selected.score,
		layout_type = selected.layout_type,
		out_of_room = selected.flags.out_of_room,
		solid = selected.flags.solid,
		pit = selected.flags.pit,
		entity_hits = selected.flags.entity_hits,
		unreachable = selected.flags.unreachable,
		fully_valid = selected.fully_valid == true,
		fallback_unsafe = fallback_unsafe,
	})

	return {
		center = selected.center,
		host = selected.host,
		companions = selected.companions,
		radius = selected.radius,
		spacing = selected.spacing,
		layout_type = selected.layout_type,
		score = selected.score,
		fully_valid = selected.fully_valid == true,
		fallback_unsafe = fallback_unsafe,
		flags = selected.flags,
		host_origin = Vector(host_pos.X, host_pos.Y),
	}
end

local function party_contains_collectible(party, collectible_id)
	collectible_id = tonumber(collectible_id) or 0
	if not party or collectible_id <= 0 then return false end
	if tonumber(party.host_subtype) == collectible_id then return true end
	for _, row in ipairs(party.companions or {}) do
		if row and row.status ~= "exited" and tonumber(row.id) == collectible_id then
			return true
		end
	end
	return false
end

local function clear_host_options_if_alone(pickup)
	if not pickup then return end
	local idx = tonumber(pickup.OptionsPickupIndex) or 0
	if idx == 0 then return end
	local others = 0
	local list = auxi.getothers(nil, EntityType.ENTITY_PICKUP, PICKUP_COLLECTIBLE)
	for _, ent in ipairs(list) do
		local p = ent:ToPickup()
		if p and auxi.check_all_exists(p) and not auxi.check_for_the_same(p, pickup) then
			if (tonumber(p.OptionsPickupIndex) or 0) == idx then
				others = others + 1
			end
		end
	end
	if others == 0 then
		pickup.OptionsPickupIndex = 0
	end
end

local function rollback_partial_party(host, token, spawned_ents, gid_key, host_origin, cycle_snapshot)
	for i = 1, #spawned_ents do
		local ent = spawned_ents[i]
		if ent and auxi.check_all_exists(ent) then
			Isaac.Spawn(1000, 15, 0, ent.Position, Vector.Zero, nil)
			ent:Remove()
		end
	end
	local host_restored = false
	local cycle_restored = false
	if host and auxi.check_all_exists(host) then
		clear_party_mark(host)
		host.OptionsPickupIndex = 0
		if host_origin then
			host.Position = host_origin
			host.Velocity = Vector.Zero
			host.TargetPosition = Vector(host_origin.X, host_origin.Y)
			host_restored = true
		end
		if type(cycle_snapshot) == "table" and #cycle_snapshot > 0 then
			restore_collectible_cycle(host, cycle_snapshot)
			cycle_restored = true
		end
	end
	local root = state_root()
	if token and root.parties[token] then
		root.parties[token] = nil
	end
	if gid_key then
		root.expanded_gids[gid_key] = nil
	end
	if _test_members_override and _test_members_override.party_token == token then
		clear_test_members_override("partial_spawn_rollback")
	end
	probe_note("PARTY_ROLLBACK", {
		reason = "PARTIAL_SPAWN_ROLLBACK",
		token = token,
		spawned = #spawned_ents,
		host_restored = host_restored,
		cycle_restored = cycle_restored,
		cycle_size = type(cycle_snapshot) == "table" and #cycle_snapshot or 0,
		host_x = host_origin and host_origin.X or nil,
		host_y = host_origin and host_origin.Y or nil,
	})
	probe_note("PARTY_ABORT", {
		reason = "PARTIAL_SPAWN_ROLLBACK",
		token = token,
		spawned = #spawned_ents,
		cleaned = true,
		cycle_restored = cycle_restored,
	})
end

local function start_party(host)
	if not host then
		return false, "NIL_HOST"
	end
	if not any_holder() then
		return false, "NO_ISOLATION_HOLDER"
	end
	if not is_member(host.SubType) then
		return false, "NOT_CLIQUE_MEMBER"
	end
	local skip, reason = skip_party_scene(host)
	if skip then
		return false, reason or "SCENE_SKIP"
	end

	local gen = unique_holder.resolve_generation(host)
	local gid = gen and tonumber(gen.id)
	if not gid then
		return false, "NO_GENERATION_ID"
	end
	local root_mark = state_root()
	local gid_key = tostring(gid)
	if root_mark.expanded_gids[gid_key] then
		return false, "ALREADY_EXPANDED"
	end

	local members = item.ensure_clique()
	local companions_ids = {}
	for _, id in ipairs(members) do
		if id ~= host.SubType then
			companions_ids[#companions_ids + 1] = id
		end
	end
	local expected_companions = #companions_ids
	if expected_companions <= 0 then
		return false, "NO_COMPANIONS"
	end

	local layout = compute_party_layout(host, expected_companions)
	local host_origin = layout.host_origin
	local host_display_id = host.SubType
	local positions_probe = {
		{role = "host", x = layout.host.X, y = layout.host.Y},
	}
	for i = 1, #layout.companions do
		local p = layout.companions[i]
		positions_probe[#positions_probe + 1] = {
			role = "companion",
			index = i,
			x = p.X,
			y = p.Y,
		}
	end

	-- Snapshot Cycle before irreversible freeze; restore on spawn rollback.
	local cycle_snapshot = snapshot_collectible_cycle(host)
	local had_cycle = #cycle_snapshot > 0

	-- Move original Host onto the circle. Collectible pedestals also track
	-- TargetPosition (engine / other mods snap Position toward it) — set both.
	local function apply_host_pos(ent, pos)
		if not ent or not pos then return end
		ent.Position = pos
		ent.Velocity = Vector.Zero
		ent.TargetPosition = Vector(pos.X, pos.Y)
	end
	if had_cycle then
		freeze_host_cycle(host, host_display_id)
	end
	apply_host_pos(host, layout.host)
	local room_idx = nil
	pcall(function()
		local desc = Game():GetLevel():GetCurrentRoomDesc()
		room_idx = desc and desc.ListIndex
	end)
	probe_note("HOST_RELOCATED", {
		from_x = host_origin.X,
		from_y = host_origin.Y,
		to_x = layout.host.X,
		to_y = layout.host.Y,
		target_x = host.TargetPosition and host.TargetPosition.X or nil,
		target_y = host.TargetPosition and host.TargetPosition.Y or nil,
		host_gid = gid,
		room_list_index = room_idx,
		cycle_cleared = had_cycle,
		cycle_size = #cycle_snapshot,
	})

	root_mark.expanded_gids[gid_key] = true

	local root = state_root()
	local token = tostring(root.next_party or 1)
	root.next_party = (root.next_party or 1) + 1
	local option_index = option_index_holder.find_a_new_index()
	host.OptionsPickupIndex = option_index

	local party = {
		token = token,
		host_gid = gid,
		host_subtype = host_display_id,
		option_index = option_index,
		companions = {},
		status = "active",
		settled = false,
		dissolved = false,
		pending_settle = nil,
		cycle_cleared = had_cycle,
		cycle_snapshot = had_cycle and cycle_snapshot or nil,
		forced_test = _test_members_override ~= nil,
		layout = {
			layout_type = layout.layout_type or "circle_r64",
			center_x = layout.center.X,
			center_y = layout.center.Y,
			radius = layout.radius,
			spacing = layout.spacing,
			fully_valid = layout.fully_valid == true,
			fallback_unsafe = layout.fallback_unsafe == true,
			host_target_x = layout.host.X,
			host_target_y = layout.host.Y,
			companion_targets = (function()
				local rows = {}
				for i = 1, #layout.companions do
					local p = layout.companions[i]
					rows[i] = {x = p.X, y = p.Y}
				end
				return rows
			end)(),
			host_origin_x = host_origin.X,
			host_origin_y = host_origin.Y,
			room_list_index = room_idx,
		},
	}
	root.parties[token] = party
	if _test_members_override then
		_test_members_override.party_token = token
	end

	persist_party_mark(host, {
		token = token,
		role = "host",
		expected = host_display_id,
	})

	probe_note("PARTY_START", {
		token = token,
		host_subtype = host_display_id,
		host_gid = gid,
		option_index = option_index,
		expected_companions = expected_companions,
		radius = layout.radius,
		center_x = layout.center.X,
		center_y = layout.center.Y,
		cycle_cleared = had_cycle,
		cycle_size = #cycle_snapshot,
	})

	-- Shared trade condition for Host + all Companions (one deal opportunity).
	local host_trade = resolve_host_trade(host)
	party.host_trade = {
		has_price = host_trade.has_price == true,
		price = host_trade.price,
		was_shop_item = host_trade.was_shop_item == true,
		source = host_trade.source,
	}
	probe_note("PRICE_HOST", price_audit_fields(host, {
		token = token,
		role = "host",
		trade_has_price = host_trade.has_price == true,
		trade_price = host_trade.price,
		trade_was_shop = host_trade.was_shop_item == true,
		trade_source = host_trade.source,
	}))
	if host_trade.has_price == true and type(host_trade.price) == "number" then
		apply_party_trade(host, host_trade)
	end

	local spawned_ents = {}
	local spawn_fail = false
	_spawning_companions = true
	pedestal_encounter.with_suppressed_encounter(item.own_key, function()
		for i = 1, expected_companions do
			local id = companions_ids[i]
			local pos = layout.companions[i] or layout.host
			local spawned = Isaac.Spawn(
				EntityType.ENTITY_PICKUP,
				PICKUP_COLLECTIBLE,
				id,
				pos,
				Vector.Zero,
				nil
			)
			spawned = spawned and spawned:ToPickup()
			if not spawned then
				spawn_fail = true
				probe_note("COMPANION_SPAWN", {
					ok = false,
					index = i,
					target_id = id,
					x = pos.X,
					y = pos.Y,
					reason = "SPAWN_FAILED",
				})
				break
			end
			local gid_before = nil
			do
				local g0 = unique_holder.resolve_generation(spawned)
				gid_before = g0 and tonumber(g0.id)
			end
			auxi.self_morph(spawned, {
				EntityType.ENTITY_PICKUP,
				PICKUP_COLLECTIBLE,
				id,
			})
			pedestal_encounter.mark_suppressed(spawned, item.own_key)
			spawned.OptionsPickupIndex = option_index
			-- Inherit Host quote via lock_price — do not catch_price_over (independent reprice).
			local price_locked = apply_party_trade(spawned, host_trade)
			spawned.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
			spawned.Position = pos
			spawned.Velocity = Vector.Zero
			spawned.TargetPosition = Vector(pos.X, pos.Y)
			local cgen = unique_holder.resolve_generation(spawned)
			local cgid = cgen and tonumber(cgen.id)
			party.companions[#party.companions + 1] = {
				gid = cgid,
				id = id,
				status = "active",
				gid_pre_morph = gid_before,
			}
			persist_party_mark(spawned, {
				token = token,
				role = "companion",
				expected = id,
				index = #party.companions,
			})
			spawned_ents[#spawned_ents + 1] = spawned
			probe_note("COMPANION_SPAWN", {
				ok = true,
				index = #party.companions,
				target_id = id,
				actual_id = spawned.SubType,
				gid = cgid,
				gid_pre_morph = gid_before,
				gid_changed = gid_before ~= nil and cgid ~= nil and gid_before ~= cgid,
				x = spawned.Position.X,
				y = spawned.Position.Y,
				party_companion = true,
				price_locked = price_locked,
			})
			probe_note("PRICE_COMPANION", price_audit_fields(spawned, {
				token = token,
				role = "companion",
				index = #party.companions,
				price_locked = price_locked,
				expected_price = host_trade.price,
				expected_has_price = host_trade.has_price == true,
			}))
		end
	end)
	_spawning_companions = false

	if spawn_fail or #spawned_ents < expected_companions then
		rollback_partial_party(
			host,
			token,
			spawned_ents,
			gid_key,
			host_origin,
			had_cycle and cycle_snapshot or nil
		)
		return false, spawn_fail and "SPAWN_FAILED" or "PARTIAL_SPAWN_ROLLBACK"
	end

	-- Next stable frame: confirm Host + Companions still share the locked trade.
	delay_buffer.addeffe(function(params)
		if not g.is_gameplay_world_active() then return end
		local p = state_root().parties[params.token]
		if not party_is_open(p) then return end
		local trade = p.host_trade or {}
		local list = auxi.getothers(nil, EntityType.ENTITY_PICKUP, PICKUP_COLLECTIBLE)
		local rows = {}
		local mismatch = 0
		for _, ent in ipairs(list) do
			local pickup = ent:ToPickup()
			local info = pickup and (party_data(pickup) or restore_party_mark(pickup))
			if info and info.token == params.token then
				local row = price_audit_fields(pickup, {
					token = params.token,
					role = info.role,
					index = info.index,
				})
				rows[#rows + 1] = row
				if trade.has_price == true and type(trade.price) == "number" then
					if row.price ~= trade.price or row.quote_price ~= trade.price then
						mismatch = mismatch + 1
					end
				elseif trade.has_price ~= true then
					if (row.price or 0) ~= 0 and row.quote_has_price == true then
						mismatch = mismatch + 1
					end
				end
			end
		end
		probe_note("PRICE_AUDIT_STABLE", {
			token = params.token,
			delay = 1,
			mismatch = mismatch,
			expected_price = trade.price,
			expected_has_price = trade.has_price == true,
			rows = rows,
			ok = mismatch == 0,
		})
	end, {token = token}, 1)

	probe_note("PARTY_READY", {
		token = token,
		option_count = 1 + #spawned_ents,
		companions = #spawned_ents,
		reason = "SUCCESS",
		positions = positions_probe,
		layout_type = layout.layout_type,
		layout_fully_valid = layout.fully_valid == true,
		layout_fallback_unsafe = layout.fallback_unsafe == true,
		layout_radius = layout.radius,
		layout_spacing = layout.spacing,
		host_x = host.Position.X,
		host_y = host.Position.Y,
		host_target_x = host.TargetPosition and host.TargetPosition.X or nil,
		host_target_y = host.TargetPosition and host.TargetPosition.Y or nil,
		cycle_cleared = had_cycle,
		cycle_size = #cycle_snapshot,
		trade_has_price = host_trade.has_price == true,
		trade_price = host_trade.price,
		trade_source = host_trade.source,
	})

	-- Short position samples: detect same-room TargetPosition snap-back vs room restore drift.
	local sample_delays = {0, 1, 5}
	for i = 1, #sample_delays do
		local delay = sample_delays[i]
		delay_buffer.addeffe(function(params)
			if not g.is_gameplay_world_active() then return end
			local p = state_root().parties[params.token]
			if not party_is_open(p) then return end
			local list = auxi.getothers(nil, EntityType.ENTITY_PICKUP, PICKUP_COLLECTIBLE)
			local host_ent = nil
			for _, ent in ipairs(list) do
				local pickup = ent:ToPickup()
				local info = pickup and (party_data(pickup) or restore_party_mark(pickup))
				if info and info.token == params.token and info.role == "host" then
					host_ent = pickup
					break
				end
			end
			if not host_ent then
				probe_note("HOST_POSITION_SAMPLE", {
					token = params.token,
					delay = params.delay,
					missing = true,
				})
				return
			end
			local want = p.layout and Vector(p.layout.host_target_x, p.layout.host_target_y)
			local dist = want and host_ent.Position:Distance(want) or nil
			local tp = host_ent.TargetPosition
			probe_note("HOST_POSITION_SAMPLE", {
				token = params.token,
				delay = params.delay,
				x = host_ent.Position.X,
				y = host_ent.Position.Y,
				target_x = tp and tp.X or nil,
				target_y = tp and tp.Y or nil,
				want_x = want and want.X or nil,
				want_y = want and want.Y or nil,
				dist = dist,
				host_gid = p.host_gid,
				room_list_index = p.layout and p.layout.room_list_index,
			})
			if dist and dist > 8 then
				probe_note("HOST_POSITION_DRIFT", {
					token = params.token,
					delay = params.delay,
					x = host_ent.Position.X,
					y = host_ent.Position.Y,
					want_x = want.X,
					want_y = want.Y,
					dist = dist,
					target_x = tp and tp.X or nil,
					target_y = tp and tp.Y or nil,
					same_room = true,
				})
				-- One corrective write if TargetPosition drifted back to the old spawn.
				host_ent.Position = want
				host_ent.Velocity = Vector.Zero
				host_ent.TargetPosition = Vector(want.X, want.Y)
			end
		end, {token = token, delay = delay}, delay)
	end

	return true, "SUCCESS"
end

dissolve_party = function(token, keep_host)
	local root = state_root()
	local party = root.parties[token]
	if not party or party.settled or party.dissolved then return end
	local list = auxi.getothers(nil, EntityType.ENTITY_PICKUP, PICKUP_COLLECTIBLE)
	for _, ent in ipairs(list) do
		local pickup = ent:ToPickup()
		local info = party_data(pickup) or restore_party_mark(pickup)
		if info and info.token == token then
			if info.role == "companion" then
				if auxi.check_all_exists(pickup) then
					Isaac.Spawn(1000, 15, 0, pickup.Position, Vector.Zero, nil)
					pickup:Remove()
				end
			elseif info.role == "host" then
				clear_party_mark(pickup)
				if keep_host then
					clear_host_options_if_alone(pickup)
				end
			end
		end
	end
	party.companions = {}
	party.pending_settle = nil
	party.status = "dissolved"
	party.dissolved = true
	if party.forced_test
		or (_test_members_override and _test_members_override.party_token == token)
	then
		clear_test_members_override("party_dissolved")
	end
end

local function rebind_all_party_pickups_in_room()
	local list = auxi.getothers(nil, EntityType.ENTITY_PICKUP, PICKUP_COLLECTIBLE)
	for _, ent in ipairs(list) do
		local pickup = ent:ToPickup()
		if pickup and auxi.check_all_exists(pickup) then
			rebind_pickup_to_party(pickup)
		end
	end
end

--- After Consistance rematerialize window: if THIS room has party members but no host, dissolve.
--- Parties whose pedestals are not in the current room are left alone.
local function dissolve_parties_missing_host()
	local root = state_root()
	local list = auxi.getothers(nil, EntityType.ENTITY_PICKUP, PICKUP_COLLECTIBLE)
	local present = {}
	local host_seen = {}
	for _, ent in ipairs(list) do
		local pickup = ent:ToPickup()
		if pickup and auxi.check_all_exists(pickup) then
			local info = party_data(pickup) or restore_party_mark(pickup)
			if not info then
				info = rebind_pickup_to_party(pickup)
			end
			if info and info.token then
				present[info.token] = true
				if info.role == "host" then
					host_seen[info.token] = true
				end
			else
				local gen = unique_holder.resolve_generation(pickup)
				local gid = gen and tonumber(gen.id)
				if gid then
					local party, token, role = find_open_party_by_gid(gid)
					if party and token then
						present[token] = true
						rebind_pickup_to_party(pickup)
						if role == "host" then
							host_seen[token] = true
						end
					end
				end
			end
		end
	end
	for token, _ in pairs(present) do
		local party = root.parties[token]
		if party_is_open(party) and not host_seen[token] then
			dissolve_party(token, false)
		end
	end
end

local function mark_companion_exited(token, index)
	local party = state_root().parties[token]
	if not party or not party.companions then return end
	local row = party.companions[index]
	if row then
		row.status = "exited"
	end
end

local function note_party_pick(pickup, player)
	local info = party_data(pickup) or restore_party_mark(pickup)
	if not info then return false end
	local party = state_root().parties[info.token]
	if not party_is_open(party) then return false end
	local picked = is_option_picked(pickup)
	local sel = option_index_holder.peek_recent_selection
		and option_index_holder.peek_recent_selection(party.option_index)
	probe_note("OPTION_PICK", {
		token = info.token,
		role = info.role,
		pick_flag = picked == true,
		option_index = party.option_index,
		selection_id = sel and tonumber(sel.id) or nil,
		subtype = pickup.SubType,
	})
	if not picked then return false end
	local pkey = player_key(player)
	if not pkey then
		probe_note("SETTLE_REJECTED", {
			reason = "NO_PLAYER_INDEX",
			token = info.token,
			phase = "note_party_pick",
		})
		return false
	end
	local gen = unique_holder.resolve_generation(pickup)
	local winner_gid = gen and tonumber(gen.id)
	party.status = "selected"
	party.pending_settle = {
		option_index = party.option_index,
		collectible_id = tonumber(info.expected) or tonumber(pickup.SubType) or 0,
		frame = Game():GetFrameCount(),
		player_index = pkey,
		winner_gid = winner_gid,
		selection_id = sel and tonumber(sel.id) or nil,
		role = info.role,
		companion_index = info.index,
	}
	probe_note("SETTLE_PENDING", {
		token = info.token,
		player_index = pkey,
		winner_gid = winner_gid,
		collectible_id = party.pending_settle.collectible_id,
		option_index = party.option_index,
		selection_id = party.pending_settle.selection_id,
		role = info.role,
	})
	return true
end

local function settle_reject(reason, extra)
	local row = {reason = reason}
	if type(extra) == "table" then
		for k, v in pairs(extra) do
			row[k] = v
		end
	end
	probe_note("SETTLE_REJECTED", row)
	return false
end

local function settle_party(player, token, collectible_id, ent)
	if not player or not holds_isolation(player) then
		return settle_reject("NO_ISOLATION_HOLDER", {token = token, collectible_id = collectible_id})
	end
	local root = state_root()
	local party = root.parties[token]
	if not party_is_open(party) then
		return settle_reject("PARTY_CLOSED", {token = token, collectible_id = collectible_id})
	end
	collectible_id = tonumber(collectible_id) or 0
	if collectible_id <= 0 or not party_contains_collectible(party, collectible_id) then
		return settle_reject("NOT_PARTY_COLLECTIBLE", {token = token, collectible_id = collectible_id})
	end
	local pending = party.pending_settle
	if type(pending) ~= "table" then
		return settle_reject("NO_PENDING", {token = token, collectible_id = collectible_id})
	end
	local pkey = player_key(player)
	if not pkey or tostring(pending.player_index) ~= pkey then
		return settle_reject("PLAYER_MISMATCH", {
			token = token,
			pending_player = pending.player_index,
			actual_player = pkey,
			collectible_id = collectible_id,
		})
	end
	if tonumber(pending.option_index) ~= tonumber(party.option_index) then
		return settle_reject("OPTION_INDEX_MISMATCH", {
			token = token,
			pending_option = pending.option_index,
			party_option = party.option_index,
		})
	end
	if tonumber(pending.collectible_id) ~= collectible_id then
		return settle_reject("COLLECTIBLE_MISMATCH", {
			token = token,
			pending_id = pending.collectible_id,
			actual_id = collectible_id,
		})
	end
	local age = Game():GetFrameCount() - (tonumber(pending.frame) or 0)
	if age < 0 or age > SETTLE_PENDING_FRAMES then
		return settle_reject("PENDING_EXPIRED", {
			token = token,
			age = age,
			window = SETTLE_PENDING_FRAMES,
		})
	end
	if ent and auxi.check_all_exists(ent) then
		local gen = unique_holder.resolve_generation(ent)
		local gid = gen and tonumber(gen.id)
		if pending.winner_gid and gid and gid ~= tonumber(pending.winner_gid) then
			return settle_reject("WINNER_GID_MISMATCH", {
				token = token,
				pending_gid = pending.winner_gid,
				ent_gid = gid,
			})
		end
	end

	if not drop_rejected(player, collectible_id) then
		return settle_reject("DROP_FAILED", {token = token, collectible_id = collectible_id})
	end
	party.settled = true
	party.status = "settled"
	party.pending_settle = nil
	probe_note("PARTY_SETTLED", {
		token = token,
		collectible_id = collectible_id,
		rejected_by = collectible_id,
		player_index = pkey,
		forced_test = party.forced_test == true,
	})
	if party.forced_test
		or (_test_members_override and _test_members_override.party_token == token)
	then
		clear_test_members_override("party_settled")
	end
	return true
end

-- Queue-stage settle: use POST_PICKUP source_context only.
-- Do NOT call resolve_gain_context here — that consumes the acquisition txn before Gain.
local function try_settle_from_collect(player, collectible_id, ent, source_context)
	collectible_id = tonumber(collectible_id) or 0
	if not player or collectible_id <= 0 then return false end

	local pkey = player_key(player)
	local info = ent and (party_data(ent) or restore_party_mark(ent))
	local root = state_root()
	local has_pending_for_player = false
	if pkey then
		for _, party in pairs(root.parties or {}) do
			local pending = party and party.pending_settle
			if party_is_open(party)
				and type(pending) == "table"
				and tostring(pending.player_index) == pkey
			then
				has_pending_for_player = true
				break
			end
		end
	end
	-- Ignore unrelated collectible gains; only diagnose party settle path.
	if not (info and info.token) and not has_pending_for_player then
		return false
	end

	local source = type(source_context) == "table" and source_context.source or nil
	if not source and type(source_context) == "table" and collectible_holder.get_acquisition_source then
		source = collectible_holder.get_acquisition_source(source_context)
	end
	local gain_gid = source and tonumber(source.generation_id) or nil
	local live_from_ctx = type(source_context) == "table" and source_context.pedestal or nil
	probe_note("COLLECT_CALLBACK", {
		collectible_id = collectible_id,
		player_index = pkey,
		has_ent = ent ~= nil,
		ent_token = info and info.token or nil,
		acquisition_gid = gain_gid,
		holds_isolation = holds_isolation(player) == true,
		is_member = is_member(collectible_id) == true,
	})

	if not holds_isolation(player) then
		return settle_reject("NO_ISOLATION_HOLDER", {
			phase = "collect",
			collectible_id = collectible_id,
		})
	end
	if not is_member(collectible_id) then
		return settle_reject("NOT_CLIQUE_MEMBER", {
			phase = "collect",
			collectible_id = collectible_id,
		})
	end
	if not pkey then
		return settle_reject("NO_PLAYER_INDEX", {phase = "collect", collectible_id = collectible_id})
	end

	if info and info.token then
		return settle_party(player, info.token, collectible_id, ent)
	end

	local matched_pending = false
	for token, party in pairs(root.parties or {}) do
		local pending = party and party.pending_settle
		if party_is_open(party)
			and type(pending) == "table"
			and tostring(pending.player_index) == pkey
			and tonumber(pending.collectible_id) == collectible_id
		then
			matched_pending = true
			if gain_gid and pending.winner_gid and gain_gid ~= tonumber(pending.winner_gid) then
				settle_reject("WINNER_GID_MISMATCH", {
					phase = "collect_scan",
					token = token,
					pending_gid = pending.winner_gid,
					acquisition_gid = gain_gid,
				})
				goto continue_party
			end
			local live_pedestal = live_from_ctx
			if not live_pedestal and collectible_holder.get_live_source_pedestal and type(source_context) == "table" then
				live_pedestal = collectible_holder.get_live_source_pedestal(source_context)
			end
			if live_pedestal then
				local ginfo = party_data(live_pedestal) or restore_party_mark(live_pedestal)
				if ginfo and ginfo.token and ginfo.token ~= token then
					settle_reject("PEDESTAL_TOKEN_MISMATCH", {
						phase = "collect_scan",
						token = token,
						gain_token = ginfo.token,
					})
					goto continue_party
				end
			end
			if settle_party(player, token, collectible_id, ent or live_pedestal) then
				return true
			end
		end
		::continue_party::
	end
	if not matched_pending then
		return settle_reject("NO_PENDING", {
			phase = "collect",
			collectible_id = collectible_id,
			player_index = pkey,
			has_acquisition = gain ~= nil,
			acquisition_gid = gain_gid,
		})
	end
	return false
end

local function remove_companion_once(pickup, token, index)
	if not pickup then return false end
	local hash = GetPtrHash(pickup)
	if _companion_exit_done[hash] then return false end
	_companion_exit_done[hash] = true
	_companion_exit_pending[hash] = nil
	if pickup.GetData then
		pickup:GetData()[item.own_key .. "exit_pending"] = nil
	end
	mark_companion_exited(token, index)
	if auxi.check_all_exists(pickup) then
		Isaac.Spawn(1000, 15, 0, pickup.Position, Vector.Zero, nil)
		pickup:Remove()
	end
	return true
end

local function schedule_companion_exit(pickup, token, index)
	if not pickup then return end
	local hash = GetPtrHash(pickup)
	if _companion_exit_done[hash] or _companion_exit_pending[hash] then return end
	_companion_exit_pending[hash] = {
		token = token,
		index = index,
		frame = Game():GetFrameCount(),
	}
	local d = pickup:GetData()
	d[item.own_key .. "exit_pending"] = true
	-- Own delay flush — do not depend solely on a later Pickup Update.
	delay_buffer.addeffe(function(params)
		local ent = params and params.ent
		if not ent or not auxi.check_all_exists(ent) then return end
		local pending = _companion_exit_pending[GetPtrHash(ent)]
		local info = party_data(ent)
		local t = (pending and pending.token) or (info and info.token) or params.token
		local idx = (pending and pending.index) or (info and info.index) or params.index
		if t then
			remove_companion_once(ent, t, idx)
		end
	end, {ent = pickup, token = token, index = index}, 1)
end

local function flush_companion_exits()
	if not next(_companion_exit_pending) then return end
	local list = auxi.getothers(nil, EntityType.ENTITY_PICKUP, PICKUP_COLLECTIBLE)
	for _, ent in ipairs(list) do
		local pickup = ent:ToPickup()
		if pickup and auxi.check_all_exists(pickup) then
			local hash = GetPtrHash(pickup)
			local pending = _companion_exit_pending[hash]
			local d = pickup:GetData()
			if pending or d[item.own_key .. "exit_pending"] then
				pending = pending or {}
				local info = party_data(pickup)
				local token = pending.token or (info and info.token)
				local index = pending.index or (info and info.index)
				if token then
					remove_companion_once(pickup, token, index)
				end
			end
		end
	end
end

local function holder_snapshot()
	local holders = 0
	local copies = 0
	for i = 0, Game():GetNumPlayers() - 1 do
		local p = Game():GetPlayer(i)
		local n = p and p:GetCollectibleNum(item.entity) or 0
		if n > 0 then
			holders = holders + 1
			copies = copies + n
		end
	end
	return holders, copies
end

local function try_expand_from_encounter(pickup, encounter)
	if _spawning_companions then return end
	if not pickup or pickup.Variant ~= PICKUP_COLLECTIBLE then return end

	local gen = unique_holder.resolve_generation(pickup)
	local gid = gen and tonumber(gen.id)
	local holders, copies = holder_snapshot()
	local is_shop = pickup.IsShopItem and pickup:IsShopItem() == true or false
	probe_note("ISOLATION_RECEIVED", {
		subtype = pickup.SubType,
		generation_id = gid,
		holders = holders,
		copies = copies,
		encounter_serial = encounter and encounter.serial or nil,
		is_shop = is_shop,
	})

	if party_data(pickup) or restore_party_mark(pickup) then
		probe_note("PARTY_ABORT", {reason = "ALREADY_PARTY_MARK", generation_id = gid})
		return
	end
	if rebind_pickup_to_party(pickup) then
		probe_note("PARTY_ABORT", {reason = "REBOUND_EXISTING", generation_id = gid})
		return
	end

	if holders <= 0 then
		probe_note("PARTY_ABORT", {reason = "NO_ISOLATION_HOLDER", subtype = pickup.SubType})
		return
	end

	-- Clique must exist before membership checks (and before force override build).
	item.ensure_clique()
	local was_member_before_force = is_member(pickup.SubType)
	local forced_this = false
	if _force_next_encounter_armed then
		_force_next_encounter_armed = false
		local built, build_err = build_force_members_for_host(pickup.SubType)
		if not built then
			probe_note("FORCED_ENCOUNTER_AUDIT", {
				ok = false,
				phase = "build_override",
				reason = build_err or "BUILD_FAILED",
				subtype = pickup.SubType,
				generation_id = gid,
				is_shop = is_shop,
				was_member = was_member_before_force,
			})
		else
			_test_members_override = built
			forced_this = true
			probe_note("FORCED_ENCOUNTER_AUDIT", {
				ok = true,
				phase = "override_installed",
				subtype = pickup.SubType,
				generation_id = gid,
				is_fresh = unique_holder.is_fresh_generation
					and unique_holder.is_fresh_generation(pickup) == true,
				is_shop = is_shop,
				options_index = pickup.OptionsPickupIndex,
				was_member = was_member_before_force,
				already_member = built.already_member == true,
				replaced_index = built.replaced_index,
				original_members = built.original,
				temp_members = built.members,
			})
		end
	end

	local member = is_member(pickup.SubType)
	probe_note("MEMBER_CHECK", {
		subtype = pickup.SubType,
		is_member = member == true,
		forced = forced_this,
		was_member_before_force = was_member_before_force,
	})
	if not member then
		if forced_this then
			clear_test_members_override("force_still_not_member")
		end
		probe_note("PARTY_ABORT", {reason = "NOT_CLIQUE_MEMBER", subtype = pickup.SubType})
		return
	end

	local skip, skip_reason = skip_party_scene(pickup)
	probe_note("SCENE_CHECK", {
		skip = skip == true,
		reason = skip_reason,
		is_shop = is_shop,
	})
	if skip then
		if forced_this then
			clear_test_members_override("force_scene_skip")
			probe_note("FORCED_ENCOUNTER_AUDIT", {
				ok = false,
				phase = "scene_check",
				reason = skip_reason or "SCENE_SKIP",
				subtype = pickup.SubType,
				generation_id = gid,
				is_shop = is_shop,
			})
		end
		probe_note("PARTY_ABORT", {reason = skip_reason or "SCENE_SKIP", subtype = pickup.SubType})
		return
	end

	local ok, result = start_party(pickup)
	if not ok then
		if forced_this then
			clear_test_members_override("force_start_party_failed")
			probe_note("FORCED_ENCOUNTER_AUDIT", {
				ok = false,
				phase = "start_party",
				reason = result or "UNKNOWN",
				subtype = pickup.SubType,
				generation_id = gid,
				is_shop = is_shop,
			})
		end
		probe_note("PARTY_ABORT", {
			reason = result or "UNKNOWN",
			subtype = pickup.SubType,
			generation_id = gid,
			expand_reason = "encounter",
			forced = forced_this,
		})
	elseif forced_this then
		local host_trade = resolve_host_trade(pickup)
		probe_note("FORCED_ENCOUNTER_AUDIT", {
			ok = true,
			phase = "party_started",
			subtype = pickup.SubType,
			generation_id = gid,
			is_shop = is_shop,
			party_token = _test_members_override and _test_members_override.party_token,
			option_index = pickup.OptionsPickupIndex,
			trade_has_price = host_trade.has_price == true,
			trade_price = host_trade.price,
			trade_was_shop = host_trade.was_shop_item == true,
			temp_members = _test_members_override and _test_members_override.members,
			original_members = _test_members_override and _test_members_override.original,
		})
	end
end

--- Cycle may show a clique member after the initial Encounter frame.
--- Track display subtypes per pedestal; expand only when a member appears.
--- Do not treat every Cycle tick as a fresh pedestal generation.
local function try_expand_from_cycle_display(pickup)
	if _spawning_companions then return end
	if not pickup or pickup.Variant ~= PICKUP_COLLECTIBLE then return end
	if not pickup.GetCollectibleCycle then return end
	local ok, cycle = pcall(function()
		return pickup:GetCollectibleCycle()
	end)
	if not ok or type(cycle) ~= "table" or #cycle == 0 then return end
	if party_data(pickup) or restore_party_mark(pickup) then return end

	local d = pickup:GetData()
	local seen_key = item.own_key .. "cycle_seen"
	d[seen_key] = d[seen_key] or {}
	local seen = d[seen_key]
	local st = pickup.SubType
	if seen[st] then return end
	seen[st] = true

	item.ensure_clique()
	if not is_member(st) then
		probe_note("CYCLE_DISPLAY", {
			subtype = st,
			is_member = false,
			cycle_size = #cycle,
		})
		return
	end

	local holders = select(1, holder_snapshot())
	probe_note("CYCLE_DISPLAY", {
		subtype = st,
		is_member = true,
		cycle_size = #cycle,
		holders = holders,
	})
	if holders <= 0 then return end

	local gen = unique_holder.resolve_generation(pickup)
	local gid = gen and tonumber(gen.id)
	local ok_party, result = start_party(pickup)
	if not ok_party then
		-- Only recoverable spawn/transaction failures may retry the same Cycle display.
		-- Fixed scene filters (EXISTING_OPTIONS / DC / SUPPRESSED / ALREADY_*) stay marked.
		local recoverable = result == "SPAWN_FAILED" or result == "PARTIAL_SPAWN_ROLLBACK"
		if recoverable then
			seen[st] = nil
		end
		probe_note("PARTY_ABORT", {
			reason = result or "UNKNOWN",
			subtype = st,
			generation_id = gid,
			expand_reason = "cycle_display",
			retry_allowed = recoverable,
		})
	end
end

-- ---- Callbacks ----

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_GAME_STARTED,
	params = nil,
	Function = function(_, is_continued)
		touch_cd = {}
		_force_next_encounter_armed = false
		_test_members_override = nil
		if is_continued then
			-- Continue restores save.elses members; do not redraw.
			return
		end
		save.elses[item.own_key .. "run"] = nil
		item.generate_clique()
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_PEDESTAL_ENCOUNTER,
	params = nil,
	Function = function(_, encounter)
		if encounter and encounter.pickup then
			try_expand_from_encounter(encounter.pickup, encounter)
		end
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_PICKUP_COLLECTIBLE,
	params = nil,
	Function = function(_, player, id, _touched, ent, source_context)
		-- Prefer live confirmed pedestal from source_context when available.
		local live = type(source_context) == "table" and source_context.pedestal or nil
		try_settle_from_collect(player, id, live or ent, source_context)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE,
	params = PICKUP_COLLECTIBLE,
	Function = function(_, pickup)
		if pickup.SubType == item.entity then
			rejected_data(pickup)
		end
		flush_companion_exits()
		try_expand_from_cycle_display(pickup)

		local info = rebind_pickup_to_party(pickup) or party_data(pickup)
		if not info then return end
		local token = info.token
		local root = state_root()
		local party = root.parties[token]
		if not party_is_open(party) then return end

		if is_option_picked(pickup) then
			-- Player may not be known on Update; collision path is primary for player bind.
			return
		end

		if info.role == "host" then
			if is_option_pending_remove(pickup) then
				local rejected = option_index_holder.was_rejected_by_selection
					and option_index_holder.was_rejected_by_selection(pickup) == true
				if rejected then
					return
				end
				dissolve_party(token, false)
				return
			end
			if pickup.SubType ~= info.expected then
				dissolve_party(token, true)
				return
			end
			return
		end

		if info.role == "companion" then
			if is_option_pending_remove(pickup) then
				local rejected = option_index_holder.was_rejected_by_selection
					and option_index_holder.was_rejected_by_selection(pickup) == true
				if rejected then
					mark_companion_exited(token, info.index)
					return
				end
				mark_companion_exited(token, info.index)
				clear_party_mark(pickup)
				return
			end
			if pickup.SubType ~= info.expected then
				-- Morph already applied: remove_companion_once is idempotent with morph_txn.
				schedule_companion_exit(pickup, token, info.index)
			end
		end
	end,
})

-- Cancel companion Morph so a new keepable collectible is never produced.
-- Actual Remove is owned by delay_buffer flush / morph_txn (idempotent).
if ModCallbacks.MC_PRE_PICKUP_MORPH then
	table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
		CallBack = ModCallbacks.MC_PRE_PICKUP_MORPH,
		params = nil,
		priority = -40,
		Function = function(_, pickup, _t, _v, _s, _kp, _ks, _im)
			local info = party_data(pickup) or restore_party_mark(pickup)
			if not info or info.role ~= "companion" then
				return
			end
			if is_option_picked(pickup) or is_option_pending_remove(pickup) then
				return
			end
			schedule_companion_exit(pickup, info.token, info.index)
			return false
		end,
	})
end

-- Must run AFTER Option_Index_holder.commit_selection (default priority 0).
-- CallbackPriority: lower runs earlier; -50 was before Pick was set → NO_PENDING.
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION,
	params = PICKUP_COLLECTIBLE,
	priority = 50,
	Function = function(_, pickup, collider)
		local player = collider and collider.ToPlayer and collider:ToPlayer()
		if not player or not pickup then return end
		local info = party_data(pickup) or restore_party_mark(pickup)
		if not info then return end
		local will = auxi.will_collect_pickup and auxi.will_collect_pickup(player, pickup) == true
		probe_note("PARTY_COLLISION", {
			token = info.token,
			role = info.role,
			subtype = pickup.SubType,
			player_index = player_key(player),
			holds_isolation = holds_isolation(player) == true,
			will_collect = will,
			pick_flag = is_option_picked(pickup) == true,
			option_index = pickup.OptionsPickupIndex,
		})
		if not holds_isolation(player) then return end
		if not will then return end
		note_party_pick(pickup, player)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_PICKUP_COLLISION,
	params = PICKUP_COLLECTIBLE,
	priority = -150,
	Function = function(_, pickup, collider)
		if not pickup or pickup.SubType ~= item.entity or not rejected_data(pickup) then
			return
		end
		local player = collider and collider.ToPlayer and collider:ToPlayer()
		if not player then return end
		-- Keep intercepting acquire (true); only ensure contact + refuse feedback.
		pickup.EntityCollisionClass = EntityCollisionClass.ENTCOLL_PLAYERONLY
		local hash = GetPtrHash(pickup)
		local now = Game():GetFrameCount()
		local last = touch_cd[hash]
		if last == nil or now - last >= TOUCH_COOLDOWN then
			touch_cd[hash] = now
			local step = touch_step[hash] or 0
			touch_step[hash] = 1 - step
			say_refuse(pickup.Position, step == 0 and "coward" or "refuse")
		end
		return true
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function()
		advance_refuse_speech()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_RENDER,
	params = nil,
	Function = function()
		draw_refuse_speech()
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function()
		touch_cd = {}
		touch_step = {}
		clear_refuse_speech()
		_companion_exit_pending = {}
		_companion_exit_done = {}
		_room_epoch = _room_epoch + 1
		-- Rebind early; dissolve host-missing only after Consistance rematerialize window.
		if not _room_rebind_scheduled then
			_room_rebind_scheduled = true
			local epoch = _room_epoch
			delay_buffer.addeffe(function()
				if epoch ~= _room_epoch then return end
				rebind_all_party_pickups_in_room()
			end, {}, 1)
			delay_buffer.addeffe(function()
				_room_rebind_scheduled = false
				if epoch ~= _room_epoch then return end
				dissolve_parties_missing_host()
			end, {}, 3)
		end
	end,
})

-- Host hard-removed in the same room (not room unload): dissolve after one tick if still missing.
table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_ENTITY_REMOVE,
	params = EntityType.ENTITY_PICKUP,
	Function = function(_, ent)
		if not g.is_gameplay_world_active() then return end
		if not ent or ent.Variant ~= PICKUP_COLLECTIBLE then return end
		local info = party_data(ent)
		if not info or info.role ~= "host" or not info.token then return end
		local party = state_root().parties[info.token]
		if not party_is_open(party) then return end
		if party.pending_settle then
			-- Selection already recorded; Options/collect path owns settle.
			return
		end
		local token = info.token
		local epoch = _room_epoch
		delay_buffer.addeffe(function(params)
			if not g.is_gameplay_world_active() then return end
			if params.epoch ~= _room_epoch then return end -- room changed: restore/rebind owns lifecycle
			local p = state_root().parties[params.token]
			if not party_is_open(p) or p.pending_settle then return end
			local list = auxi.getothers(nil, EntityType.ENTITY_PICKUP, PICKUP_COLLECTIBLE)
			for _, other in ipairs(list) do
				local pickup = other:ToPickup()
				if pickup and auxi.check_all_exists(pickup) then
					local i = party_data(pickup) or restore_party_mark(pickup)
					if i and i.token == params.token and i.role == "host" then
						return
					end
					local gen = unique_holder.resolve_generation(pickup)
					if gen and tonumber(gen.id) == tonumber(p.host_gid) then
						rebind_pickup_to_party(pickup)
						return
					end
				end
			end
			dissolve_party(params.token, false)
		end, {token = token, epoch = epoch}, 1)
	end,
})

morph_txn.register(item.own_key .. "reject", {
	match_pre = function(pickup)
		return pickup
			and pickup.Type == EntityType.ENTITY_PICKUP
			and pickup.Variant == PICKUP_COLLECTIBLE
			and pickup.SubType == item.entity
			and rejected_data(pickup) ~= nil
	end,
	capture = function(pickup)
		local bag = rejected_data(pickup)
		if not bag then return nil end
		return {
			rejected = true,
			rejected_by = tonumber(bag.rejected_by),
			x = pickup.Position.X,
			y = pickup.Position.Y,
		}
	end,
	on_post = function(_txn)
	end,
})

-- Companion Morph that still applies: single remove path via remove_companion_once.
morph_txn.register(item.own_key .. "companion", {
	priority = 20,
	match_pre = function(pickup)
		local info = party_data(pickup) or restore_party_mark(pickup)
		return info and info.role == "companion"
	end,
	capture = function(pickup)
		local info = party_data(pickup) or restore_party_mark(pickup)
		if not info then return nil end
		if is_option_picked(pickup) or is_option_pending_remove(pickup) then
			return nil
		end
		return {
			token = info.token,
			index = info.index,
			expected = info.expected,
			cleaned = false,
		}
	end,
	on_post = function(txn)
		local snap = txn and txn.source_snapshot
		if not snap or snap.cleaned then return end
		local after = txn.after or {}
		local subtype = tonumber(after.subtype) or 0
		if subtype == tonumber(snap.expected) then
			return
		end
		snap.cleaned = true
		local target = txn.target
		if target then
			remove_companion_once(target, snap.token, snap.index)
		else
			mark_companion_exited(snap.token, snap.index)
		end
	end,
})

-- ---- EID: rejected pedestal vs normal clique list ----
local function eid_rejected_bag(desc)
	if not desc or desc.ObjType ~= 5 or desc.ObjVariant ~= 100 then
		return nil
	end
	if desc.ObjSubType ~= item.entity then
		return nil
	end
	local ent = desc.Entity
	if not ent or not auxi.check_all_exists(ent) then
		return nil
	end
	if ent.Type ~= EntityType.ENTITY_PICKUP or ent.Variant ~= PICKUP_COLLECTIBLE then
		return nil
	end
	if ent.SubType ~= item.entity then
		return nil
	end
	local pickup = ent:ToPickup()
	if not pickup then
		return nil
	end
	return rejected_data(pickup)
end

local function eid_reject_description(bag)
	local lang = Options and Options.Language or "en"
	local by = bag and tonumber(bag.rejected_by)
	if by and by > 0 then
		if lang == "en" then
			return "#Rejected by you and {{Collectible" .. tostring(by) .. "}}"
		end
		return "#已被你和{{Collectible" .. tostring(by) .. "}}联合孤立"
	end
	-- Legacy rejected bags without rejected_by: never invent an icon.
	if lang == "en" then
		return "#Rejected by you and another collectible"
	end
	return "#已被你和其他道具联合孤立"
end

function item.register_eid()
	if item._eid or not EID or not EID.addDescriptionModifier then return end
	item._eid = true

	-- Rejected Isolation pedestal: replace mechanism text; keep Name.
	-- Judgment is per-pedestal Consistance bag only (never backpack Isolation).
	EID:addDescriptionModifier("qing_isolation_rejected", function(desc)
		return eid_rejected_bag(desc) ~= nil
	end, function(desc)
		local bag = eid_rejected_bag(desc)
		if not bag then
			return desc
		end
		desc.Description = eid_reject_description(bag)
		return desc
	end)

	EID:addDescriptionModifier("qing_isolation_members", function(desc)
		if not desc or desc.ObjType ~= 5 or desc.ObjVariant ~= 100 then return false end
		if desc.ObjSubType ~= item.entity then return false end
		-- Rejected pedestals must not append the clique list.
		if eid_rejected_bag(desc) then return false end
		local members = item.get_members()
		return members and #members > 0
	end, function(desc)
		if eid_rejected_bag(desc) then
			return desc
		end
		local members = item.get_members()
		if not members or #members == 0 then return desc end
		local lang = Options and Options.Language or "en"
		local title = (lang == "en") and "#Clique excluding Isolation:#" or "#排挤孤立的道具：#"
		local icons = {}
		for i = 1, #members do
			icons[#icons + 1] = "{{Collectible" .. tostring(members[i]) .. "}}"
		end
		EID:appendToDescription(desc, title .. table.concat(icons, " "))
		return desc
	end)
end

item.register_eid()

-- ---- Debug ----
function item.debug_member_report()
	item.ensure_clique()
	local root = state_root()
	local lines = {
		string.format("generated=%s count=%d", tostring(root.generated), #(root.members or {})),
	}
	for i, id in ipairs(root.members or {}) do
		local cfg = collectible_cfg(id)
		local ok, reason = item.is_clique_candidate(id)
		lines[#lines + 1] = string.format(
			"%02d id=%d q=%s name=%s ok=%s reason=%s",
			i,
			id,
			tostring(cfg and cfg.Quality),
			tostring(cfg and cfg.Name),
			tostring(ok),
			tostring(reason)
		)
	end
	local qcount = {[0]=0,[1]=0,[2]=0,[3]=0,[4]=0}
	for _, id in ipairs(root.members or {}) do
		local cfg = collectible_cfg(id)
		local q = tonumber(cfg and cfg.Quality) or 0
		qcount[q] = (qcount[q] or 0) + 1
	end
	lines[#lines + 1] = string.format(
		"quality hist: 0=%d 1=%d 2=%d 3=%d 4=%d",
		qcount[0], qcount[1], qcount[2], qcount[3], qcount[4]
	)
	_last_debug_report = table.concat(lines, "\n")
	Isaac.DebugString("[Isolation]\n" .. _last_debug_report)
	return _last_debug_report
end

function item.debug_simulate_draws(n)
	n = math.max(1, math.min(5000, tonumber(n) or 1000))
	local hist = {[0]=0,[1]=0,[2]=0,[3]=0,[4]=0}
	local q4_parties = 0
	local undersized = 0
	-- Isolated RNG: do not advance the real Isolation collectible stream.
	local rng = RNG()
	local seed = Game():GetSeeds():GetStartSeed()
	rng:SetSeed((seed % 2147483646) + 1, 17)
	for _ = 1, n do
		local by_q = build_candidates()
		local picked_set = {}
		local q4 = 0
		local count = 0
		for __ = 1, MEMBER_COUNT do
			local entries = {}
			for q = 0, 4 do
				if q == 4 and q4 >= 1 then goto cont end
				local bucket = by_q[q]
				local available = 0
				for i = 1, #bucket do
					if not picked_set[bucket[i]] then available = available + 1 end
				end
				if available > 0 then
					entries[#entries + 1] = {q = q, w = (QUALITY_WEIGHT[q] or 0) * available, bucket = bucket}
				end
				::cont::
			end
			if #entries == 0 then break end
			local choice = weighted_pick(rng, entries)
			local pool = {}
			for i = 1, #choice.bucket do
				if not picked_set[choice.bucket[i]] then
					pool[#pool + 1] = choice.bucket[i]
				end
			end
			if #pool == 0 then break end
			local id = pool[rng:RandomInt(#pool) + 1]
			picked_set[id] = true
			count = count + 1
			hist[choice.q] = hist[choice.q] + 1
			if choice.q == 4 then q4 = q4 + 1 end
		end
		if count < MEMBER_COUNT then undersized = undersized + 1 end
		if q4 > 0 then q4_parties = q4_parties + 1 end
	end
	local report = string.format(
		"draws=%d items=%d q0=%d q1=%d q2=%d q3=%d q4=%d parties_with_q4=%d undersized=%d",
		n, n * MEMBER_COUNT, hist[0], hist[1], hist[2], hist[3], hist[4], q4_parties, undersized
	)
	_last_debug_report = report
	Isaac.DebugString("[Isolation] " .. report)
	return report
end

function item.debug_get_last_report()
	return _last_debug_report or ""
end

function item.debug_force_regenerate()
	local root = state_root()
	for token, party in pairs(root.parties or {}) do
		if party_is_open(party) then
			_last_debug_report = "blocked: active party " .. tostring(token)
			Isaac.DebugString("[Isolation] " .. _last_debug_report)
			return _last_debug_report
		end
	end
	item.generate_clique({force = true})
	return item.debug_member_report()
end

function item.debug_has_active_party()
	local root = state_root()
	for _, party in pairs(root.parties or {}) do
		if party_is_open(party) then
			return true
		end
	end
	return false
end

return item
