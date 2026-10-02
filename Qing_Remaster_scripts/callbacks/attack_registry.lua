-- Attack registry: Attack objects, member bind/unbind+generation, Seal≠End, EndAttack, tombstone GC.
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local callback_manager = require("Qing_Remaster_scripts.core.callback_manager")

local M = {
	own_key = "attack_trigger_holder_",
	TOMBSTONE_FRAMES = 45,
	DAMAGE_REMEMBER_FRAMES = 6,
	-- Epic/Dr explosions often attribute damage to the player after the projectile is gone.
	PLAYER_BLAST_REMEMBER_FRAMES = 12,
	next_id = 0,
	attacks = {},
	-- GetPtrHash -> { attack_id, generation, init_seed, entity }
	bindings = {},
	-- Short-lived damage identity after bomb/epic remove (hash / InitSeed).
	recent_damage = {},
	recent_damage_seed = {},
	-- player GetPtrHash -> { attack_id, generation, position, expire_frame, family }
	recent_player_blasts = {},
	-- Dev-only audit sink (attack_audit_probe). Nil when unused — one cheap check on hot paths.
	debug_observer = nil,
	-- Optional maintenance timing (Attack Audit Measure Maintenance Cost). Default OFF.
	measure_maintenance = false,
	maintenance_stats = {
		dead_last_ms = 0,
		dead_max_ms = 0,
		integrity_last_ms = 0,
		integrity_max_ms = 0,
		bindings_count = 0,
		active_attack_count = 0,
		bound_member_count = 0,
		dead_interval = 4,
		integrity_interval = 30,
	},
}

-- Reused across sweeps to cut GC in long fights (P1).
local dead_binding_buffer = {}
local integrity_orphan_buffer = {}

local DATA_AID = M.own_key .. "attack_id"
local DATA_GEN = M.own_key .. "generation"
-- Survives Unbind so the next Bind can report previous_attack_* to Attack Audit.
local DATA_LAST_AID = M.own_key .. "last_attack_id"
local DATA_LAST_FAMILY = M.own_key .. "last_family"

local function game_frame()
	return Game():GetFrameCount()
end

local function entity_alive(ent)
	return auxi.check_all_exists(ent)
end

--- Dev audit only. Probe sets/clears; gameplay must not depend on this.
function M.SetDebugObserver(fn)
	M.debug_observer = type(fn) == "function" and fn or nil
end

local function debug_emit(kind, attack, extras)
	local obs = M.debug_observer
	if obs then
		obs(kind, attack, extras)
	end
end

--- Emit a probe-only event (create/seal/bind_reject/collector_reject/…). Attack may be nil.
function M.EmitAudit(kind, attack, extras)
	debug_emit(kind, attack, extras)
end

function M.data_keys()
	return DATA_AID, DATA_GEN
end

function M.clear_entity_binding_meta(ent)
	if not ent then return end
	local d = ent:GetData()
	d[DATA_AID] = nil
	-- Keep DATA_GEN so the next Bind increments generation (reusable entities).
end

function M.read_entity_binding_meta(ent)
	if not ent then return nil, nil end
	local d = ent:GetData()
	return d[DATA_AID], d[DATA_GEN]
end

local function write_entity_meta(ent, attack_id, generation)
	local d = ent:GetData()
	d[DATA_AID] = attack_id
	d[DATA_GEN] = generation
end

function M.dispatch(callback_name, event)
	callback_manager.work(callback_name, function(funct, params)
		if params == nil or params == event.family or params == event.attack_id then
			funct(nil, event)
		end
	end)
end

function M.make_event(attack, extras)
	extras = extras or {}
	local event = {
		attack = attack,
		attack_id = attack and attack.id or extras.attack_id,
		player = extras.player or (attack and attack.player),
		source_id = extras.source_id or (attack and attack.source_id),
		attack_source = extras.attack_source or (attack and attack.source),
		member = extras.member,
		generation = extras.generation,
		family = extras.family or (attack and attack.family),
		position = extras.position,
		direction = extras.direction,
		target = extras.target,
		damage = extras.damage,
		sample_weight = extras.sample_weight,
		-- Damage path: Entity Source / ExtraSource. Not Attack.source.
		source = extras.source,
		reason = extras.reason,
		previous_attack_id = extras.previous_attack_id,
		previous_family = extras.previous_family,
	}
	return event
end

function M.GetAttack(id)
	if id == nil then return nil end
	return M.attacks[id]
end

function M.GetAttackForMember(ent)
	if not ent then return nil end
	local hash = GetPtrHash(ent)
	local binding = M.bindings[hash]
	if not binding then return nil end
	local attack = M.attacks[binding.attack_id]
	if not attack or not attack.active or attack.ending then
		return nil
	end
	local aid, gen = M.read_entity_binding_meta(ent)
	if aid ~= binding.attack_id or gen ~= binding.generation then
		-- Entity GetData can be wiped mid-lifetime (Epic ROCKET near landing observed).
		-- Registry binding is authoritative; rewrite namespaced meta.
		write_entity_meta(ent, binding.attack_id, binding.generation)
	end
	return attack, binding
end

function M.CreateAttack(player, family, opts)
	opts = opts or {}
	M.next_id = M.next_id + 1
	local source = opts.source
	local source_id = opts.source_id
	if source and source.source_id then
		source_id = source_id or source.source_id
	elseif not source_id and player then
		source_id = "player:" .. tostring(GetPtrHash(player))
		source = {
			kind = "player",
			entity = player,
			source_id = source_id,
			owner_player = player,
		}
	end
	local attack = {
		id = M.next_id,
		player = player,
		family = family or "unknown",
		source = source,
		source_id = source_id,
		tags = {},
		open_for_members = true,
		active = true,
		ending = false,
		created_frame = game_frame(),
		sealed_frame = nil,
		ended_frame = nil,
		members = {},
		bound_members = {},
		member_count = 0,
		bound_count = 0,
		once_emitted = false,
		direction = opts.direction,
		position = opts.position,
		primary_hash = nil,
		synthetic = opts.synthetic == true,
		synthetic_kind = opts.synthetic_kind,
		synthetic_reason = opts.synthetic_reason,
		-- Adapter / create_or_join reason (Attack Audit create_reason).
		create_reason = opts.reason or opts.create_reason,
		collector = opts.collector,
	}
	M.attacks[attack.id] = attack
	debug_emit("create", attack, {
		synthetic = attack.synthetic,
		synthetic_kind = attack.synthetic_kind,
		synthetic_reason = attack.synthetic_reason,
		create_reason = attack.create_reason,
		reason = attack.create_reason,
		collector = attack.collector,
		source_id = attack.source_id,
		source_kind = attack.source and attack.source.kind or nil,
	})
	return attack
end

function M.SetTag(attack, key, value)
	if not attack or not attack.tags then return end
	attack.tags[key] = value
end

function M.GetTag(attack, key)
	if not attack or not attack.tags then return nil end
	return attack.tags[key]
end

function M.SealAttack(attack)
	if not attack or not attack.active or attack.ending then return false end
	if not attack.open_for_members then return false end
	attack.open_for_members = false
	attack.sealed_frame = game_frame()
	debug_emit("seal", attack, { bound_count = attack.bound_count })
	if attack.bound_count <= 0 then
		M.EndAttack(attack, "all_members_unbound")
	end
	return true
end

local function resolve_previous_binding(ent, existing)
	local prev_id = existing and existing.attack_id or nil
	local prev_family = nil
	if prev_id then
		local prev_attack = M.attacks[prev_id]
		prev_family = prev_attack and prev_attack.family or nil
	end
	if not prev_id and ent then
		local d = ent:GetData()
		prev_id = d[DATA_LAST_AID]
		prev_family = d[DATA_LAST_FAMILY]
	end
	return prev_id, prev_family
end

function M.BindMember(attack, ent, opts)
	opts = opts or {}
	if not attack or not ent then return false end
	if not attack.active or attack.ending then return false end
	if not attack.open_for_members and not opts.allow_sealed then return false end

	local hash = GetPtrHash(ent)
	local existing = M.bindings[hash]
	if existing and existing.attack_id == attack.id then
		-- Refresh wrapper pointer for same binding.
		existing.entity = ent
		local rec = attack.bound_members[hash]
		if rec then rec.entity = ent end
		return true, rec
	end
	if existing and existing.attack_id ~= attack.id then
		-- Must Unbind/Rebind explicitly; do not silently steal.
		local prev_id, prev_family = resolve_previous_binding(ent, existing)
		debug_emit("bind_reject", attack, {
			reason = opts.reason or "bind",
			bind_reason = opts.reason or "bind",
			previous_attack_id = prev_id,
			previous_family = prev_family,
			member = ent,
			member_ptr = hash,
		})
		return false
	end

	local prev_id, prev_family = resolve_previous_binding(ent, existing)
	local d = ent:GetData()
	local generation = (d[DATA_GEN] or 0) + 1
	write_entity_meta(ent, attack.id, generation)
	d[DATA_LAST_AID] = nil
	d[DATA_LAST_FAMILY] = nil

	local record = {
		hash = hash,
		entity = ent,
		generation = generation,
		init_seed = ent.InitSeed,
		bound = true,
		unbound_reason = nil,
		role = opts.role or "primary",
	}
	attack.members[#attack.members + 1] = record
	attack.bound_members[hash] = record
	attack.member_count = #attack.members
	attack.bound_count = (attack.bound_count or 0) + 1
	-- primary / proxy may own primary_hash; derived never becomes primary_hash.
	-- primary_hash may remain nil until a non-derived member binds (legal).
	if not attack.primary_hash and record.role ~= "derived" then
		attack.primary_hash = hash
	end

	M.bindings[hash] = {
		attack_id = attack.id,
		generation = generation,
		init_seed = ent.InitSeed,
		entity = ent,
	}

	local pos = opts.position or ent.Position
	local dir = opts.direction or attack.direction
	local bind_reason = opts.reason or "bind"
	M.dispatch(enums.Callbacks.POST_ATTACK_MEMBER_BOUND, M.make_event(attack, {
		member = ent,
		generation = generation,
		position = pos,
		direction = dir,
		reason = bind_reason,
		previous_attack_id = prev_id,
		previous_family = prev_family,
	}))

	-- First Bind still owns the default Once path for member-bearing Attacks.
	M.EmitAttackOnce(attack, {
		member = ent,
		generation = generation,
		position = pos,
		direction = dir,
		reason = bind_reason,
	})

	return true, record
end

--- Publish POST_ATTACK_ONCE for Attacks that may never Bind a member
--- (e.g. Tecro persistent spear). Idempotent via once_emitted.
--- Sample-kind synthetics suppress Once (same rule as BindMember).
function M.EmitAttackOnce(attack, opts)
	opts = opts or {}
	if not attack or attack.once_emitted then
		return false
	end
	attack.once_emitted = true
	if attack.synthetic_kind == "sample" then
		return false
	end
	M.dispatch(enums.Callbacks.POST_ATTACK_ONCE, M.make_event(attack, {
		member = opts.member,
		generation = opts.generation or 0,
		position = opts.position or attack.position,
		direction = opts.direction or attack.direction,
		reason = opts.reason or "emit_once",
	}))
	return true
end

function M.UnbindHash(hash, reason, ent_hint)
	if hash == nil then return false end
	local binding = M.bindings[hash]
	if not binding then
		if ent_hint then
			pcall(function() M.clear_entity_binding_meta(ent_hint) end)
		end
		return false
	end

	local attack = M.attacks[binding.attack_id]
	local generation = binding.generation
	local old_attack = attack
	local ent = ent_hint or binding.entity

	-- Remove from current binding map first.
	M.bindings[hash] = nil
	if attack and attack.bound_members then
		local rec = attack.bound_members[hash]
		if rec then
			rec.bound = false
			rec.unbound_reason = reason or "manual"
			if ent then rec.entity = ent end
			attack.bound_members[hash] = nil
			attack.bound_count = math.max(0, (attack.bound_count or 1) - 1)
		end
	end

	M.dispatch(enums.Callbacks.POST_ATTACK_MEMBER_UNBOUND, M.make_event(old_attack, {
		attack_id = binding.attack_id,
		member = ent,
		generation = generation,
		reason = reason or "manual",
		player = old_attack and old_attack.player,
		family = old_attack and old_attack.family,
	}))

	if ent then
		pcall(function()
			local d = ent:GetData()
			d[DATA_LAST_AID] = binding.attack_id
			d[DATA_LAST_FAMILY] = old_attack and old_attack.family or nil
			M.clear_entity_binding_meta(ent)
		end)
	end

	if old_attack and old_attack.active and not old_attack.ending
		and not old_attack.open_for_members
		and (old_attack.bound_count or 0) <= 0
		and reason ~= "attack_end"
		and reason ~= "room_change"
		and reason ~= "sword_melee_hold" then
		M.EndAttack(old_attack, "all_members_unbound")
	end

	return true
end

function M.UnbindMember(ent, reason)
	if not ent then return false end
	local hash = nil
	pcall(function() hash = GetPtrHash(ent) end)
	if not hash then return false end
	return M.UnbindHash(hash, reason, ent)
end

local function now_ms()
	if Isaac and Isaac.GetTime then
		return Isaac.GetTime()
	end
	return 0
end

local function count_bindings()
	local n = 0
	for _ in pairs(M.bindings) do
		n = n + 1
	end
	return n
end

local function count_active_attacks()
	local n = 0
	local members = 0
	for _, attack in pairs(M.attacks) do
		if attack and attack.active and not attack.ending then
			n = n + 1
			members = members + (attack.bound_count or 0)
		end
	end
	return n, members
end

--- Layer 2: binding still points at a dead / invalid entity wrapper.
--- POST_ENTITY_REMOVE GetPtrHash may miss the pre-remove key (Isaac wrapper pitfall).
function M.sweep_dead_bindings()
	local measure = M.measure_maintenance == true
	local t0 = measure and now_ms() or 0
	local n = 0
	for hash, binding in pairs(M.bindings) do
		local ent = binding and binding.entity
		local alive = false
		if ent then
			local ok, exists = pcall(function()
				return auxi.check_all_exists(ent)
			end)
			alive = ok and exists == true
		end
		if not alive then
			n = n + 1
			dead_binding_buffer[n] = hash
		end
	end
	for i = 1, n do
		M.UnbindHash(dead_binding_buffer[i], "member_gone")
		dead_binding_buffer[i] = nil
	end
	if measure then
		local dt = math.max(0, now_ms() - t0)
		local st = M.maintenance_stats
		st.dead_last_ms = dt
		if dt > (st.dead_max_ms or 0) then
			st.dead_max_ms = dt
		end
		st.bindings_count = count_bindings()
		local ac, mc = count_active_attacks()
		st.active_attack_count = ac
		st.bound_member_count = mc
	end
end

--- Layer 3: repair bindings ↔ attack.bound_members mismatch (safety net, not hot path).
function M.sweep_registry_integrity()
	local measure = M.measure_maintenance == true
	local t0 = measure and now_ms() or 0
	for _, attack in pairs(M.attacks) do
		if attack and attack.active and attack.bound_members then
			local orphan_n = 0
			for hash, _ in pairs(attack.bound_members) do
				if not M.bindings[hash] then
					orphan_n = orphan_n + 1
					integrity_orphan_buffer[orphan_n] = hash
				end
			end
			for i = 1, orphan_n do
				local hash = integrity_orphan_buffer[i]
				integrity_orphan_buffer[i] = nil
				if attack.bound_members[hash] then
					attack.bound_members[hash] = nil
					attack.bound_count = math.max(0, (attack.bound_count or 1) - 1)
				end
			end
			if attack.active and not attack.ending
				and not attack.open_for_members
				and (attack.bound_count or 0) <= 0 then
				M.EndAttack(attack, "all_members_unbound")
			end
		end
	end
	if measure then
		local dt = math.max(0, now_ms() - t0)
		local st = M.maintenance_stats
		st.integrity_last_ms = dt
		if dt > (st.integrity_max_ms or 0) then
			st.integrity_max_ms = dt
		end
		st.bindings_count = count_bindings()
		local ac, mc = count_active_attacks()
		st.active_attack_count = ac
		st.bound_member_count = mc
	end
end

--- Full sync (room boundary / tests). Prefer throttled Layer 2+3 on UPDATE.
function M.sweep_dead_members()
	M.sweep_dead_bindings()
	M.sweep_registry_integrity()
end

function M.set_measure_maintenance(on)
	M.measure_maintenance = on == true
	if not M.measure_maintenance then
		local st = M.maintenance_stats
		st.dead_last_ms = 0
		st.dead_max_ms = 0
		st.integrity_last_ms = 0
		st.integrity_max_ms = 0
	end
end

function M.get_maintenance_stats()
	return M.maintenance_stats
end

function M.RebindMember(attack, ent, opts)
	if not ent then return false end
	local hash = GetPtrHash(ent)
	if M.bindings[hash] then
		M.UnbindMember(ent, "rebind")
	end
	return M.BindMember(attack, ent, opts)
end

--- Validate delayed identity snapshot. Returns attack or nil.
function M.validate_delayed_identity(snap)
	if not snap then return nil end
	local attack = M.attacks[snap.attack_id]
	if not attack then return nil end
	if snap.hash == nil or snap.generation == nil or snap.init_seed == nil then
		return nil
	end
	local binding = M.bindings[snap.hash]
	if binding then
		if binding.attack_id ~= snap.attack_id then return nil end
		if binding.generation ~= snap.generation then return nil end
		if binding.init_seed ~= snap.init_seed then return nil end
	else
		-- Unbound / ended: still allow tombstone Attack lookup for tags if attack exists.
		-- Callers that need live binding should check bound separately.
	end
	return attack
end

function M.capture_member_identity(ent)
	if not ent then return nil end
	local hash = GetPtrHash(ent)
	local binding = M.bindings[hash]
	if not binding then return nil end
	return {
		hash = hash,
		init_seed = binding.init_seed or ent.InitSeed,
		generation = binding.generation,
		attack_id = binding.attack_id,
	}
end

function M.EndAttack(attack, reason)
	if not attack then return false end
	if attack.ending or not attack.active then return false end
	attack.ending = true
	attack.open_for_members = false

	local hashes = {}
	for hash, _ in pairs(attack.bound_members) do
		hashes[#hashes + 1] = hash
	end
	for i = 1, #hashes do
		local rec = attack.bound_members[hashes[i]]
		local ent = rec and rec.entity
		if ent then
			M.UnbindMember(ent, reason or "attack_end")
		else
			-- Orphan record: drop without entity callback.
			attack.bound_members[hashes[i]] = nil
			attack.bound_count = math.max(0, (attack.bound_count or 1) - 1)
			M.bindings[hashes[i]] = nil
		end
	end

	M.dispatch(enums.Callbacks.POST_ATTACK_END, M.make_event(attack, {
		reason = reason or "manual",
	}))

	attack.active = false
	attack.ended_frame = game_frame()
	return true
end

function M.EndAllAttacks(reason)
	local ids = {}
	for id, attack in pairs(M.attacks) do
		if attack.active then
			ids[#ids + 1] = id
		end
	end
	for i = 1, #ids do
		M.EndAttack(M.attacks[ids[i]], reason or "manual")
	end
end

function M.tick_tombstones()
	local frame = game_frame()
	local drop = {}
	for id, attack in pairs(M.attacks) do
		if not attack.active and attack.ended_frame
			and (frame - attack.ended_frame) >= M.TOMBSTONE_FRAMES then
			drop[#drop + 1] = id
		end
	end
	for i = 1, #drop do
		M.attacks[drop[i]] = nil
	end
	-- Expire recent damage remembers.
	local drop_h = {}
	for hash, rec in pairs(M.recent_damage) do
		if not rec.expire_frame or rec.expire_frame < frame then
			drop_h[#drop_h + 1] = hash
		end
	end
	for i = 1, #drop_h do
		local rec = M.recent_damage[drop_h[i]]
		M.recent_damage[drop_h[i]] = nil
		if rec and rec.init_seed and M.recent_damage_seed[rec.init_seed] == rec then
			M.recent_damage_seed[rec.init_seed] = nil
		end
	end
	local drop_p = {}
	for ph, rec in pairs(M.recent_player_blasts) do
		if not rec.expire_frame or rec.expire_frame < frame then
			drop_p[#drop_p + 1] = ph
		end
	end
	for i = 1, #drop_p do
		M.recent_player_blasts[drop_p[i]] = nil
	end
end

--- Remember member identity briefly so explosion damage after ENTITY_REMOVE still resolves.
function M.remember_for_damage(ent, attack, generation)
	if not ent or not attack then return end
	local hash = GetPtrHash(ent)
	local seed = ent.InitSeed
	local rec = {
		attack_id = attack.id,
		generation = generation,
		init_seed = seed,
		expire_frame = game_frame() + M.DAMAGE_REMEMBER_FRAMES,
	}
	M.recent_damage[hash] = rec
	if seed then
		M.recent_damage_seed[seed] = rec
	end
end

--- Epic/Dr: explosion Source is often the player. Remember by player for a short window.
function M.remember_player_blast(player, attack, generation, position)
	if not player or not attack then return end
	local ph = GetPtrHash(player)
	M.recent_player_blasts[ph] = {
		attack_id = attack.id,
		generation = generation,
		init_seed = nil,
		position = position and Vector(position.X, position.Y) or nil,
		family = attack.family,
		expire_frame = game_frame() + M.PLAYER_BLAST_REMEMBER_FRAMES,
	}
end

function M.clear_player_blast_for_attack(player, attack_id)
	if not player or attack_id == nil then return end
	local ph = GetPtrHash(player)
	local rec = M.recent_player_blasts[ph]
	if rec and rec.attack_id == attack_id then
		M.recent_player_blasts[ph] = nil
	end
end

function M.lookup_recent_for_damage(ent)
	if not ent then return nil, nil end
	local frame = game_frame()
	local hash = GetPtrHash(ent)
	local rec = M.recent_damage[hash]
	if (not rec or rec.expire_frame < frame) and ent.InitSeed then
		rec = M.recent_damage_seed[ent.InitSeed]
		if rec and rec.init_seed ~= ent.InitSeed then
			rec = nil
		end
	end
	if not rec or rec.expire_frame < frame then
		return nil, nil
	end
	local attack = M.attacks[rec.attack_id]
	if not attack then
		return nil, nil
	end
	return attack, rec
end

function M.lookup_recent_player_blast(player, position)
	if not player then return nil, nil end
	local frame = game_frame()
	local rec = M.recent_player_blasts[GetPtrHash(player)]
	if not rec or not rec.expire_frame or rec.expire_frame < frame then
		return nil, nil
	end
	local attack = M.attacks[rec.attack_id]
	if not attack then
		return nil, nil
	end
	-- Optional proximity gate: skip if blast pos known and target is far (room-wide non-epic).
	if position and rec.position and rec.family == "epic" then
		local dist = position:Distance(rec.position)
		if dist > 120 then
			return nil, nil
		end
	end
	return attack, rec
end

function M.reset_all()
	M.EndAllAttacks("manual")
	M.attacks = {}
	M.bindings = {}
	M.recent_damage = {}
	M.recent_damage_seed = {}
	M.recent_player_blasts = {}
	M.next_id = 0
end

return M
