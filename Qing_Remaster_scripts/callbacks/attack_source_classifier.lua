-- Attack source classification: player / mimic whitelist / proxy inherit / ignore.
-- Does not invent Familiar capability; whitelist lives in familiar_attack_classification.
-- Explicit Fire semantics live in attack_fire_context; SpawnContext APIs forward there.
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")
local registry = require("Qing_Remaster_scripts.callbacks.attack_registry")
local fam_class = require("Qing_Remaster_scripts.mimics.familiar_attack_classification")
local fire_context = require("Qing_Remaster_scripts.callbacks.attack_fire_context")
local enums = require("Qing_Remaster_scripts.core.enums")

local M = {
	own_key = "attack_source_classifier_",
	-- Explicit opt-out on entity GetData (MarkIgnore / Fire Context untracked).
	DATA_IGNORE = "attack_ignore",
	DATA_PROXY_MARK = "attack_proxy_mark",
}

local EVIL_EYE_VARIANT = (EffectVariant and EffectVariant.EVIL_EYE) or 84

--- Qing MeusFetus / MeusRocket / vanilla Epic TARGET+ROCKET: Attack lifecycle carriers (proxy).
function M.is_epic_lifecycle_entity(ent)
	if not ent or ent.Type ~= EntityType.ENTITY_EFFECT then return false end
	local v = ent.Variant or -1
	if enums.Entities.ID_EFFECT_MeusFetus and v == enums.Entities.ID_EFFECT_MeusFetus then
		return true
	end
	if enums.Entities.ID_EFFECT_MeusRocket and v == enums.Entities.ID_EFFECT_MeusRocket then
		return true
	end
	if EffectVariant and v == EffectVariant.ROCKET then return true end
	if EffectVariant and EffectVariant.SMALL_ROCKET and v == EffectVariant.SMALL_ROCKET then
		return true
	end
	if EffectVariant and v == EffectVariant.TARGET then return true end
	return false
end

-- Must be declared before IsCraftAttackFamiliar / IsMimicFamiliar (Lua local forward refs are nil).
-- Use lightweight craft_identity — never require Item_Air_Flight / Item_Blue_Print (cycle + wrong key).
local CraftIdentity = require("Qing_Remaster_scripts.mimics.craft_identity")

function M.GetCraftUid(ent)
	return CraftIdentity.get_uid(ent)
end

--- Blueprint / Air Flight craft familiar (has craft_uid): independent Attack source.
function M.IsCraftAttackFamiliar(ent)
	if not ent or ent.Type ~= EntityType.ENTITY_FAMILIAR then
		return false
	end
	return CraftIdentity.get_uid(ent) ~= nil
end

function M.IsMimicFamiliar(ent)
	return fam_class.is_player_attack_mimic(ent) or M.IsCraftAttackFamiliar(ent)
end

function M.IsReactiveFamiliar(ent)
	return fam_class.is_reactive_familiar(ent)
end

--- Canonical source.kind: "attack_mimic" (legacy "mimic_familiar" accepted by helpers).
function M.NormalizeSourceKind(kind)
	if kind == "mimic_familiar" then
		return "attack_mimic"
	end
	return kind
end

function M.IsPlayerAttackSource(source)
	return source ~= nil and source.kind == "player"
end

function M.IsIndependentMimicSource(source)
	if not source then return false end
	local k = M.NormalizeSourceKind(source.kind)
	return k == "attack_mimic"
end

function M.GetAttackOwnerPlayer(attack)
	if not attack then return nil end
	if attack.player then return attack.player end
	local source = attack.source
	if source and source.owner_player then return source.owner_player end
	if source and source.entity and source.entity.ToPlayer then
		local p = source.entity:ToPlayer()
		if p then return p end
	end
	return nil
end

--- Aim / control entity for direction (not the same as logical Attack source).
function M.GetPreferredAimEntity(source, attack, event)
	if source then
		if M.IsPlayerAttackSource(source) then
			return source.entity or source.owner_player
		end
		if M.IsIndependentMimicSource(source) then
			return source.entity
		end
	end
	if event and event.member then
		return event.member
	end
	if attack and attack.primary_hash and attack.bound_members then
		local rec = attack.bound_members[attack.primary_hash]
		if rec and rec.entity then return rec.entity end
	end
	return nil
end

--- Soft player aim: ShootingInput → AimDirection → FireDirection → +X.
--- Prefer GetAttackAimContext for Attack Trigger derived fire.
function M.GetPlayerAimDirection(player)
	if player == nil then
		return Vector(1, 0)
	end
	local dir = Vector(0, 0)
	if player.GetShootingInput then
		dir = player:GetShootingInput()
	end
	if (not dir or dir:Length() < 0.01) and player.GetAimDirection then
		dir = player:GetAimDirection()
	end
	if not dir or dir:Length() < 0.01 then
		local fire_dir = player.GetFireDirection and player:GetFireDirection() or nil
		if fire_dir == Direction.LEFT then
			dir = Vector(-1, 0)
		elseif fire_dir == Direction.RIGHT then
			dir = Vector(1, 0)
		elseif fire_dir == Direction.UP then
			dir = Vector(0, -1)
		elseif fire_dir == Direction.DOWN then
			dir = Vector(0, 1)
		else
			dir = Vector(1, 0)
		end
	end
	if dir:Length() < 0.01 then
		dir = Vector(1, 0)
	end
	return dir:Normalized()
end

--- Compatibility wrapper → attack_aim_resolver.GetAttackAimContext(...).direction
function M.GetPreferredAimDirection(source, attack, event)
	local resolver = require("Qing_Remaster_scripts.callbacks.attack_aim_resolver")
	local ctx = resolver.GetAttackAimContext(source, attack, event)
	return (ctx and ctx.direction) or Vector(1, 0)
end

function M.GetAttackAimContext(source, attack, event)
	local resolver = require("Qing_Remaster_scripts.callbacks.attack_aim_resolver")
	return resolver.GetAttackAimContext(source, attack, event)
end

-- Runtime consumer capability (no cache on Attack / source objects).
local capability_resolvers = {}

function M.RegisterSourceCapabilityResolver(fn)
	if type(fn) ~= "function" then return end
	capability_resolvers[#capability_resolvers + 1] = fn
end

--- “May this factual source consume the named Attack-level consumer?”
--- player → true; attack_mimic → false unless a resolver returns true.
function M.SourceCanConsume(source, key, player, attack)
	if not source or not key then
		return false
	end
	if M.IsPlayerAttackSource(source) then
		return true
	end
	for i = 1, #capability_resolvers do
		local ret = capability_resolvers[i](source, key, player, attack)
		if ret ~= nil then
			return ret == true
		end
	end
	return false
end

function M.CanConsumerUseAttack(consumer_key, attack, player)
	if not attack or not consumer_key then
		return false
	end
	return M.SourceCanConsume(attack.source, consumer_key, player, attack)
end

--- Live craft_profile on an independent mimic / Craft Flight source entity.
--- Returns profile, familiar (or nil, nil). Does not invent counts from Blue_Print alone.
--- Reads CraftIdentity PROFILE_KEY only — never require Item_Air_Flight (cycle risk).
function M.GetCraftProfileFromSource(source)
	if not M.IsIndependentMimicSource(source) then
		return nil, nil
	end
	local fam = source.entity
	if not fam or fam.Type ~= EntityType.ENTITY_FAMILIAR then
		return nil, nil
	end
	if not CraftIdentity.get_uid(fam) then
		return nil, nil
	end
	return CraftIdentity.get_profile(fam), fam
end

--- Recipe collectible count for a Craft Attack source (0 if not craft / missing profile).
function M.GetCraftCollectibleCount(source, collectible_id)
	local id = tonumber(collectible_id)
	if not id or id <= 0 then
		return 0
	end
	local prof = M.GetCraftProfileFromSource(source)
	if not prof or not prof.counts then
		return 0
	end
	local CraftProfile = require("Qing_Remaster_scripts.others.craft_combat_profile")
	return CraftProfile.count_of(prof.counts, id)
end

--- Aquarius / Dark Art sample: no Once; Once-consumers must skip.
--- Ludo cadence (`synthetic_kind="ludo"`) still emits Once and is consumable (like Bone Club rounds).
function M.IsSyntheticSampleAttack(attack)
	return attack ~= nil
		and attack.synthetic == true
		and attack.synthetic_kind == "sample"
end

function M.is_evil_eye_effect(ent)
	return ent
		and ent.Type == EntityType.ENTITY_EFFECT
		and (ent.Variant or -1) == EVIL_EYE_VARIANT
end

function M.is_fetus_tear(ent)
	if not ent or ent.Type ~= EntityType.ENTITY_TEAR then return false end
	-- C Section uses TearVariant.FETUS (50); flag TEAR_FETUS (114) may arrive later than POST_FIRE_TEAR.
	if TearVariant and TearVariant.FETUS and ent.Variant == TearVariant.FETUS then
		return true
	end
	if ent.Variant == 50 then
		return true
	end
	local flag = TearFlags and TearFlags.TEAR_FETUS
	if flag then
		if ent.HasTearFlags then
			local ok, hit = pcall(function() return ent:HasTearFlags(flag) end)
			if ok and hit == true then return true end
		end
		if ent.TearFlags and (ent.TearFlags & flag) == flag then
			return true
		end
	end
	-- Bit 114 without TearFlags enum (auxi.fire_fetus style).
	if ent.TearFlags then
		local bit114 = BitSet128(0, 1 << (114 - 64))
		if (ent.TearFlags & bit114) == bit114 then return true end
	end
	return false
end

function M.is_lasershot_tear(ent)
	if not ent or ent.Type ~= EntityType.ENTITY_TEAR then return false end
	local flag = TearFlags and TearFlags.TEAR_LASERSHOT
	if not flag then return false end
	if ent.HasTearFlags then
		local ok, hit = pcall(function() return ent:HasTearFlags(flag) end)
		if ok and hit == true then return true end
	end
	if ent.TearFlags then
		return (ent.TearFlags & flag) == flag
	end
	return false
end

--- Evil Eye / C Section fetus / Epic TARGET·rocket·MeusFetus: long-lived Attack carriers.
function M.is_proxy_entity(ent)
	if not ent then return false end
	if ent:GetData()[M.DATA_PROXY_MARK] == true then return true end
	if M.is_evil_eye_effect(ent) then return true end
	if M.is_fetus_tear(ent) then return true end
	if M.is_epic_lifecycle_entity(ent) then return true end
	return false
end

--- Carriers whose children should inherit the same Attack (fetus / evil eye / Trisagion / Epic).
function M.is_attack_carrier(ent)
	if not ent then return false end
	if M.is_proxy_entity(ent) then return true end
	if M.is_lasershot_tear(ent) then return true end
	return false
end

function M.MarkIgnore(ent)
	if not ent then return end
	ent:GetData()[M.DATA_IGNORE] = true
end

function M.IsIgnored(ent)
	if not ent then return true end
	local d = ent:GetData()
	if d[M.DATA_IGNORE] == true then return true end
	-- Explicit Fire Context wins.
	local ctx = fire_context.Peek()
	if ctx then
		if ctx.mode == "untracked" or ctx.mode == "ignore" or ctx.attack_ignore == true then
			return true
		end
		if ctx.mode == "new_attack" or ctx.mode == "inherit" then
			return false
		end
	end
	return false
end

-- Legacy compatibility alias.
-- New code must use attack_fire_context / holder Fire API.
function M.PushSpawnContext(ctx)
	return fire_context.Push(ctx)
end

-- Legacy compatibility alias.
-- New code must use attack_fire_context / holder Fire API.
function M.PopSpawnContext(token)
	return fire_context.Pop(token)
end

-- Legacy compatibility alias.
-- New code must use attack_fire_context / holder Fire API.
function M.CurrentSpawnContext()
	return fire_context.Peek()
end

-- Legacy compatibility alias.
-- New code must use attack_fire_context / holder Fire API.
function M.WithSpawnContext(ctx, fn)
	return fire_context.With(ctx, fn)
end

--- Owner player for display / Gospel owner (walk chain). Not sufficient for CreateAttack eligibility.
function M.resolve_owner_player(ent)
	if not ent then return nil end
	if ent:ToPlayer() then return ent:ToPlayer() end
	return auxi.check_spawner_player(ent)
		or auxi.check_near_spawner_player(ent)
		or auxi.check_near_spawner_player(ent, { checklist = { "SpawnerEntity", "Parent" } })
end

function M.player_source_id(player)
	if not player then return "player:nil" end
	return "player:" .. tostring(GetPtrHash(player))
end

function M.mimic_source_id(fam)
	if not fam then return "mimic:nil" end
	local uid = CraftIdentity.get_uid(fam)
	if uid ~= nil then
		return "craft:" .. tostring(uid)
	end
	return string.format(
		"fam:%d:%d:%d",
		fam.Type or 3,
		fam.Variant or 0,
		fam.InitSeed or 0
	)
end

function M.make_player_source(player)
	return {
		kind = "player",
		entity = player,
		source_id = M.player_source_id(player),
		owner_player = player,
	}
end

function M.make_mimic_source(fam, owner_player)
	owner_player = owner_player or M.resolve_owner_player(fam)
	return {
		-- Canonical: attack_mimic. Legacy alias "mimic_familiar" still accepted by helpers.
		kind = "attack_mimic",
		entity = fam,
		source_id = M.mimic_source_id(fam),
		owner_player = owner_player,
	}
end

--- Immediate emitter: prefer tear/carrier / attack_mimic Parent over Spawner=Player
--- (Incubus / Twisted often Spawner=Player with Parent=familiar; Trisagion Spawner=Player, Parent=tear).
function M.get_immediate_emitter(ent)
	if not ent then return nil end
	local parent = ent.Parent
	local spawner = ent.SpawnerEntity
	if parent and M.is_attack_carrier(parent) then
		return parent
	end
	if spawner and M.is_attack_carrier(spawner) then
		return spawner
	end
	-- Any tear Parent/Spawner still beats Player Spawner (flag timing / late LASERSHOT).
	if parent and parent.Type == EntityType.ENTITY_TEAR then
		return parent
	end
	if spawner and spawner.Type == EntityType.ENTITY_TEAR then
		return spawner
	end
	-- Attack-mimic / reactive familiar Parent beats Player Spawner (Incubus FireProjectile).
	if parent and (M.IsMimicFamiliar(parent) or M.IsReactiveFamiliar(parent)) then
		return parent
	end
	if spawner and (M.IsMimicFamiliar(spawner) or M.IsReactiveFamiliar(spawner)) then
		return spawner
	end
	if spawner then return spawner end
	if parent then return parent end
	return nil
end

--- Classify an entity that may be an emitter or the projectile itself.
function M.ClassifyEmitter(ent)
	if not ent then
		return { kind = "unknown" }
	end
	if M.IsIgnored(ent) then
		return { kind = "ignore", entity = ent }
	end
	local as_player = ent:ToPlayer()
	if as_player then
		return {
			kind = "player",
			entity = as_player,
			source = M.make_player_source(as_player),
			owner_player = as_player,
		}
	end
	if M.IsMimicFamiliar(ent) then
		local owner = M.resolve_owner_player(ent)
		return {
			kind = "attack_mimic",
			entity = ent,
			source = M.make_mimic_source(ent, owner),
			owner_player = owner,
		}
	end
	if M.IsReactiveFamiliar(ent) then
		return {
			kind = "reactive_familiar",
			entity = ent,
			owner_player = M.resolve_owner_player(ent),
		}
	end
	if ent.Type == EntityType.ENTITY_FAMILIAR then
		return {
			kind = "other_familiar",
			entity = ent,
			owner_player = M.resolve_owner_player(ent),
		}
	end
	if M.is_proxy_entity(ent) then
		return {
			kind = "proxy",
			entity = ent,
			owner_player = M.resolve_owner_player(ent),
		}
	end
	return {
		kind = "other",
		entity = ent,
		owner_player = M.resolve_owner_player(ent),
	}
end

local function attack_of(ent)
	if not ent then return nil end
	return select(1, registry.GetAttackForMember(ent))
end

local function resolve_parent_attack_depth(ent, depth, use_ctx)
	if not ent or depth <= 0 then return nil, nil end
	if use_ctx then
		local ctx = M.CurrentSpawnContext()
		if ctx and ctx.mode == "inherit" and ctx.attack_id then
			local a = registry.GetAttack(ctx.attack_id)
			if a and a.active and not a.ending then
				return a, "fire_context"
			end
		end
		if ctx and ctx.mode == "inherit" and ctx.attack and ctx.attack.active and not ctx.attack.ending then
			return ctx.attack, "fire_context"
		end
		if ctx and ctx.mode == "inherit" and ctx.emitter then
			local a = attack_of(ctx.emitter)
			if a and a.active and not a.ending then
				return a, "fire_context_emitter"
			end
		end
	end

	-- Prefer carrier Parent/Spawner (fetus / evil eye / Trisagion tear) before Player Spawner.
	local ordered = {}
	local parent = ent.Parent
	local spawner = ent.SpawnerEntity
	if parent and M.is_attack_carrier(parent) then
		ordered[#ordered + 1] = parent
	end
	if spawner and M.is_attack_carrier(spawner) and spawner ~= parent then
		ordered[#ordered + 1] = spawner
	end
	if parent and not M.is_attack_carrier(parent) then
		ordered[#ordered + 1] = parent
	end
	if spawner and not M.is_attack_carrier(spawner) and spawner ~= parent then
		ordered[#ordered + 1] = spawner
	end

	for i = 1, #ordered do
		local p = ordered[i]
		local attack = attack_of(p)
		if attack then
			return attack, p
		end
	end
	for i = 1, #ordered do
		local p = ordered[i]
		if p then
			local attack, via = resolve_parent_attack_depth(p, depth - 1, false)
			if attack then
				return attack, via or p
			end
		end
	end
	return nil, nil
end

--- Parent/Spawner chain already bound to an Attack → inherit.
function M.ResolveParentAttack(ent)
	return resolve_parent_attack_depth(ent, 4, true)
end

--- When engine attributes child weapons to the Player, find a live Attack carrier.
--- near_pos: prefer closest bound fetus / evil-eye / Trisagion (LASERSHOT) tear (default radius 96).
function M.FindLivingProxyAttack(owner_player, near_pos, opts)
	opts = opts or {}
	if not owner_player then return nil, nil end
	local radius = opts.radius or 96
	local ph = GetPtrHash(owner_player)
	local best, best_proxy, best_dist, best_id = nil, nil, nil, -1
	for _, attack in pairs(registry.attacks) do
		if attack and attack.active and not attack.ending
			and attack.player and GetPtrHash(attack.player) == ph then
			for _, rec in pairs(attack.bound_members) do
				local e = rec and rec.entity
				if e and auxi.check_all_exists(e) and M.is_attack_carrier(e) then
					local dist = 0
					if near_pos and e.Position then
						dist = near_pos:Distance(e.Position)
						if dist > radius then
							e = nil
						end
					end
					if e then
						local better = false
						if not best then
							better = true
						elseif near_pos and (best_dist == nil or dist < best_dist) then
							better = true
						elseif (not near_pos or dist == best_dist) and attack.id > best_id then
							better = true
						end
						if better then
							best = attack
							best_proxy = e
							best_dist = dist
							best_id = attack.id
						end
					end
				end
			end
		end
	end
	return best, best_proxy
end

function M.BindProxy(parent_attack, proxy, opts)
	opts = opts or {}
	if not parent_attack or not proxy then return false end
	proxy:GetData()[M.DATA_PROXY_MARK] = true
	return registry.BindMember(parent_attack, proxy, {
		allow_sealed = opts.allow_sealed ~= false,
		role = "proxy",
		reason = opts.reason or "proxy",
		direction = opts.direction,
		position = opts.position,
	})
end

function M.BindDerived(parent_ent, child_ent, opts)
	opts = opts or {}
	if not child_ent then return false end
	local attack = opts.attack or attack_of(parent_ent) or M.ResolveParentAttack(child_ent)
	if not attack then return false end
	local role = opts.role or (M.is_proxy_entity(child_ent) and "proxy") or "derived"
	return registry.BindMember(attack, child_ent, {
		allow_sealed = true,
		role = role,
		reason = opts.reason or "derived",
		direction = opts.direction,
		position = opts.position,
	})
end

function M.InheritAttack(parent_ent, child_ent, role)
	return M.BindDerived(parent_ent, child_ent, { role = role or "derived" })
end

--- Resolve how a weapon callback should treat `ent`.
--- opts.from_fire_callback: true for POST_FIRE_* / weapon-fire semantics (player/mimic create allowed).
function M.ResolveCandidate(ent, family, opts)
	opts = opts or {}
	family = family or "unknown"

	if not ent or M.IsIgnored(ent) then
		return { mode = "ignore", reason = "ignored" }
	end

	local existing = attack_of(ent)
	if existing and not opts.force_new_instance then
		return {
			mode = "already",
			parent_attack = existing,
			owner_player = existing.player,
			source_id = existing.source_id,
			source = existing.source,
		}
	end
	-- force_new_instance: still recover owner/source from a live binding, but do not join it.
	if existing and opts.force_new_instance then
		return {
			mode = "player",
			owner_player = existing.player,
			source_id = existing.source_id,
			source = existing.source,
			reason = "force_new_instance_was_bound",
			previous_attack = existing,
			role_hint = "primary",
		}
	end

	local ctx = M.CurrentSpawnContext()
	if ctx and (ctx.mode == "untracked" or ctx.mode == "ignore") then
		return { mode = "ignore", reason = "fire_context_untracked" }
	end
	-- Explicit Fire Context inherit still applies (fetus-held etc.) unless force_new_instance.
	if ctx and ctx.mode == "inherit" and not opts.force_new_instance then
		local parent = M.ResolveParentAttack(ent)
		if parent then
			return {
				mode = "inherit",
				parent_attack = parent,
				owner_player = parent.player,
				source_id = parent.source_id,
				source = parent.source,
				reason = "fire_context_inherit",
				role_hint = ctx.role or "derived",
			}
		end
		return { mode = "ignore", reason = "fire_context_inherit_missing" }
	end
	if ctx and ctx.mode == "new_attack" then
		-- Explicit new_attack: never rewrite to inherit via Parent/Spawner heuristics.
		local source = ctx.source or ctx.source_entity
		if source and M.IsMimicFamiliar(source) then
			local owner = M.resolve_owner_player(source)
			local src = ctx.source_desc or M.make_mimic_source(source, owner)
			return {
				mode = "mimic",
				source_entity = source,
				source = src,
				source_id = src and src.source_id,
				owner_player = owner,
				role_hint = ctx.role or "primary",
				reason = "fire_context_new_attack",
			}
		end
		local owner = (source and source.ToPlayer and source:ToPlayer()) or (ctx.source_desc and nil)
		if source and source.ToPlayer and source:ToPlayer() then
			owner = source:ToPlayer()
		elseif not owner then
			owner = M.resolve_owner_player(ent)
		end
		if owner then
			local src = ctx.source_desc or M.make_player_source(owner)
			return {
				mode = "player",
				source_entity = owner,
				source = src,
				source_id = src and src.source_id,
				owner_player = owner,
				role_hint = ctx.role or "primary",
				reason = "fire_context_new_attack",
			}
		end
		return { mode = "ignore", reason = "fire_context_new_attack_no_source" }
	end

	local parent_attack, via = M.ResolveParentAttack(ent)
	if parent_attack and not opts.force_new_instance then
		return {
			mode = "inherit",
			parent_attack = parent_attack,
			owner_player = parent_attack.player,
			source_id = parent_attack.source_id,
			source = parent_attack.source,
			via = via,
			reason = "parent_binding",
		}
	end

	-- Proxy entity without parent Attack yet: treat as create-eligible only when fire creates it.
	local emitter = M.get_immediate_emitter(ent)
	local emitter_cls = M.ClassifyEmitter(emitter)
	-- If projectile itself is a proxy (fetus / evil eye), classify the projectile for role later;
	-- eligibility still comes from emitter (player/mimic).
	local self_cls = M.ClassifyEmitter(ent)

	if self_cls.kind == "other_familiar" or emitter_cls.kind == "other_familiar" then
		return {
			mode = "ignore",
			reason = "other_familiar",
			owner_player = self_cls.owner_player or emitter_cls.owner_player,
		}
	end

	-- Non-fire paths (laser init scan, knife update): only inherit or explicit mimic/player emitter.
	local allow_create = opts.from_fire_callback == true or opts.allow_create == true

	-- Child of carrier (fetus / evil eye / Trisagion tear): inherit once carrier is bound.
	if emitter and M.is_attack_carrier(emitter) and not opts.force_new_instance then
		local carrier_attack = attack_of(emitter)
		if carrier_attack then
			return {
				mode = "inherit",
				parent_attack = carrier_attack,
				owner_player = carrier_attack.player,
				source_id = carrier_attack.source_id,
				source = carrier_attack.source,
				via = emitter,
				reason = M.is_lasershot_tear(emitter) and "lasershot_emitter" or "proxy_emitter",
				role_hint = "derived",
			}
		end
	end

	if emitter_cls.kind == "attack_mimic" and emitter_cls.source then
		if not allow_create and not opts.allow_mimic_create then
			-- Laser INIT from Incubus still needs create; treat familiar emitter as create-eligible.
			allow_create = true
		end
		if allow_create then
			return {
				mode = "mimic",
				source_entity = emitter_cls.entity,
				source = emitter_cls.source,
				source_id = emitter_cls.source.source_id,
				owner_player = emitter_cls.owner_player,
				role_hint = (self_cls.kind == "proxy" or M.is_proxy_entity(ent)) and "proxy" or "primary",
			}
		end
	end

	if emitter_cls.kind == "player" and emitter_cls.source then
		if allow_create or opts.from_fire_callback then
			-- C Section / Trisagion child weapons often set Spawner=Player; only inherit when
			-- the projectile is closer to a live carrier (fetus / evil eye / LASERSHOT tear) than to the player.
			if family ~= "tear" and not opts.force_new_instance then
				local proxy_attack, proxy_ent = M.FindLivingProxyAttack(
					emitter_cls.owner_player,
					ent.Position,
					{ radius = 80 }
				)
				if proxy_attack and proxy_ent and emitter_cls.owner_player then
					local d_proxy = ent.Position:Distance(proxy_ent.Position)
					local d_player = ent.Position:Distance(emitter_cls.owner_player.Position)
					if d_proxy + 16 < d_player then
						return {
							mode = "inherit",
							parent_attack = proxy_attack,
							owner_player = proxy_attack.player,
							source_id = proxy_attack.source_id,
							source = proxy_attack.source,
							via = proxy_ent,
							reason = "living_proxy_near",
							role_hint = "derived",
						}
					end
				end
			end
			return {
				mode = "player",
				source_entity = emitter_cls.entity,
				source = emitter_cls.source,
				source_id = emitter_cls.source.source_id,
				owner_player = emitter_cls.owner_player,
				role_hint = (self_cls.kind == "proxy" or M.is_proxy_entity(ent)) and "proxy" or "primary",
			}
		end
	end

	-- Entity itself is player/mimic (rare: binding the familiar?); Evil Eye Spawner=player with no emitter walk.
	if not emitter and self_cls.kind == "proxy" then
		local owner = self_cls.owner_player
		if owner and (allow_create or opts.from_fire_callback) then
			return {
				mode = "player",
				source_entity = owner,
				source = M.make_player_source(owner),
				source_id = M.player_source_id(owner),
				owner_player = owner,
				role_hint = "proxy",
			}
		end
	end

	-- Spawner chain landed on player via Classify of ent when Spawner is nil (some knives).
	if allow_create or opts.from_fire_callback then
		local owner = M.resolve_owner_player(ent)
		if owner and not emitter then
			-- No emitter: only accept for fire callbacks (player-fired tear with Spawner set late).
			if opts.from_fire_callback then
				return {
					mode = "player",
					source_entity = owner,
					source = M.make_player_source(owner),
					source_id = M.player_source_id(owner),
					owner_player = owner,
					role_hint = M.is_proxy_entity(ent) and "proxy" or "primary",
				}
			end
		end
	end

	return {
		mode = "ignore",
		reason = "ineligible_emitter",
		owner_player = M.resolve_owner_player(ent),
	}
end

function M.reset_spawn_stack()
	fire_context.Reset()
end

return M
