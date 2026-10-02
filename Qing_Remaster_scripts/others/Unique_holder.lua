local save = require("Qing_Remaster_scripts.core.savedata")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local consistance_holder = require("Qing_Remaster_scripts.others.Consistance_holder")
local lifetime = require("Qing_Remaster_scripts.others.Entity_lifetime_holder")

-- Generation marker（业务 pedestal generation，≠ ESSM token）
local GEN_KEY = "_QingUniqueGeneration"
local STAMP_KEY = "_QingUniqueEssmStamp" -- shadow 兼容
local GEN_NEXT_KEY = "UniqueGenerationNext"
-- ESSM 独立 namespace（≠ QingEntityLifetime.token）
local ESSM_GEN_NS = "QingUniqueGeneration"

local item = {
	ToCall = {},
	myToCall = {},
	pre_ToCall = {},
	own_key = "Uni_h_",
	signal_hash_table = {},
	_restore_registry = {},
	_restore_registry_meta = nil,
	_morph_before = {}, -- ptr -> { seed, subtype, gen_id, birth_room_epoch }
	_morph_handled_frame = {}, -- ptr -> game frame
	_room_generation_epoch = 0, -- room appearance counter（非 ESSM 持久化）
	debug = {
		shadow_enabled = false,
		force_legacy_backend = false,
		backend = "unset",
		match_new = 0,
		match_old = 0,
		legacy_new_essm_old = 0,
		legacy_old_essm_new = 0,
		essm_error = 0,
		morph_reinit_events = 0,
		cycle_reinit_events = 0,
		known_legacy_noise = 0,
		registry_restored = 0,
		live_essm_restored = 0,
		new_midroom = 0,
		new_first_visit = 0,
		gen_new = 0,
		gen_same = 0,
		gen_restored = 0,
		gen_empty = 0,
		legacy_fallback = 0,
		unresolved = 0,
		early_create_blocked = 0,
		restore_registry_miss = 0,
		essm_api_error = 0,
		generation_persist_write = 0,
		generation_persist_read = 0,
		generation_restore_with_id = 0,
		generation_restore_missing_id = 0,
		generation_persistence_mismatch = 0,
		-- resolve_generation diagnostics（consumer 不得读这些做分支）
		resolve_runtime_hit = 0,
		resolve_registry_hit = 0,
		resolve_essm_hit = 0,
		resolve_morph_hit = 0,
		resolve_classify_hit = 0,
		resolve_unresolved = 0,
		resolve_conflict = 0,
		last = nil,
		last_classify = nil,
		last_generation = nil,
		last_native = nil,
		last_resolve = nil,
	},
}

function item.quest_signal_hash(key)
	return item.signal_hash_table[key]
end

function item.signal_hash(key, val)
	item.signal_hash_table[key] = val
end

local function ptr_key(ent)
	if not ent then return nil end
	local ok, h = pcall(GetPtrHash, ent)
	if ok then return tostring(h) end
	return nil
end

local function game_frame()
	local f = 0
	pcall(function()
		f = Game():GetFrameCount()
	end)
	return f
end

local function bump(counter)
	item.debug[counter] = (item.debug[counter] or 0) + 1
end

-- 前向声明：apply_unique_generation 在 GEN_UNKNOWN 时调用
local apply_legacy_unique_init

local function alloc_generation_id()
	save.elses = save.elses or {}
	local n = tonumber(save.elses[GEN_NEXT_KEY]) or 0
	n = n + 1
	save.elses[GEN_NEXT_KEY] = n
	return n
end

--- GEN_NEW：写 ESSM QingUniqueGeneration.id（仅已 classify 为 NEW 后调用；会 GetEntityData）。
local function persist_generation_write(ent, id)
	if not item.is_essm_backend() or not ent or id == nil then return false end
	local ns = select(1, lifetime.ensure_namespace(ent, ESSM_GEN_NS))
	if type(ns) ~= "table" then return false end
	ns.id = id
	bump("generation_persist_write")
	return true
end

--- GEN_SAME：确保 ESSM 仍是该 id；若 ESSM 已有不同 id 则不覆盖并记 mismatch。
local function persist_generation_sync_same(ent, id)
	if not item.is_essm_backend() or not ent or id == nil then return end
	local existing = select(1, lifetime.read_namespace(ent, ESSM_GEN_NS))
	if type(existing) == "table" and existing.id ~= nil and tonumber(existing.id) ~= tonumber(id) then
		bump("generation_persistence_mismatch")
		item.debug.last_classify = {
			event = "generation_persistence_mismatch",
			business_id = id,
			essm_id = existing.id,
			seed = ent.InitSeed,
			frame = game_frame(),
		}
		pcall(function()
			Isaac.DebugString(
				"[Qing Unique] generation_persistence_mismatch business="
					.. tostring(id)
					.. " essm="
					.. tostring(existing.id)
					.. " seed="
					.. tostring(ent.InitSeed)
			)
		end)
		return
	end
	persist_generation_write(ent, id)
end

local function read_generation_from_save_state(save_state)
	local ns = select(1, lifetime.read_namespace_from_save_state(save_state, ESSM_GEN_NS))
	if type(ns) ~= "table" then return nil end
	local id = tonumber(ns.id)
	if id ~= nil then
		bump("generation_persist_read")
	end
	return id
end

local function room_identity(desc)
	desc = desc or (Game():GetLevel() and Game():GetLevel():GetCurrentRoomDesc())
	if not desc then return nil end
	local stage, stage_type, dim = nil, nil, nil
	pcall(function()
		local level = Game():GetLevel()
		stage = level:GetStage()
		stage_type = level:GetStageType()
		if level.GetDimension then
			dim = level:GetDimension()
		end
	end)
	return {
		list_index = desc.ListIndex,
		stage = stage,
		stage_type = stage_type,
		dimension = dim,
	}
end

local function registry_room_ok()
	local meta = item._restore_registry_meta
	if type(meta) ~= "table" then return false end
	local cur = room_identity()
	if not cur then return false end
	if meta.list_index ~= cur.list_index then return false end
	if meta.stage ~= nil and cur.stage ~= nil and meta.stage ~= cur.stage then return false end
	if meta.stage_type ~= nil and cur.stage_type ~= nil and meta.stage_type ~= cur.stage_type then return false end
	if meta.dimension ~= nil and cur.dimension ~= nil and meta.dimension ~= cur.dimension then return false end
	return true
end

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_GAME_STARTED,
	params = nil,
	Function = function(_, continue)
		item.signal_hash_table = {}
		item._restore_registry = {}
		item._restore_registry_meta = nil
		item._morph_before = {}
		item._morph_handled_frame = {}
		item._room_generation_epoch = 0
		item._clear_missing_override()
		-- Continue：保留 UniqueGenerationNext（run-scoped allocator）与 ESSM QingUniqueGeneration.id
		if not continue then
			-- 新开局由 save.elses 整体重置；此处不主动清 GEN_NEXT，避免与存档管线竞态
		end
	end,
})

table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.PRE_NEW_ROOM,
	params = nil,
	Function = function(_)
		-- 每次 live room appearance +1（回房 ≠ 同一次 appearance）
		item._room_generation_epoch = (tonumber(item._room_generation_epoch) or 0) + 1
		item[item.own_key .. "shop_item"] = nil
		local room = Game():GetRoom()
		local first = false
		pcall(function()
			first = room:IsFirstVisit()
		end)
		if first then
			item._restore_registry = {}
			item._restore_registry_meta = nil
		end
		item._morph_before = {}
		item._morph_handled_frame = {}
		-- Debug：跨房仍挂着 missing override = 泄漏
		local ov = item[item.own_key .. "missing_ov"]
		if ov then
			local env_ok, env = pcall(require, "Qing_Remaster_scripts.core.dev_environment")
			if env_ok and env and not env.is_public_release() then
				Isaac.DebugString(
					"[Qing Unique] MISSING_OVERRIDE_LEAK across room id="
						.. tostring(ov.id)
						.. " remaining="
						.. tostring(ov.remaining)
						.. " consume="
						.. tostring(ov.consume_count)
				)
			end
			-- release 不清，避免掩盖业务 bug；开发树也不擅自清，只打点
		end
	end,
})

-- Rewind：清 future-derived runtime cache。_room_generation_epoch 不回退（appearance token 可继续递增）。
table.insert(item.myToCall, #item.myToCall + 1, {
	CallBack = enums.Callbacks.POST_REWIND,
	params = nil,
	Function = function(_)
		item._restore_registry = {}
		item._restore_registry_meta = nil
		item._morph_before = {}
		item._morph_handled_frame = {}
	end,
})

function item.is_essm_backend()
	if item.debug.force_legacy_backend == true then return false end
	return lifetime.is_available() == true
end

function item.set_force_legacy_backend(on)
	item.debug.force_legacy_backend = on == true
end

function item.get_backend_name()
	return item.is_essm_backend() and "essm" or "legacy"
end

function item.set_shadow_enabled(on)
	item.debug.shadow_enabled = on == true
end

function item.is_shadow_enabled()
	return item.debug.shadow_enabled == true
end

function item.reset_shadow_stats()
	item.debug.match_new = 0
	item.debug.match_old = 0
	item.debug.legacy_new_essm_old = 0
	item.debug.legacy_old_essm_new = 0
	item.debug.essm_error = 0
	item.debug.morph_reinit_events = 0
	item.debug.cycle_reinit_events = 0
	item.debug.known_legacy_noise = 0
	item.debug.registry_restored = 0
	item.debug.live_essm_restored = 0
	item.debug.new_midroom = 0
	item.debug.new_first_visit = 0
	item.debug.gen_new = 0
	item.debug.gen_same = 0
	item.debug.gen_restored = 0
	item.debug.gen_empty = 0
	item.debug.legacy_fallback = 0
	item.debug.unresolved = 0
	item.debug.early_create_blocked = 0
	item.debug.restore_registry_miss = 0
	item.debug.essm_api_error = 0
	item.debug.generation_persist_write = 0
	item.debug.generation_persist_read = 0
	item.debug.generation_restore_with_id = 0
	item.debug.generation_restore_missing_id = 0
	item.debug.generation_persistence_mismatch = 0
	item.debug.resolve_runtime_hit = 0
	item.debug.resolve_registry_hit = 0
	item.debug.resolve_essm_hit = 0
	item.debug.resolve_morph_hit = 0
	item.debug.resolve_classify_hit = 0
	item.debug.resolve_unresolved = 0
	item.debug.resolve_conflict = 0
	item.debug.last = nil
	item.debug.last_classify = nil
	item.debug.last_generation = nil
	item.debug.last_native = nil
	item.debug.last_resolve = nil
end

function item.get_shadow_snapshot()
	local reg_n = 0
	if item._restore_registry then
		for k in pairs(item._restore_registry) do
			if type(k) == "string" and not tostring(k):find("^seed:") then
				reg_n = reg_n + 1
			end
		end
	end
	return {
		enabled = item.debug.shadow_enabled == true,
		backend = item.get_backend_name(),
		force_legacy = item.debug.force_legacy_backend == true,
		match_new = item.debug.match_new or 0,
		match_old = item.debug.match_old or 0,
		legacy_new_essm_old = item.debug.legacy_new_essm_old or 0,
		legacy_old_essm_new = item.debug.legacy_old_essm_new or 0,
		essm_error = item.debug.essm_error or 0,
		morph_reinit_events = item.debug.morph_reinit_events or 0,
		cycle_reinit_events = item.debug.cycle_reinit_events or 0,
		known_legacy_noise = item.debug.known_legacy_noise or 0,
		registry_restored = item.debug.registry_restored or 0,
		gen_new = item.debug.gen_new or 0,
		gen_same = item.debug.gen_same or 0,
		gen_restored = item.debug.gen_restored or 0,
		gen_empty = item.debug.gen_empty or 0,
		legacy_fallback = item.debug.legacy_fallback or 0,
		unresolved = item.debug.unresolved or 0,
		early_create_blocked = item.debug.early_create_blocked or 0,
		restore_registry_miss = item.debug.restore_registry_miss or 0,
		essm_api_error = item.debug.essm_api_error or 0,
		generation_persist_write = item.debug.generation_persist_write or 0,
		generation_persist_read = item.debug.generation_persist_read or 0,
		generation_restore_with_id = item.debug.generation_restore_with_id or 0,
		generation_restore_missing_id = item.debug.generation_restore_missing_id or 0,
		generation_persistence_mismatch = item.debug.generation_persistence_mismatch or 0,
		resolve_runtime_hit = item.debug.resolve_runtime_hit or 0,
		resolve_registry_hit = item.debug.resolve_registry_hit or 0,
		resolve_essm_hit = item.debug.resolve_essm_hit or 0,
		resolve_morph_hit = item.debug.resolve_morph_hit or 0,
		resolve_classify_hit = item.debug.resolve_classify_hit or 0,
		resolve_unresolved = item.debug.resolve_unresolved or 0,
		resolve_conflict = item.debug.resolve_conflict or 0,
		room_generation_epoch = item.get_room_generation_epoch(),
		last = item.debug.last,
		last_classify = item.debug.last_classify,
		last_generation = item.debug.last_generation,
		last_native = item.debug.last_native,
		last_resolve = item.debug.last_resolve,
		last_fresh = (function()
			local lg = item.debug.last_generation
			if type(lg) ~= "table" then return nil end
			local birth = tonumber(lg.birth_room_epoch)
			local cur = item.get_room_generation_epoch()
			return {
				birth_room_epoch = birth,
				room_generation_epoch = cur,
				fresh = birth ~= nil and birth == cur,
			}
		end)(),
		registry_size = reg_n,
	}
end

function item.registry_key(seed, typ, variant)
	return tostring(seed or 0) .. ":" .. tostring(typ or 0) .. ":" .. tostring(variant or 0)
end

function item.lookup_restore_registry(ent)
	if not ent then return nil end
	if not registry_room_ok() then return nil end
	local key = item.registry_key(ent.InitSeed, ent.Type, ent.Variant)
	local hit = item._restore_registry[key]
	if hit then return hit, key end
	-- seed-only：仅当唯一候选才命中
	local seed_key = "seed:" .. tostring(ent.InitSeed)
	local cands = item._restore_registry[seed_key]
	if type(cands) == "table" and cands.__candidates then
		if #cands == 1 then
			return cands[1], key
		end
		return nil, key
	end
	if type(cands) == "table" and cands.token ~= nil then
		return cands, key
	end
	return nil, key
end

--- Native ESSM / restore axis（≠ business generation）。
function item.get_native_identity(ent)
	local room = Game():GetRoom()
	local room_frame = room:GetFrameCount()
	local reg, reg_key = item.lookup_restore_registry(ent)
	local live = select(1, lifetime.try_get(ent))
	if reg and reg.token ~= nil then
		return {
			kind = "NATIVE_RESTORED",
			source = "restore_registry",
			token = reg.token,
			registry_hit = true,
			live_tryget_hit = live ~= nil,
			room_frame = room_frame,
			registry_key = reg_key,
		}
	end
	if live then
		return {
			kind = "NATIVE_SAME",
			source = "live_essm",
			token = live.token,
			registry_hit = false,
			live_tryget_hit = true,
			room_frame = room_frame,
		}
	end
	return {
		kind = "NATIVE_UNKNOWN",
		source = "none",
		token = nil,
		registry_hit = false,
		live_tryget_hit = false,
		room_frame = room_frame,
	}
end

--- Runtime-only 纯读：只 mirror GetData marker，不 prepare / restore / classify。
--- DO NOT use as authoritative consumer identity query — 用 resolve_generation。
function item.peek_generation(ent)
	if not ent then return nil end
	local d = ent:GetData()
	local marker = d and d[GEN_KEY]
	if type(marker) ~= "table" then
		return nil
	end
	if marker.id == nil or not marker.kind then
		return nil
	end
	return {
		id = marker.id,
		kind = marker.kind,
		source = marker.source,
		seed = marker.seed,
		subtype = marker.subtype,
		frame = marker.frame,
		birth_room_epoch = marker.birth_room_epoch,
	}
end

--- 兼容旧名：等价 peek_generation（runtime-only，允许 nil）。
function item.get_generation(ent)
	return item.peek_generation(ent)
end

function item.get_room_generation_epoch()
	return tonumber(item._room_generation_epoch) or 0
end

--- 将已确认的 generation materialize 到 live marker；禁止在此 alloc id。
--- GEN_RESTORED / ESSM attach：不得把 birth_room_epoch 写成当前 room epoch（否则回房误判 fresh）。
local function attach_existing_generation(ent, gen)
	if not ent or type(gen) ~= "table" or gen.id == nil then
		return false
	end
	local id = tonumber(gen.id)
	if id == nil then
		return false
	end
	local current = item.peek_generation(ent)
	if current and tonumber(current.id) == id then
		return true
	end
	if current and current.id ~= nil and tonumber(current.id) ~= id then
		bump("resolve_conflict")
		item.debug.last_resolve = {
			event = "attach_conflict",
			runtime_id = current.id,
			resolved_id = id,
			source = gen.source,
			seed = ent.InitSeed,
			frame = game_frame(),
		}
		return false
	end
	local kind = gen.kind or "GEN_RESTORED"
	local source = gen.source or "attach_existing"
	local birth_epoch = gen.birth_room_epoch
	if birth_epoch == nil and current then
		birth_epoch = current.birth_room_epoch
	end
	-- restore / essm attach：禁止默认 current room epoch
	if kind == "GEN_NEW" and birth_epoch == nil then
		birth_epoch = item.get_room_generation_epoch()
	end
	local d = ent:GetData()
	local marker = {
		id = id,
		kind = kind,
		source = source,
		frame = game_frame(),
		seed = ent.InitSeed,
		subtype = ent.SubType or 0,
		birth_room_epoch = birth_epoch,
	}
	d[GEN_KEY] = marker
	if kind == "GEN_NEW" then
		d.first_appear = true
	else
		d.first_appear = false
	end
	d.first_appear2 = nil
	d[STAMP_KEY] = {
		token = select(1, lifetime.get_token(ent)),
		is_new = kind == "GEN_NEW",
		pending = false,
		kind = kind,
		source = source,
		frame = game_frame(),
	}
	-- ESSM：已有不同 id 不得覆盖；无 id 才写入
	if item.is_essm_backend() then
		local existing = select(1, lifetime.read_namespace(ent, ESSM_GEN_NS))
		if type(existing) == "table" and existing.id ~= nil and tonumber(existing.id) ~= id then
			bump("generation_persistence_mismatch")
			item.debug.last_classify = {
				event = "generation_persistence_mismatch",
				business_id = id,
				essm_id = existing.id,
				seed = ent.InitSeed,
				frame = game_frame(),
				via = "attach_existing_generation",
			}
		elseif kind ~= "GEN_EMPTY" then
			persist_generation_write(ent, id)
		end
	end
	item.debug.last_generation = marker
	return true
end

local function note_resolve(reason, ent, extra)
	extra = extra or {}
	item.debug.last_resolve = {
		frame = game_frame(),
		seed = ent and ent.InitSeed,
		subtype = ent and ent.SubType,
		reason = reason,
		generation_id = extra.generation_id,
		kind = extra.kind,
		source = extra.source,
	}
end

--- 正式业务接口：稳定 pedestal generation identity。
--- 可 attach 已确认 id / 调用 frozen classify+apply；禁止自行发明 classification。
--- 仅真正 unresolved 时返回 nil；nil ≠ NEW / first-seen / restored。
function item.resolve_generation(ent)
	if not ent then
		bump("resolve_unresolved")
		note_resolve("invalid_entity", ent)
		return nil
	end
	if ent.Type ~= EntityType.ENTITY_PICKUP or ent.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then
		bump("resolve_unresolved")
		note_resolve("non_collectible", ent)
		return nil
	end

	-- Step 1: runtime marker
	local live = item.peek_generation(ent)
	if live and live.id ~= nil then
		bump("resolve_runtime_hit")
		note_resolve("runtime_marker", ent, {
			generation_id = live.id,
			kind = live.kind,
			source = live.source,
		})
		return live
	end

	if not item.is_essm_backend() then
		-- legacy：无 ESSM/registry 轴；尽量走 classify，否则 unresolved
		local gen = item.classify_unique_generation(ent)
		if gen and gen.kind == "GEN_UNKNOWN" then
			bump("resolve_unresolved")
			note_resolve("legacy_unresolved", ent, { kind = gen.kind, source = gen.source })
			return nil
		end
		if gen then
			item.apply_unique_generation(ent, gen)
			bump("resolve_classify_hit")
			local out = item.peek_generation(ent)
			note_resolve("legacy_classify", ent, {
				generation_id = out and out.id,
				kind = out and out.kind,
				source = out and out.source,
			})
			return out
		end
		bump("resolve_unresolved")
		note_resolve("legacy_nil", ent)
		return nil
	end

	-- Step 2: restore registry（Room Return 核心）
	local reg = select(1, item.lookup_restore_registry(ent))
	if reg and reg.generation_id ~= nil then
		local gid = tonumber(reg.generation_id)
		if gid ~= nil then
			local gen = {
				id = gid,
				kind = "GEN_RESTORED",
				source = "restore_registry_resolve",
				-- 不得写 current room epoch：回房不能变 fresh
				birth_room_epoch = nil,
			}
			if attach_existing_generation(ent, gen) then
				bump("resolve_registry_hit")
				local out = item.peek_generation(ent) or gen
				note_resolve("restore_registry", ent, {
					generation_id = out.id,
					kind = out.kind,
					source = out.source,
				})
				return out
			end
			-- attach conflict：不覆盖，记 unresolved
			bump("resolve_unresolved")
			note_resolve("restore_registry_attach_conflict", ent, {
				generation_id = gid,
			})
			return item.peek_generation(ent)
		end
	elseif reg == nil then
		-- 多候选等 ambiguous：lookup 已 miss；若仅 seed 多候选，勿猜
		if registry_room_ok() then
			local seed_key = "seed:" .. tostring(ent.InitSeed)
			local cands = item._restore_registry[seed_key]
			if type(cands) == "table" and cands.__candidates and #cands > 1 then
				bump("resolve_unresolved")
				note_resolve("ambiguous_restore_registry", ent)
				return nil
			end
		end
	end

	-- Step 3: ESSM QingUniqueGeneration namespace（只读，不 create）
	local ns_ok, ns = pcall(function()
		return select(1, lifetime.read_namespace(ent, ESSM_GEN_NS))
	end)
	if not ns_ok then
		bump("essm_api_error")
		bump("resolve_unresolved")
		note_resolve("essm_api_error", ent)
		return nil
	end
	if type(ns) == "table" and ns.id ~= nil then
		local gid = tonumber(ns.id)
		if gid ~= nil then
			local native = item.get_native_identity(ent)
			local kind = "GEN_SAME"
			local source = "essm_resolve"
			if native and native.kind == "NATIVE_RESTORED" then
				kind = "GEN_RESTORED"
				source = "essm_resolve_restored"
			elseif native and native.kind == "NATIVE_SAME" then
				kind = "GEN_SAME"
				source = "essm_resolve_same"
			end
			-- subtype0：空底座不得把 ESSM id 当成业务 collectible generation
			if (ent.SubType or 0) == 0 then
				bump("resolve_unresolved")
				note_resolve("empty_pedestal_essm_skip", ent, { generation_id = gid })
				return nil
			end
			local gen = { id = gid, kind = kind, source = source, birth_room_epoch = nil }
			if attach_existing_generation(ent, gen) then
				bump("resolve_essm_hit")
				local out = item.peek_generation(ent) or gen
				note_resolve("essm", ent, {
					generation_id = out.id,
					kind = out.kind,
					source = out.source,
				})
				return out
			end
			bump("resolve_unresolved")
			note_resolve("essm_attach_conflict", ent, { generation_id = gid })
			return item.peek_generation(ent)
		end
	end

	-- Step 4: Morph bridge evidence（复用 frozen classify，不复制判断）
	local pk = ptr_key(ent)
	local before = pk and item._morph_before[pk] or nil
	if before and before.old_seed == nil and before.seed ~= nil then
		-- _morph_before 存的是 seed/subtype/gen_id
		local morph_ctx = {
			old_seed = before.seed,
			old_subtype = before.subtype,
			gen_id = before.gen_id,
			birth_room_epoch = before.birth_room_epoch,
			kept_seed = before.seed == ent.InitSeed,
		}
		local gen = item.classify_unique_generation(ent, { morph = morph_ctx })
		if gen and gen.kind ~= "GEN_UNKNOWN" then
			item.apply_unique_generation(ent, gen)
			bump("resolve_morph_hit")
			local out = item.peek_generation(ent)
			note_resolve("morph_bridge", ent, {
				generation_id = out and out.id,
				kind = out and out.kind,
				source = out and out.source,
			})
			return out
		end
	end

	-- Step 5: frozen classify + apply（仅 classifier 说 GEN_NEW 时才 alloc）
	local classified = item.classify_unique_generation(ent)
	if not classified or classified.kind == "GEN_UNKNOWN" then
		bump("resolve_unresolved")
		note_resolve("classify_unresolved", ent, {
			kind = classified and classified.kind,
			source = classified and classified.source,
		})
		return nil
	end
	-- 空底座：可返回 EMPTY marker（apply 会写 id），业务 consumer 通常自行过滤 SubType==0
	item.apply_unique_generation(ent, classified)
	bump("resolve_classify_hit")
	local out = item.peek_generation(ent)
	if not out then
		bump("resolve_unresolved")
		note_resolve("classify_apply_no_marker", ent, {
			kind = classified.kind,
			source = classified.source,
		})
		return nil
	end
	note_resolve("classify", ent, {
		generation_id = out.id,
		kind = out.kind,
		source = out.source,
	})
	return out
end

function item.is_current_classification_new(ent)
	local gen = item.resolve_generation(ent)
	return gen ~= nil and gen.kind == "GEN_NEW"
end

--- DEPRECATED：仅表示当前 kind==GEN_NEW，不是耐久 freshness。
--- 业务「本房新生 pedestal」必须用 is_fresh_generation()。
function item.is_new_generation(ent)
	return item.is_current_classification_new(ent)
end

--- 本 room appearance 中以 GEN_NEW 诞生的 generation（可延迟查询，不依赖 kind 仍为 GEN_NEW）。
function item.is_fresh_generation(ent)
	local gen = item.resolve_generation(ent)
	if not gen or not gen.id then
		return false
	end
	local birth = tonumber(gen.birth_room_epoch)
	local cur = item.get_room_generation_epoch()
	return birth ~= nil and birth == cur
end

--- 写 generation marker + first_appear（业务轴）。
function item.apply_unique_generation(ent, generation, opts)
	opts = opts or {}
	local d = ent:GetData()
	local room = Game():GetRoom()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	generation = generation or {}
	local kind = generation.kind or "GEN_UNKNOWN"
	local id = generation.id
	local source = generation.source
	local existing = d[GEN_KEY]
	local birth_epoch = generation.birth_room_epoch
	if kind == "GEN_NEW" then
		id = id or alloc_generation_id()
		bump("gen_new")
		d.first_appear = true
		d.first_appear2 = nil
		birth_epoch = item.get_room_generation_epoch()
		if source == "midroom_new" then
			bump("new_midroom")
		elseif source == "first_visit_new" then
			bump("new_first_visit")
		end
		-- 仅 GEN_NEW 时确保 ESSM token + 写 generation namespace（禁止 INIT 判定前 GetEntityData）
		if item.is_essm_backend() then
			lifetime.ensure_token(ent)
			persist_generation_write(ent, id)
		end
	elseif kind == "GEN_SAME" then
		id = id or (existing and existing.id) or alloc_generation_id()
		bump("gen_same")
		d.first_appear = false
		d.first_appear2 = nil
		birth_epoch = birth_epoch or (existing and existing.birth_room_epoch)
		persist_generation_sync_same(ent, id)
	elseif kind == "GEN_RESTORED" then
		if id ~= nil then
			bump("generation_restore_with_id")
		else
			-- 旧存档只有 QingEntityLifetime.token：legacy 分配新 id（migration）
			id = alloc_generation_id()
			bump("generation_restore_missing_id")
			source = source or "restore_registry_legacy_generation"
		end
		bump("gen_restored")
		bump("registry_restored")
		d.first_appear = false
		d.first_appear2 = nil
		-- 恢复旧 birth（若有）；不得写成 current room epoch
		birth_epoch = birth_epoch or (existing and existing.birth_room_epoch)
		-- 回房后同步 ESSM namespace（与业务 id 对齐）
		if item.is_essm_backend() then
			persist_generation_write(ent, id)
		end
	elseif kind == "GEN_EMPTY" then
		id = id or (existing and existing.id) or alloc_generation_id()
		bump("gen_empty")
		d.first_appear = false
		d.first_appear2 = nil
		birth_epoch = birth_epoch or (existing and existing.birth_room_epoch)
	else
		-- GEN_UNKNOWN → legacy fallback
		bump("unresolved")
		bump("legacy_fallback")
		apply_legacy_unique_init(ent, d, room, desc)
		item.debug.last_generation = generation
		return
	end
	local marker = {
		id = id,
		kind = kind,
		source = source,
		frame = game_frame(),
		seed = ent.InitSeed,
		subtype = ent.SubType or 0,
		birth_room_epoch = birth_epoch,
	}
	d[GEN_KEY] = marker
	-- shadow 兼容 stamp
	d[STAMP_KEY] = {
		token = select(1, lifetime.get_token(ent)),
		is_new = kind == "GEN_NEW",
		pending = false,
		kind = kind,
		source = source,
		frame = game_frame(),
	}
	item.debug.last_generation = marker
	if opts.shadow ~= false and item.debug.shadow_enabled == true then
		pcall(function()
			item.shadow_compare_pickup(ent)
		end)
	end
end

--- 业务 generation 轴（不直接用 ESSM token 决定 NEW）。
function item.classify_unique_generation(ent, context)
	context = context or {}
	local room = Game():GetRoom()
	local room_frame = room:GetFrameCount()
	local first_visit = false
	pcall(function()
		first_visit = room:IsFirstVisit()
	end)
	local subtype = ent.SubType or 0
	local is_empty = (ent.Variant == PickupVariant.PICKUP_COLLECTIBLE) and subtype == 0
	local d = ent:GetData()
	local existing = d[GEN_KEY]
	local native = item.get_native_identity(ent)
	item.debug.last_native = native

	-- Empty 优先于 Morph：TryRemove / EMPTY_PENDING 不得被 morph bridge 判成 NEW/SAME
	if is_empty then
		bump("early_create_blocked")
		return {
			kind = "GEN_EMPTY",
			source = "empty_pedestal",
			id = existing and existing.id,
			birth_room_epoch = existing and existing.birth_room_epoch,
			native = native,
		}
	end

	-- Morph bridge（POST 已写入 context.morph）
	local morph = context.morph
	if morph and morph.old_seed ~= nil then
		if morph.old_seed ~= ent.InitSeed then
			return {
				kind = "GEN_NEW",
				source = "morph_replacement",
				native = native,
				seed_changed = true,
				old_seed = morph.old_seed,
			}
		end
		return {
			kind = "GEN_SAME",
			source = "morph_same_seed",
			id = morph.gen_id or (existing and existing.id),
			birth_room_epoch = morph.birth_room_epoch
				or (existing and existing.birth_room_epoch),
			native = native,
			seed_changed = false,
			old_seed = morph.old_seed,
		}
	end

	-- Restore registry 最高优先
	if native.kind == "NATIVE_RESTORED" then
		local reg = item.lookup_restore_registry(ent)
		local gen_id = reg and tonumber(reg.generation_id) or nil
		if gen_id ~= nil then
			return {
				kind = "GEN_RESTORED",
				source = "restore_registry",
				id = gen_id,
				-- 不得附 current room epoch；apply 亦不得补写 current
				birth_room_epoch = existing and existing.birth_room_epoch,
				native = native,
				token = native.token,
			}
		end
		return {
			kind = "GEN_RESTORED",
			source = "restore_registry_legacy_generation",
			id = nil,
			birth_room_epoch = existing and existing.birth_room_epoch,
			native = native,
			token = native.token,
		}
	end

	if room_frame >= 0 then
		-- 已有 generation marker 且 seed 未变 → 同 generation（Cycle re-INIT 等）
		if existing and existing.seed == ent.InitSeed and existing.kind ~= "GEN_EMPTY" then
			return {
				kind = "GEN_SAME",
				source = "existing_marker",
				id = existing.id,
				birth_room_epoch = existing.birth_room_epoch,
				native = native,
			}
		end
		return {
			kind = "GEN_NEW",
			source = "midroom_new",
			native = native,
		}
	end

	-- room_frame == -1
	if first_visit then
		bump("restore_registry_miss")
		return {
			kind = "GEN_NEW",
			source = "first_visit_new",
			native = native,
		}
	end
	-- 回访无 registry：legacy
	bump("restore_registry_miss")
	return {
		kind = "GEN_UNKNOWN",
		source = "legacy_fallback",
		native = native,
	}
end

--- 兼容旧名：映射到 generation 轴。
function item.classify_pickup_identity(ent)
	local gen = item.classify_unique_generation(ent)
	local map = {
		GEN_NEW = "NEW",
		GEN_SAME = "SAME_LIFETIME",
		GEN_RESTORED = "RESTORED",
		GEN_EMPTY = "SAME_LIFETIME",
		GEN_UNKNOWN = "UNRESOLVED",
	}
	return {
		kind = map[gen.kind] or "UNRESOLVED",
		source = gen.source,
		token = gen.native and gen.native.token,
		is_new = gen.kind == "GEN_NEW",
		room_frame = gen.native and gen.native.room_frame,
		registry_hit = gen.native and gen.native.registry_hit,
		live_tryget_hit = gen.native and gen.native.live_tryget_hit,
		generation = gen,
		native = gen.native,
	}
end

apply_legacy_unique_init = function(ent, d, room, desc)
	item.debug.backend = "legacy"
	if room:GetFrameCount() == -1 then
		if room:IsFirstVisit() then
			d.first_appear = true
			consistance_holder.try_hold_entity(ent, item.own_key, { ignore_subtype = true, one_room = true })
		end
	else
		local succ = consistance_holder.try_check_entity(ent, item.own_key)
		if not succ then
			d.first_appear = true
			consistance_holder.try_hold_entity(ent, item.own_key, { ignore_subtype = true })
		end
	end
	d.first_appear2 = nil
end

function item.build_restore_registry(room_desc)
	item._restore_registry = {}
	local ident = room_identity(room_desc)
	item._restore_registry_meta = {
		frame = game_frame(),
		list_index = ident and ident.list_index,
		stage = ident and ident.stage,
		stage_type = ident and ident.stage_type,
		dimension = ident and ident.dimension,
		count = 0,
		with_token = 0,
		with_generation = 0,
	}
	if not lifetime.is_available() or not room_desc then
		return item._restore_registry
	end
	local ok, states = pcall(function()
		return room_desc:GetEntitiesSaveState()
	end)
	if not ok or states == nil then
		bump("essm_api_error")
		return item._restore_registry
	end
	local n = 0
	pcall(function()
		n = #states
	end)
	local function ingest(ss)
		if not ss then return end
		local typ, var, sub, seed = 0, 0, 0, 0
		pcall(function() typ = ss:GetType() end)
		pcall(function() var = ss:GetVariant() end)
		pcall(function() sub = ss:GetSubType() end)
		pcall(function() seed = ss:GetInitSeed() end)
		if typ ~= EntityType.ENTITY_PICKUP then return end
		if var ~= PickupVariant.PICKUP_COLLECTIBLE then return end
		local info = select(1, lifetime.try_get_from_save_state(ss))
		local generation_id = read_generation_from_save_state(ss)
		local entry = {
			token = info and info.token or nil,
			generation_id = generation_id,
			type = typ,
			variant = var,
			subtype = sub,
			init_seed = seed,
		}
		local key = item.registry_key(seed, typ, var)
		item._restore_registry[key] = entry
		-- seed candidates
		local sk = "seed:" .. tostring(seed)
		local bag = item._restore_registry[sk]
		if bag == nil then
			item._restore_registry[sk] = entry
		elseif bag.__candidates then
			bag[#bag + 1] = entry
		else
			item._restore_registry[sk] = { __candidates = true, bag, entry }
		end
		item._restore_registry_meta.count = (item._restore_registry_meta.count or 0) + 1
		if entry.token ~= nil then
			item._restore_registry_meta.with_token = (item._restore_registry_meta.with_token or 0) + 1
		end
		if entry.generation_id ~= nil then
			item._restore_registry_meta.with_generation = (item._restore_registry_meta.with_generation or 0) + 1
		end
	end
	if n > 0 and states.Get then
		for i = 0, n do
			local ss = nil
			pcall(function()
				ss = states:Get(i)
			end)
			ingest(ss)
		end
	end
	return item._restore_registry
end

function item.shadow_compare_pickup(ent, opts)
	opts = opts or {}
	if not ent then return nil end
	local d = ent:GetData()
	local room = Game():GetRoom()
	local mid_room = room:GetFrameCount() ~= -1
	local gen = d[GEN_KEY] or opts.generation or item.debug.last_generation
	local native = opts.native or item.get_native_identity(ent)
	local flag_new = d.first_appear == true
	local flag_new2 = d.first_appear2 == true
	local gen_kind = gen and gen.kind or nil
	local gen_is_new = gen_kind == "GEN_NEW"
	local gen_is_old = gen_kind == "GEN_SAME" or gen_kind == "GEN_RESTORED" or gen_kind == "GEN_EMPTY"
	local class
	if gen_kind == nil or gen_kind == "GEN_UNKNOWN" then
		class = "UNRESOLVED"
	elseif gen_is_new and flag_new then
		class = "MATCH"
		item.debug.match_new = (item.debug.match_new or 0) + 1
	elseif gen_is_old and not flag_new then
		class = "MATCH"
		item.debug.match_old = (item.debug.match_old or 0) + 1
	elseif gen_is_new and not flag_new then
		class = "ESSM_NEW_LEGACY_OLD"
		item.debug.legacy_old_essm_new = (item.debug.legacy_old_essm_new or 0) + 1
	elseif gen_is_old and flag_new then
		class = "ESSM_OLD_LEGACY_NEW"
		item.debug.legacy_new_essm_old = (item.debug.legacy_new_essm_old or 0) + 1
	else
		class = "MATCH"
	end
	if mid_room then
		item.debug.morph_reinit_events = (item.debug.morph_reinit_events or 0) + 1
	end
	local row = {
		class = class,
		backend = item.get_backend_name(),
		seed = ent.InitSeed,
		subtype = ent.SubType or 0,
		legacy_first_appear = flag_new,
		legacy_first_appear2 = flag_new2,
		generation_kind = gen_kind,
		generation_source = gen and gen.source,
		generation_id = gen and gen.id,
		native_kind = native and native.kind,
		native_token = native and native.token,
		essm_token = native and native.token,
		essm_kind = gen_kind,
		essm_source = gen and gen.source,
		registry_hit = native and native.registry_hit,
		live_tryget_hit = native and native.live_tryget_hit,
		room_frame = room:GetFrameCount(),
		mid_room = mid_room,
		frame = game_frame(),
	}
	item.debug.last = row
	item.debug.last_native = native
	return row
end

local function run_unique_init(ent)
	local room = Game():GetRoom()
	local desc = Game():GetLevel():GetCurrentRoomDesc()
	local d = ent:GetData()
	local pk = ptr_key(ent)
	if item.is_essm_backend() then
		item.debug.backend = "essm"
		-- Morph POST 已处理则跳过（防双重 NEW）
		if pk and item._morph_handled_frame[pk] == game_frame() then
			return
		end
		local gen = item.classify_unique_generation(ent)
		item.apply_unique_generation(ent, gen)
	else
		apply_legacy_unique_init(ent, d, room, desc)
	end
end

if ModCallbacks.MC_PRE_ROOM_RESTORE_STATE then
	table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
		CallBack = ModCallbacks.MC_PRE_ROOM_RESTORE_STATE,
		params = nil,
		Function = function(_, _room, room_desc)
			if not item.is_essm_backend() then return end
			item.build_restore_registry(room_desc)
		end,
	})
end

if ModCallbacks.MC_PRE_PICKUP_MORPH then
	table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
		CallBack = ModCallbacks.MC_PRE_PICKUP_MORPH,
		params = nil,
		priority = -190,
		Function = function(_, pickup)
			local p = pickup and (pickup.ToPickup and pickup:ToPickup() or pickup) or nil
			if not p or p.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then return end
			local pk = ptr_key(p)
			if not pk then return end
			local d = p:GetData()
			local gen = d[GEN_KEY]
			item._morph_before[pk] = {
				seed = p.InitSeed,
				subtype = p.SubType or 0,
				gen_id = gen and gen.id,
				birth_room_epoch = gen and gen.birth_room_epoch,
			}
		end,
	})
end

if ModCallbacks.MC_POST_PICKUP_MORPH then
	table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
		CallBack = ModCallbacks.MC_POST_PICKUP_MORPH,
		params = nil,
		priority = -90,
		Function = function(_, pickup, _pt, _pv, _ps, _kp, keptSeed, _im)
			if not item.is_essm_backend() then return end
			local p = pickup and (pickup.ToPickup and pickup:ToPickup() or pickup) or nil
			if not p or p.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then return end
			local pk = ptr_key(p)
			local before = pk and item._morph_before[pk] or nil
			if pk then item._morph_before[pk] = nil end
			if not before then return end
			local gen = item.classify_unique_generation(p, {
				morph = {
					old_seed = before.seed,
					old_subtype = before.subtype,
					gen_id = before.gen_id,
					birth_room_epoch = before.birth_room_epoch,
					kept_seed = keptSeed == true,
				},
			})
			item.apply_unique_generation(p, gen)
			if pk then
				item._morph_handled_frame[pk] = game_frame()
			end
		end,
	})
end

table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PICKUP_INIT,
	params = 100,
	Function = function(_, ent)
		run_unique_init(ent)
		if item.debug.shadow_enabled == true then
			pcall(function()
				item.shadow_compare_pickup(ent)
			end)
		end
	end,
})

--- 空底座 settle：TryRemove 同帧可能仍留 GEN_NEW marker；供 UPDATE / Test Lab 立刻纠正。
function item.settle_empty_pedestal(ent)
	if not ent or ent.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then return nil end
	if (ent.SubType or 0) ~= 0 then return nil end
	if not item.is_essm_backend() then return nil end
	local gen = item.classify_unique_generation(ent)
	item.apply_unique_generation(ent, gen)
	return gen
end

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_PICKUP_UPDATE,
	params = 100,
	Function = function(_, ent)
		if not item.is_essm_backend() then return end
		if (ent.SubType or 0) ~= 0 then return end
		local d = ent:GetData()
		local gen = d[GEN_KEY]
		-- 纠正 TryRemove 后仍残留的 GEN_NEW / 非 EMPTY marker（同帧 Lab 也会主动 settle）
		local needs = d.first_appear == true
			or (type(gen) == "table" and gen.kind ~= "GEN_EMPTY")
		if not needs then return end
		item.settle_empty_pedestal(ent)
	end,
})

table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
	CallBack = ModCallbacks.MC_PRE_GET_COLLECTIBLE,
	params = nil,
	priority = -100,
	Function = function(_, pool, decrease, seed)
		local ov = item[item.own_key .. "missing_ov"]
		if not ov then
			-- legacy flat key（迁移期兜底）
			local legacy = item[item.own_key .. "missing"]
			if legacy then
				return legacy or 33
			end
			return
		end
		local id = ov.id or 33
		ov.consume_count = (ov.consume_count or 0) + 1
		if ov.remaining ~= nil then
			ov.remaining = ov.remaining - 1
			if ov.remaining <= 0 then
				item._set_missing_override(nil)
			end
		end
		return id
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function(_)
		for playerNum = 1, Game():GetNumPlayers() do
			local player = Game():GetPlayer(playerNum - 1)
			if player:GetData().should_evaluate_on_update_once then
				player:EvaluateItems()
				player:GetData().should_evaluate_on_update_once = nil
			end
		end
	end,
})

table.insert(item.pre_ToCall, #item.pre_ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_NEW_ROOM,
	params = nil,
	Function = function(_)
		local player = Game():GetPlayer(0)
		local d = player:GetData()
		item.Room_Shift_offset = player.Position - auxi.ProtectVector(d[item.own_key .. "RPos"] or player.Position)
	end,
})

table.insert(item.ToCall, #item.ToCall + 1, {
	CallBack = ModCallbacks.MC_POST_UPDATE,
	params = nil,
	Function = function(_)
		local player = Game():GetPlayer(0)
		local d = player:GetData()
		d[item.own_key .. "RPos"] = auxi.Vector2Table(player.Position)
	end,
})

--- 预热商店池。必须恢复 RoomDescriptor.ShopItemIdx，否则会推进本房货位序号，
--- 后续 D6/ReloadGraphics 可能把道具滚进卡牌等错误 Variant（常见 3¢ 卡）。
function item.try_spawn_shop_item()
	if item[item.own_key .. "shop_item"] ~= nil then return end
	item[item.own_key .. "shop_item"] = true
	local level = Game():GetLevel()
	local room_idx = level:GetCurrentRoomIndex()
	local desc = level:GetRoomByIdx(room_idx)
	local old_idx = nil
	if desc then
		old_idx = desc.ShopItemIdx
	end
	local q = item.with_missing(33, function()
		return Isaac.Spawn(5, 150, 0, Vector(0, 0), Vector(0, 0), nil)
	end)
	if q then q:Remove() end
	if desc and old_idx ~= nil then
		desc.ShopItemIdx = old_idx
	end
end

local function missing_ov_key()
	return item.own_key .. "missing_ov"
end

local function missing_stack_key()
	return item.own_key .. "missing_stack"
end

function item._set_missing_override(ov)
	item[missing_ov_key()] = ov
	if ov then
		item[item.own_key .. "missing"] = ov.id or 33
	else
		item[item.own_key .. "missing"] = nil
	end
end

function item._clear_missing_override()
	item[missing_ov_key()] = nil
	item[missing_stack_key()] = nil
	item[item.own_key .. "missing"] = nil
end

function item.get_missing_override()
	return item[missing_ov_key()]
end

function item.is_missing_override_active()
	return item[missing_ov_key()] ~= nil
end

--- Scope-safe missing override。无论 fn 成败都会恢复外层状态。
--- 新业务请用此 API，禁止裸 Hold_for_missing(true)。
function item.with_missing(id, fn)
	local stack = item[missing_stack_key()]
	if type(stack) ~= "table" then
		stack = {}
		item[missing_stack_key()] = stack
	end
	stack[#stack + 1] = item[missing_ov_key()]
	local started = -1
	pcall(function() started = Game():GetFrameCount() end)
	item._set_missing_override({
		id = id or 33,
		remaining = nil, -- scope 内不自动消费完；离开 scope 才恢复
		started_frame = started,
		consume_count = 0,
	})
	local ok, a, b, c = pcall(fn)
	local prev = stack[#stack]
	stack[#stack] = nil
	item._set_missing_override(prev)
	if not ok then
		error(a)
	end
	return a, b, c
end

--- Dangerous legacy API.
--- Prefer with_missing(id, fn).
--- A leaked override affects global MC_PRE_GET_COLLECTIBLE.
--- Hold_for_missing(true) is one-shot (remaining=1) so forgotten clears cannot pollute a whole run.
--- Multi-spawn scopes MUST use with_missing.
function item.Hold_for_missing(val, id)
	if val then
		local env_ok, env = pcall(require, "Qing_Remaster_scripts.core.dev_environment")
		if env_ok and env and not env.is_public_release() then
			Isaac.DebugString("[Qing Unique] Hold_for_missing(true) legacy one-shot; prefer with_missing")
		end
		local started = -1
		pcall(function() started = Game():GetFrameCount() end)
		item._set_missing_override({
			id = id or 33,
			remaining = 1,
			started_frame = started,
			consume_count = 0,
		})
	else
		item._set_missing_override(nil)
	end
end

return item
