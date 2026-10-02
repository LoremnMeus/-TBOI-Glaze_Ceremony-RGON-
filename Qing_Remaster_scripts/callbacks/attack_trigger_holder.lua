-- Attack Trigger Holder: public API + module wiring.
-- tear_trigger_holder is a retired shim (M8); Attack semantics live here.
local registry = require("Qing_Remaster_scripts.callbacks.attack_registry")
local grouping = require("Qing_Remaster_scripts.callbacks.attack_grouping")
local dps = require("Qing_Remaster_scripts.callbacks.attack_dps_sampler")
local damage_binding = require("Qing_Remaster_scripts.callbacks.attack_damage_binding")
local adapters = require("Qing_Remaster_scripts.callbacks.attack_weapon_adapters")
local classifier = require("Qing_Remaster_scripts.callbacks.attack_source_classifier")
local fire_context = require("Qing_Remaster_scripts.callbacks.attack_fire_context")
local aim_resolver = require("Qing_Remaster_scripts.callbacks.attack_aim_resolver")
local env = require("Qing_Remaster_scripts.core.dev_environment")

local item = {
	ToCall = {},
	myToCall = {},
	post_myToCall = {},
	own_key = registry.own_key,
	registry = registry,
	grouping = grouping,
	dps = dps,
	classifier = classifier,
	aim_resolver = aim_resolver,
	fire_context = fire_context,
}

-- Re-export registry API.
item.SetDebugObserver = registry.SetDebugObserver
item.CreateAttack = registry.CreateAttack
item.BindMember = registry.BindMember
item.AddMember = registry.BindMember -- alias; respects open_for_members
item.UnbindMember = registry.UnbindMember
item.UnbindHash = registry.UnbindHash
item.EmitAttackOnce = registry.EmitAttackOnce
item.sweep_dead_members = registry.sweep_dead_members
item.sweep_dead_bindings = registry.sweep_dead_bindings
item.sweep_registry_integrity = registry.sweep_registry_integrity
item.set_measure_maintenance = registry.set_measure_maintenance
item.get_maintenance_stats = registry.get_maintenance_stats
item.RebindMember = registry.RebindMember
item.GetAttack = registry.GetAttack
item.GetAttackForMember = registry.GetAttackForMember
item.SealAttack = registry.SealAttack
item.EndAttack = registry.EndAttack
item.SetTag = registry.SetTag
item.GetTag = registry.GetTag
item.capture_member_identity = registry.capture_member_identity
item.validate_delayed_identity = registry.validate_delayed_identity
item.make_event = registry.make_event
item.dispatch = registry.dispatch
item.remember_for_damage = registry.remember_for_damage
item.lookup_recent_for_damage = registry.lookup_recent_for_damage
item.remember_player_blast = registry.remember_player_blast
item.lookup_recent_player_blast = registry.lookup_recent_player_blast

-- Source whitelist / proxy inherit / spawn context (see attack_source_classifier).
item.MarkIgnore = classifier.MarkIgnore
item.IsIgnored = classifier.IsIgnored
item.MarkProxy = function(ent, attack, opts)
	if attack then
		return classifier.BindProxy(attack, ent, opts)
	end
	if ent then
		ent:GetData()[classifier.DATA_PROXY_MARK] = true
	end
	return true
end
item.BindProxy = classifier.BindProxy
item.BindDerived = classifier.BindDerived
item.InheritAttack = classifier.InheritAttack
item.ResolveParentAttack = classifier.ResolveParentAttack
item.ResolveCandidate = classifier.ResolveCandidate
item.ClassifyEmitter = classifier.ClassifyEmitter
item.IsMimicFamiliar = classifier.IsMimicFamiliar
item.IsPlayerAttackSource = classifier.IsPlayerAttackSource
item.IsIndependentMimicSource = classifier.IsIndependentMimicSource
item.SourceCanConsume = classifier.SourceCanConsume
item.CanConsumerUseAttack = classifier.CanConsumerUseAttack
item.IsSyntheticSampleAttack = classifier.IsSyntheticSampleAttack
item.GetPreferredAimEntity = classifier.GetPreferredAimEntity
item.GetPreferredAimDirection = classifier.GetPreferredAimDirection
item.GetAttackAimContext = aim_resolver.GetAttackAimContext
item.GetPlayerAimDirection = classifier.GetPlayerAimDirection
item.RegisterSourceCapabilityResolver = classifier.RegisterSourceCapabilityResolver
item.GetAttackOwnerPlayer = classifier.GetAttackOwnerPlayer
item.IsReactiveFamiliar = classifier.IsReactiveFamiliar
item.WithSpawnContext = classifier.WithSpawnContext
item.PushSpawnContext = classifier.PushSpawnContext
item.PopSpawnContext = classifier.PopSpawnContext
item.WithFireContext = fire_context.With
item.PushFireContext = fire_context.Push
item.PopFireContext = fire_context.Pop
item.PeekFireContext = fire_context.Peek
item.GetTagsForMember = function(ent)
	local attack = select(1, registry.GetAttackForMember(ent))
	return attack and attack.tags or nil, attack
end

--- Copy current Peek Fire Context into a fresh opts table for holder.Fire* (never mutate Peek).
--- Returns nil when no context is active.
--- Internal: `_copied_fire_context_token` enables with_fire same-context fast path (not gameplay metadata).
function item.CopyFireContext(reason, overrides)
	local ctx = fire_context.Peek()
	if not ctx then
		return nil
	end
	local ret = {
		mode = ctx.mode,
		attack = ctx.attack,
		attack_id = ctx.attack_id or (ctx.attack and ctx.attack.id),
		emitter = ctx.emitter,
		role = ctx.role,
		reason = reason or ctx.reason,
		source = ctx.source,
		source_id = ctx.source_id,
		source_desc = ctx.source_desc,
		family = ctx.family,
		_copied_fire_context_token = ctx.token,
	}
	if type(overrides) == "table" then
		for k, v in pairs(overrides) do
			ret[k] = v
		end
	end
	return ret
end

------------------------------------------------------------------------
-- Explicit Fire API (mode required). Adapters Peek fire_context during callbacks.
------------------------------------------------------------------------

local warned_missing_mode = false
local warned_bad_inherit = false
local warned_missing_parent = {}
local warned_parent_conflict = {}

-- opts.Source may name an *intermediate* emitter (Tear/Knife/…).
-- Legacy alias opts.source_entity is deprecated — prefer opts.Source / opts.emitter / opts.source.
-- Isaac Fire* Spawner must be a friendly-fire owner (player or mimic familiar);
-- otherwise Tech/TechX (esp. at player.Position) can self-damage.
-- Intermediate provenance is kept on Parent after spawn so get_immediate_emitter still walks the chain.
local function is_friendly_fire_owner(ent)
	if not ent then return false end
	if ent.ToPlayer and ent:ToPlayer() then return true end
	if classifier.IsMimicFamiliar(ent) then return true end
	return false
end

local function same_entity(a, b)
	if not a or not b then return false end
	return GetPtrHash(a) == GetPtrHash(b)
end

local function resolve_friendly_owner(player, opts)
	opts = opts or {}
	local attack = opts.attack
	if attack and attack.source and classifier.IsIndependentMimicSource(attack.source) and attack.source.entity then
		return attack.source.entity
	end
	if attack and attack.player then
		return attack.player
	end
	return player
end

--- @return engine_spawner Entity|nil, intermediate Entity|nil
local function resolve_fire_source_chain(player, opts)
	opts = opts or {}
	-- Canonical: opts.Source. opts.source_entity is legacy alias only.
	local requested = opts.Source
	if requested == nil then
		requested = opts.source_entity
	end
	local emitter = opts.emitter
	local engine = nil
	local intermediate = nil

	if requested ~= nil then
		if is_friendly_fire_owner(requested) then
			engine = requested
		else
			intermediate = requested
			engine = resolve_friendly_owner(player, opts)
		end
	end

	-- Keep Attack emitter as Parent chain when Source was already the owner (or nil).
	if intermediate == nil and emitter ~= nil and not is_friendly_fire_owner(emitter) then
		if engine == nil or not same_entity(emitter, engine) then
			intermediate = emitter
		end
	end

	return engine, intermediate
end

local function warn_parent_conflict_once(ent, existing, intermediate)
	if env.is_public_release and env.is_public_release() then return end
	local key = tostring(ent and GetPtrHash(ent) or "?")
		.. ":"
		.. tostring(existing and GetPtrHash(existing) or "?")
		.. ":"
		.. tostring(intermediate and GetPtrHash(intermediate) or "?")
	if warned_parent_conflict[key] then return end
	warned_parent_conflict[key] = true
	Isaac.DebugString(string.format(
		"[Qing AttackFire] Parent conflict: keep existing Parent=%s Type=%s; skip intermediate=%s Type=%s",
		tostring(existing and GetPtrHash(existing)),
		tostring(existing and existing.Type),
		tostring(intermediate and GetPtrHash(intermediate)),
		tostring(intermediate and intermediate.Type)
	))
end

local function apply_intermediate_parent(ent, intermediate, engine_spawner)
	if not ent or not intermediate then return ent end
	if same_entity(intermediate, engine_spawner) then return ent end
	local parent = ent.Parent
	if parent == nil
		or same_entity(parent, engine_spawner)
		or is_friendly_fire_owner(parent)
	then
		-- Nil or only friendly owner → attach intermediate (Trisagion / Tech IX chain).
		ent.Parent = intermediate
		return ent
	end
	if same_entity(parent, intermediate) then
		return ent
	end
	-- Another non-owner intermediate already set — do not silently overwrite.
	warn_parent_conflict_once(ent, parent, intermediate)
	return ent
end

local function fire_with_source_chain(player, opts, fire_fn)
	local engine, intermediate = resolve_fire_source_chain(player, opts)
	local ent = fire_fn(engine)
	return apply_intermediate_parent(ent, intermediate, engine)
end

-- Perf (only when registry.measure_maintenance): Holder Fire call / nested Push / fast reuse.
local fire_perf = {
	calls = 0,
	nested_pushes = 0,
	fast_reused = 0,
}

function item.reset_fire_perf_stats()
	fire_perf.calls = 0
	fire_perf.nested_pushes = 0
	fire_perf.fast_reused = 0
end

function item.get_fire_perf_stats()
	return fire_perf
end

local function note_fire_perf(reused)
	if registry.measure_maintenance ~= true then
		return
	end
	fire_perf.calls = fire_perf.calls + 1
	if reused then
		fire_perf.fast_reused = fire_perf.fast_reused + 1
	else
		fire_perf.nested_pushes = fire_perf.nested_pushes + 1
	end
end

local function warn_once(flag_name, msg)
	if flag_name == "mode" then
		if warned_missing_mode then return end
		warned_missing_mode = true
	elseif flag_name == "inherit" then
		if warned_bad_inherit then return end
		warned_bad_inherit = true
	end
	Isaac.DebugString("[Qing AttackFire] " .. tostring(msg))
end

--- Dev-only once-per-key warning when a child weapon expected a parent Attack but found none.
function item.warn_missing_parent_once(key, msg)
	if env.is_public_release and env.is_public_release() then return end
	key = tostring(key or "missing_parent")
	if warned_missing_parent[key] then return end
	warned_missing_parent[key] = true
	Isaac.DebugString("[Qing AttackHolder] " .. tostring(msg))
end

local function resolve_parent_attack_from_opts(opts)
	if opts.attack and opts.attack.active and not opts.attack.ending then
		return opts.attack
	end
	if opts.attack_id then
		local a = registry.GetAttack(opts.attack_id)
		if a and a.active and not a.ending then
			return a
		end
	end
	if opts.emitter then
		local a = select(1, registry.GetAttackForMember(opts.emitter))
		if a and a.active and not a.ending then
			return a
		end
	end
	return nil
end

--- Validate opts.mode; returns mode string (may coerce missing/bad to untracked in release).
local function require_fire_mode(opts, api_name)
	opts = opts or {}
	local mode = opts.mode
	if fire_context.is_valid_mode(mode) then
		return mode, opts
	end
	local msg = (api_name or "Fire*") .. " requires opts.mode = new_attack|inherit|untracked"
	if env.is_public_release() then
		warn_once("mode", msg .. "; treating as untracked")
		opts.mode = "untracked"
		return "untracked", opts
	end
	error(msg)
end

local function build_fire_ctx(player, family, opts, mode)
	local attack = nil
	if mode == "inherit" then
		attack = resolve_parent_attack_from_opts(opts)
		if not attack then
			local msg = "Fire* mode=inherit but parent Attack missing/ended"
			if env.is_public_release() then
				warn_once("inherit", msg .. "; treating as untracked")
				mode = "untracked"
			else
				error(msg)
			end
		end
	end

	-- new_attack source: only EntityPlayer or mimic whitelist Familiar.
	-- Holder always builds source_desc via classifier; reject forged tables / foreign entities.
	local source = nil
	local source_id = nil
	local source_desc = nil
	if mode == "new_attack" then
		source = opts.source or player
		if source and classifier.IsMimicFamiliar(source) then
			local owner = classifier.resolve_owner_player(source) or player
			source_desc = classifier.make_mimic_source(source, owner)
			source_id = source_desc.source_id
		elseif source and source.ToPlayer and source:ToPlayer() then
			source = source:ToPlayer()
			source_desc = classifier.make_player_source(source)
			source_id = source_desc.source_id
		elseif player and player.ToPlayer and player:ToPlayer() then
			source = player:ToPlayer() or player
			source_desc = classifier.make_player_source(source)
			source_id = source_desc.source_id
		else
			local msg = "Fire* mode=new_attack requires EntityPlayer or mimic familiar source"
			if env.is_public_release() then
				warn_once("mode", msg .. "; treating as untracked")
				mode = "untracked"
				source = nil
				source_id = nil
				source_desc = nil
			else
				error(msg)
			end
		end
	elseif attack then
		source_id = attack.source_id
		source_desc = attack.source
		source = attack.player
	end

	local role = opts.role
	if not role then
		if mode == "inherit" then
			role = "derived"
		elseif mode == "new_attack" then
			role = "primary"
		end
	end

	return {
		mode = mode,
		attack = attack,
		attack_id = attack and attack.id or opts.attack_id,
		emitter = opts.emitter,
		emitter_hash = opts.emitter and GetPtrHash(opts.emitter) or nil,
		source = source,
		source_entity = source,
		source_id = source_id,
		source_desc = source_desc,
		family = family or opts.family,
		role = role,
		reason = opts.reason or ("fire_" .. tostring(mode)),
	}, mode
end

--- True when opts was CopyFireContext'd from the current stack top and core Attack
--- semantics were not overridden (reason/family may differ; do not force-equal family).
local function can_reuse_top_context(top, opts)
	if not top or not opts then
		return false
	end
	if opts._copied_fire_context_token ~= top.token then
		return false
	end
	if opts.mode ~= top.mode then
		return false
	end
	if opts.attack ~= top.attack then
		return false
	end
	local opts_attack_id = opts.attack_id or (opts.attack and opts.attack.id)
	local top_attack_id = top.attack_id or (top.attack and top.attack.id)
	if opts_attack_id ~= top_attack_id then
		return false
	end
	if opts.emitter ~= top.emitter then
		return false
	end
	if opts.role ~= top.role then
		return false
	end
	if opts.source_id ~= top.source_id then
		return false
	end
	return true
end

local function with_fire(player, family, opts, api_name, fn)
	local mode
	mode, opts = require_fire_mode(opts, api_name)
	local top = fire_context.Peek()
	if can_reuse_top_context(top, opts) then
		note_fire_perf(true)
		return fn()
	end
	note_fire_perf(false)
	local ctx
	ctx, mode = build_fire_ctx(player, family, opts, mode)
	return fire_context.With(ctx, fn)
end

--- EntityPlayer:FireTear wrapper. opts.mode required.
function item.FireTear(player, position, velocity, opts)
	opts = opts or {}
	return with_fire(player, opts.family or "tear", opts, "FireTear", function()
		local can_be_eye = true
		if opts.can_be_eye ~= nil then
			can_be_eye = opts.can_be_eye
		elseif opts.CanBeEye ~= nil then
			can_be_eye = opts.CanBeEye
		end
		local no_tracer = opts.no_tracer == true or opts.NoTractorBeam == true
		local streak = true
		if opts.can_trigger_streak_end ~= nil then
			streak = opts.can_trigger_streak_end
		elseif opts.CanTriggerStreakEnd ~= nil then
			streak = opts.CanTriggerStreakEnd
		end
		return fire_with_source_chain(player, opts, function(engine_source)
			return player:FireTear(
				position,
				velocity,
				can_be_eye,
				no_tracer,
				streak,
				engine_source,
				opts.damage_multiplier or opts.DamageMultiplier or 1
			)
		end)
	end)
end

--- EntityPlayer:FireTechLaser wrapper. opts.mode required.
function item.FireTechLaser(player, position, direction, opts)
	opts = opts or {}
	return with_fire(player, opts.family or "technology", opts, "FireTechLaser", function()
		return fire_with_source_chain(player, opts, function(engine_source)
			return player:FireTechLaser(
				position,
				opts.offset_id or opts.OffsetID or 0,
				direction,
				opts.left_eye == true or opts.LeftEye == true,
				opts.one_hit == true or opts.OneHit == true,
				engine_source,
				opts.damage_multiplier or opts.DamageMultiplier or 1
			)
		end)
	end)
end

item.FireLaser = item.FireTechLaser

--- EntityPlayer:FireBrimstone wrapper. opts.mode required.
--- Signature mirrors engine: FireBrimstone(Direction, Source?, DamageMultiplier?).
--- nil damage_multiplier = omit / engine default (do not coerce to 1).
function item.FireBrimstone(player, direction, opts)
	opts = opts or {}
	return with_fire(player, opts.family or "brimstone", opts, "FireBrimstone", function()
		return fire_with_source_chain(player, opts, function(engine_source)
			local dmg_mul = opts.damage_multiplier
			if dmg_mul == nil then
				dmg_mul = opts.DamageMultiplier
			end
			return player:FireBrimstone(
				direction,
				engine_source,
				dmg_mul
			)
		end)
	end)
end

--- EntityPlayer:FireTechXLaser wrapper. opts.mode required.
function item.FireTechXLaser(player, position, direction, radius, opts)
	opts = opts or {}
	return with_fire(player, opts.family or "techx", opts, "FireTechXLaser", function()
		return fire_with_source_chain(player, opts, function(engine_source)
			return player:FireTechXLaser(
				position,
				direction,
				radius,
				engine_source or player,
				opts.damage_multiplier or opts.DamageMultiplier or 1
			)
		end)
	end)
end

--- EntityPlayer:FireBomb wrapper. opts.mode required.
--- Docs: FireBomb(Position, Velocity, Source?).
function item.FireBomb(player, position, velocity, opts)
	opts = opts or {}
	return with_fire(player, opts.family or "bomb", opts, "FireBomb", function()
		return fire_with_source_chain(player, opts, function(engine_source)
			return player:FireBomb(
				position,
				velocity,
				engine_source
			)
		end)
	end)
end

--- EntityPlayer:FireKnife wrapper. opts.mode required.
--- Docs: FireKnife(Parent, RotationOffset?, CantOverwrite?, SubType?, Variant?).
--- Call as FireKnife(player, parent_ent, opts) — parent is the knife handle / Nil / player.
function item.FireKnife(player, parent, opts)
	opts = opts or {}
	return with_fire(player, opts.family or "knife", opts, "FireKnife", function()
		return player:FireKnife(
			parent,
			opts.rotation_offset or opts.RotationOffset or 0,
			opts.cant_overwrite == true or opts.CantOverwrite == true,
			opts.subtype or opts.SubType or 0,
			opts.variant or opts.Variant or 0
		)
	end)
end

------------------------------------------------------------------------
-- Synthetic / extra DPS sample (M8.1): proc opportunity without POST_ATTACK_ONCE.
------------------------------------------------------------------------

--- Append one normalized DPS sample to an existing Attack. Does not Create / Bind / Once.
function item.EmitDpsSample(attack, ent, opts)
	opts = opts or {}
	if not attack or not attack.active or attack.ending then
		return false
	end
	dps.emit_sample(attack, ent, {
		generation = opts.generation,
		position = opts.position or (ent and ent.Position),
		direction = opts.direction,
		sample_weight = opts.sample_weight or 1,
		reason = opts.reason or "synthetic_existing_attack",
	})
	return true
end

--- No parent Attack: Create synthetic sample Attack → DPS_SAMPLE → Seal (no Bind / no Once).
--- Derived members from DPS consumers may keep the Attack alive after Seal until unbound.
function item.EmitSyntheticSample(player, opts)
	opts = opts or {}
	if not player then return nil end

	local family = opts.family or "tear"
	local source = classifier.make_player_source(player)
	local attack = registry.CreateAttack(player, family, {
		source = source,
		source_id = source and source.source_id,
		position = opts.position or player.Position,
		direction = opts.direction,
		synthetic = true,
		synthetic_kind = opts.synthetic_kind or "sample",
		synthetic_reason = opts.reason or "synthetic_sample",
	})
	if not attack then
		return nil
	end

	-- Synthetic sample must never emit POST_ATTACK_ONCE, including derived binds
	-- during the DPS_SAMPLE callback window.
	attack.once_emitted = true

	item.EmitDpsSample(attack, opts.source_entity, {
		position = opts.position,
		direction = opts.direction,
		sample_weight = opts.sample_weight or 1,
		reason = opts.reason or "synthetic_sample",
	})

	registry.SealAttack(attack)
	return attack
end

local function merge_calls(dst, src)
	if not src then return end
	for i = 1, #src do
		dst[#dst + 1] = src[i]
	end
end

merge_calls(item.ToCall, adapters.ToCall)
merge_calls(item.myToCall, adapters.myToCall)
merge_calls(item.ToCall, damage_binding.ToCall)

return item
